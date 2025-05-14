#!/bin/bash

# SweetPad Incremental Builds Setup Script
# This script configures SweetPad for optimal incremental builds in VSCode

set -e  # Exit on any error

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Define backup directory for reversion
BACKUP_DIR="${HOME}/.sweetpad_backup/$(date +%Y%m%d_%H%M%S)"

# Function to display progress
progress() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

# Function to display warnings
warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to display errors
error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Function to create backup of configuration files
backup_configs() {
  progress "Creating backup of current configurations..."
  mkdir -p "${BACKUP_DIR}"
  
  # Backup .vscode/settings.json if it exists
  if [ -f "${WORKSPACE_PATH}/.vscode/settings.json" ]; then
    mkdir -p "${BACKUP_DIR}/.vscode"
    cp "${WORKSPACE_PATH}/.vscode/settings.json" "${BACKUP_DIR}/.vscode/"
    progress "Backed up .vscode/settings.json"
  fi
  
  # Backup .vscode/tasks.json if it exists
  if [ -f "${WORKSPACE_PATH}/.vscode/tasks.json" ]; then
    mkdir -p "${BACKUP_DIR}/.vscode"
    cp "${WORKSPACE_PATH}/.vscode/tasks.json" "${BACKUP_DIR}/.vscode/"
    progress "Backed up .vscode/tasks.json"
  fi
  
  # Backup buildServer.json if it exists
  if [ -f "${WORKSPACE_PATH}/buildServer.json" ]; then
    cp "${WORKSPACE_PATH}/buildServer.json" "${BACKUP_DIR}/"
    progress "Backed up buildServer.json"
  fi
}

# Function to restore backups in case of failure
restore_backups() {
  error "Error occurred during setup. Restoring backups..."
  
  if [ -f "${BACKUP_DIR}/.vscode/settings.json" ]; then
    mkdir -p "${WORKSPACE_PATH}/.vscode"
    cp "${BACKUP_DIR}/.vscode/settings.json" "${WORKSPACE_PATH}/.vscode/"
    progress "Restored .vscode/settings.json"
  fi
  
  if [ -f "${BACKUP_DIR}/.vscode/tasks.json" ]; then
    mkdir -p "${WORKSPACE_PATH}/.vscode"
    cp "${BACKUP_DIR}/.vscode/tasks.json" "${WORKSPACE_PATH}/.vscode/"
    progress "Restored .vscode/tasks.json"
  fi
  
  if [ -f "${BACKUP_DIR}/buildServer.json" ]; then
    cp "${BACKUP_DIR}/buildServer.json" "${WORKSPACE_PATH}/"
    progress "Restored buildServer.json"
  fi
  
  error "Setup failed. Previous configuration has been restored."
  exit 1
}

# Set up error handling
trap restore_backups ERR

progress "SweetPad Incremental Build Configuration Script"
progress "---------------------------------------------"
progress "This script will configure SweetPad for optimal incremental builds."
echo ""

# Get workspace path
WORKSPACE_PATH=$(pwd)
if [ ! -d "${WORKSPACE_PATH}" ]; then
  error "Invalid workspace path. Please run this script from your project root."
  exit 1
fi

# Create .vscode directory if it doesn't exist
VSCODE_DIR="${WORKSPACE_PATH}/.vscode"
if [ ! -d "$VSCODE_DIR" ]; then
  progress "Creating .vscode directory..."
  mkdir -p "$VSCODE_DIR"
fi

SETTINGS_JSON_PATH="${VSCODE_DIR}/settings.json"
TASKS_JSON_PATH="${VSCODE_DIR}/tasks.json"

# --- Helper function to update JSON files ---
update_json_file() {
  local file_path="$1"
  local key="$2"
  local value="$3" # Can be a string, number, boolean, or JSON object/array string
  local is_json_value="${4:-false}" # True if value is already a JSON string (object/array)

  if [ ! -f "$file_path" ]; then
    echo "{}" > "$file_path"
  fi

  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    warning "jq is not installed. Cannot automatically update '$file_path'."
    warning "Please add the following manually to '$file_path':"
    if [ "$is_json_value" = true ]; then
      echo "  \"$key\": $value"
    else
      # Guess if value is boolean or number, otherwise treat as string
      if [[ "$value" == "true" || "$value" == "false" || "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "  \"$key\": $value"
      else
        echo "  \"$key\": \"$value\""
      fi
    fi
    return 1
  fi

  local temp_file
  temp_file=$(mktemp)

  if [ "$is_json_value" = true ]; then
    jq --arg key "$key" --argjson val "$value" '. + {($key): $val}' "$file_path" > "$temp_file" && mv "$temp_file" "$file_path"
  else
    # Guess if value is boolean or number for jq
    if [[ "$value" == "true" || "$value" == "false" ]]; then
      jq --arg key "$key" --argjson val "$value" '. + {($key): $val}' "$file_path" > "$temp_file" && mv "$temp_file" "$file_path"
    elif [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      jq --arg key "$key" --argjson val "$(echo "$value" | awk '{print $1+0}')" '. + {($key): $val}' "$file_path" > "$temp_file" && mv "$temp_file" "$file_path"
    else
      jq --arg key "$key" --arg val "$value" '. + {($key): $val}' "$file_path" > "$temp_file" && mv "$temp_file" "$file_path"
    fi
  fi
  progress "Updated '$key' in '$file_path'."
}

# Create backups
backup_configs


# Check for Xcode workspace/project
XCODE_PROJECT=$(find "${WORKSPACE_PATH}" -maxdepth 1 -name "*.xcodeproj" | head -n 1)
XCODE_WORKSPACE=$(find "${WORKSPACE_PATH}" -maxdepth 1 -name "*.xcworkspace" | head -n 1)

if [ -z "${XCODE_PROJECT}" ] && [ -z "${XCODE_WORKSPACE}" ]; then
  error "No Xcode project or workspace found in current directory."
  exit 1
fi

if [ -n "${XCODE_WORKSPACE}" ]; then
  XCODE_PATH="${XCODE_WORKSPACE}"
  XCODE_NAME=$(basename "${XCODE_WORKSPACE}" .xcworkspace)
else
  XCODE_PATH="${XCODE_PROJECT}"
  XCODE_NAME=$(basename "${XCODE_PROJECT}" .xcodeproj)
fi

progress "Found Xcode project: ${XCODE_NAME}"

# Phase 1: Derived Data Path Management
progress "Phase 1: Derived Data Path Management"
progress "Setting a persistent derived data location to prevent cache invalidation."

# Create BuildCache directory
BUILD_CACHE_DIR="${WORKSPACE_PATH}/BuildCache"
mkdir -p "${BUILD_CACHE_DIR}"
progress "Created persistent derived data location at ${BUILD_CACHE_DIR}"

DERIVED_DATA_PATH_VALUE="\${workspaceFolder}/BuildCache" # Project-local cache
update_json_file "$SETTINGS_JSON_PATH" "sweetpad.build.derivedDataPath" "$DERIVED_DATA_PATH_VALUE"
progress "Set 'sweetpad.build.derivedDataPath' to '$DERIVED_DATA_PATH_VALUE' in settings.json"
echo ""

progress "Phase 2: Build Argument Optimization (tasks.json)"
progress "Setting up optimized build tasks for faster incremental builds..."

# Create tasks.json template with proper project values
TASKS_TEMPLATE=$(cat << EOF
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "SweetPad: Optimized Build",
      "type": "shell",
      "command": "xcodebuild",
      "args": [
        "WORKSPACE_ARG",
        "-scheme", "SCHEME_NAME",
        "-configuration", "Debug",
        "-derivedDataPath", "\${workspaceFolder}/BuildCache",
        "-parallelizeTargets",
        "-jobs", "automatic",
        "-skipPackagePluginValidation",
        "-skipMacroValidation",
        "-enableCodeCoverage", "NO",
        "SWIFT_COMPILATION_MODE=incremental",
        "ONLY_ACTIVE_ARCH=YES"
      ],
      "problemMatcher": [
        "\$gcc"
      ],
      "group": {
        "kind": "build",
        "isDefault": true
      }
    },
    {
      "label": "SweetPad: Resolve Package Dependencies",
      "type": "shell",
      "command": "xcodebuild",
      "args": [
        "-resolvePackageDependencies",
        "WORKSPACE_ARG",
        "-scheme", "SCHEME_NAME",
        "-derivedDataPath", "\${workspaceFolder}/BuildCache"
      ],
      "problemMatcher": [
        "\$gcc"
      ]
    }
  ]
}
EOF
)

# Substitute actual project values
if [ -n "${XCODE_WORKSPACE}" ]; then
  WORKSPACE_ARG="-workspace \"\${workspaceFolder}/$(basename "${XCODE_WORKSPACE}")\""
else
  WORKSPACE_ARG="-project \"\${workspaceFolder}/$(basename "${XCODE_PROJECT}")\""
fi

# Replace placeholders with actual values
TASKS_CONTENT=$(echo "${TASKS_TEMPLATE}" | sed "s|WORKSPACE_ARG|${WORKSPACE_ARG}|g" | sed "s|SCHEME_NAME|${XCODE_NAME}|g")

# Check if tasks.json exists
if [ -f "${TASKS_JSON_PATH}" ]; then
  # Backup original tasks
  cp "${TASKS_JSON_PATH}" "${TASKS_JSON_PATH}.bak"
  
  # Use jq to merge tasks if available
  if command -v jq &> /dev/null; then
    # Write the optimized task to a temp file
    echo "${TASKS_CONTENT}" > "${WORKSPACE_PATH}/.vscode/optimized-tasks.json"
    
    # Extract tasks from both files and merge
    jq -s '[.[0].tasks[], .[1].tasks[]] | unique_by(.label) | {version: "2.0.0", tasks: .}' \
      "${TASKS_JSON_PATH}.bak" "${WORKSPACE_PATH}/.vscode/optimized-tasks.json" > "${TASKS_JSON_PATH}"
    
    rm "${WORKSPACE_PATH}/.vscode/optimized-tasks.json"
    progress "Merged optimized build tasks with existing tasks.json"
  else
    warning "jq not found. Creating new tasks.json with optimized build settings only."
    echo "${TASKS_CONTENT}" > "${TASKS_JSON_PATH}"
    progress "Created new tasks.json with optimized build settings"
  fi
else
  echo "${TASKS_CONTENT}" > "${TASKS_JSON_PATH}"
  progress "Created new tasks.json with optimized build settings"
fi
echo ""

progress "Phase 3: Build Server Integration"
progress "Setting up build server integration for optimal incremental builds..."

# Set up build server integration (if not already done by autocomplete script)
if [ ! -f "${WORKSPACE_PATH}/buildServer.json" ]; then
  progress "Creating buildServer.json with custom build root..."
  
  # Create buildServer.json
  cat > "${WORKSPACE_PATH}/buildServer.json" << EOF
{
  "name": "${XCODE_NAME} Build Server",
  "version": "0.1",
  "bspVersion": "2.0",
  "rootUri": "file://\${workspaceFolder}/",
  "capabilities": { "languageIds": ["swift"] },
  "data": {
    "workspace": "\${workspaceFolder}/$(basename "${XCODE_PATH}")",
    "scheme": "${XCODE_NAME}",
    "build_root": "\${workspaceFolder}/BuildCache",
    "crossTargetInheritance": true
  }
}
EOF

  progress "Created buildServer.json with custom build root"
else
  progress "buildServer.json already exists. Updating build_root path..."
  
  if command -v jq &> /dev/null; then
    # Create a temporary file with the updated build_root
    jq '.data.build_root = "${workspaceFolder}/BuildCache"' "${WORKSPACE_PATH}/buildServer.json" > "${WORKSPACE_PATH}/buildServer.json.tmp"
    mv "${WORKSPACE_PATH}/buildServer.json.tmp" "${WORKSPACE_PATH}/buildServer.json"
    progress "Updated build_root in existing buildServer.json"
  else
    warning "jq not found. Please manually update buildServer.json to use \${workspaceFolder}/BuildCache as build_root"
  fi
fi

progress "Phase 4: Dependency Resolution Helper"
progress "Creating dependency resolution script..."

# Generate a helper script for resolving dependencies
cat > "${WORKSPACE_PATH}/resolve_dependencies.sh" << 'EOF'
#!/bin/bash

# Resolve Swift Package Manager dependencies
echo "Resolving Swift Package dependencies..."
xcodebuild -resolvePackageDependencies \
  -workspace "$(find . -maxdepth 1 -name "*.xcworkspace" | head -n 1)" \
  -scheme "$(basename "$(find . -maxdepth 1 -name "*.xcodeproj" | head -n 1)" .xcodeproj)" \
  -derivedDataPath "./BuildCache"

echo "Dependencies resolved."
EOF

chmod +x "${WORKSPACE_PATH}/resolve_dependencies.sh"
progress "Created dependency resolution helper script at ${WORKSPACE_PATH}/resolve_dependencies.sh"
echo ""

progress "Phase 5: Optimization Settings"
progress "Configuring additional optimization settings..."

# Avoid Overcleaning
update_json_file "$SETTINGS_JSON_PATH" "sweetpad.build.cleanBeforeBuild" "false"
progress "Disabled automatic cleaning before builds"

# File watcher excludes
FILES_WATCHER_EXCLUDE_VALUE='{
  "**/.git": true,
  "**/.svn": true,
  "**/.hg": true,
  "**/CVS": true,
  "**/.DS_Store": true,
  "**/Thumbs.db": true,
  "**/BuildCache/**": true,
  "**/DerivedData/**": true,
  "**/*.xcodeproj/project.xcworkspace": true,
  "**/*.xcodeproj/xcuserdata": true
}'
update_json_file "$SETTINGS_JSON_PATH" "files.watcherExclude" "$FILES_WATCHER_EXCLUDE_VALUE" true
progress "Configured file watcher excludes for build artifacts"

progress "Phase 6: Install Support Tools"
progress "Installing xcbeautify for better build output readability..."

if ! command -v brew &> /dev/null; then
    warning "Homebrew not found. Skipping xcbeautify installation."
else
    if ! command -v xcbeautify &> /dev/null; then
        brew install xcbeautify
        progress "Installed xcbeautify for improved build output formatting"
    else
        progress "xcbeautify is already installed"
    fi
fi

# Print verification steps and instructions
cat << EOF

${GREEN}=== SweetPad Incremental Builds Setup Complete! ===${NC}

Your project is now configured for optimal incremental builds with SweetPad.

Key configurations:
- Persistent derived data location at ${BUILD_CACHE_DIR}
- Optimized build settings with incremental compilation mode
- Clean before build disabled to preserve incremental artifacts
- File watcher excludes for build cache directories

${YELLOW}Manual configuration steps:${NC}
In the SweetPad panel in VS Code, right-click on your scheme(s) to configure:
- Disable 'Build for Profiling' (if not needed for development)
- Enable 'Parallelize Build'
- Set 'Build Configuration' to 'Debug' for development builds

${YELLOW}For advanced performance:${NC}
If your project uses Objective-C interoperability, consider these Xcode settings:
- Set 'Precompile Bridging Header' to Yes
- For module interface stabilization:
  SWIFT_EMIT_MODULE_INTERFACE = YES
  BUILD_LIBRARY_FOR_DISTRIBUTION = YES

To get started:
1. ${YELLOW}Restart VS Code${NC} to apply the new settings
2. Run the "SweetPad: Optimized Build" task from the Command Palette (Cmd+Shift+P)
   or use the Tasks menu
3. For Swift Package dependencies, run the "SweetPad: Resolve Package Dependencies" task
   or use the provided helper script: ./resolve_dependencies.sh

EOF

# All done!
progress "Incremental builds setup completed successfully"
echo "Remember to restart VS Code to apply all settings."
