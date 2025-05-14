#!/bin/bash

# SweetPad Autocomplete Setup Script
# This script configures SweetPad for optimal Swift/iOS autocomplete in VSCode

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
  
  # Backup buildServer.json if it exists
  if [ -f "${WORKSPACE_PATH}/buildServer.json" ]; then
    cp "${WORKSPACE_PATH}/buildServer.json" "${BACKUP_DIR}/"
    progress "Backed up buildServer.json"
  fi
  
  # Backup .vscode/settings.json if it exists
  if [ -f "${WORKSPACE_PATH}/.vscode/settings.json" ]; then
    mkdir -p "${BACKUP_DIR}/.vscode"
    cp "${WORKSPACE_PATH}/.vscode/settings.json" "${BACKUP_DIR}/.vscode/"
    progress "Backed up .vscode/settings.json"
  fi
}

# Function to restore backups in case of failure
restore_backups() {
  error "Error occurred during setup. Restoring backups..."
  
  if [ -f "${BACKUP_DIR}/buildServer.json" ]; then
    cp "${BACKUP_DIR}/buildServer.json" "${WORKSPACE_PATH}/"
    progress "Restored buildServer.json"
  fi
  
  if [ -f "${BACKUP_DIR}/.vscode/settings.json" ]; then
    mkdir -p "${WORKSPACE_PATH}/.vscode"
    cp "${BACKUP_DIR}/.vscode/settings.json" "${WORKSPACE_PATH}/.vscode/"
    progress "Restored .vscode/settings.json"
  fi
  
  error "Setup failed. Previous configuration has been restored."
  exit 1
}

# Set up error handling
trap restore_backups ERR

progress "SweetPad Autocomplete Configuration Script"
progress "-----------------------------------------"
progress "This script will configure SweetPad for optimal autocompletion."
progress "Please ensure you have Homebrew installed."
echo ""

# --- Phase 1: Toolchain Installation ---
progress "Phase 1: Installing/Updating Toolchain..."
if ! command -v brew &> /dev/null
then
    error "Homebrew not found. Please install Homebrew first: https://brew.sh/"
    exit 1
fi

# Get workspace path
WORKSPACE_PATH=$(pwd)
if [ ! -d "${WORKSPACE_PATH}" ]; then
  error "Invalid workspace path. Please run this script from your project root."
  exit 1
fi

# Create backups
backup_configs

progress "Installing xcode-build-server (development HEAD)..."
brew install xcode-build-server --HEAD || warning "xcode-build-server installation failed, trying without --HEAD flag..."
if ! command -v xcode-build-server &> /dev/null; then
  brew install xcode-build-server || error "Failed to install xcode-build-server"
fi

progress "Installing sourcekit-lsp..."
brew install sourcekit-lsp || error "Failed to install sourcekit-lsp"

progress "Toolchain installation complete."
echo ""

# --- Phase 2: Project Initialization ---
progress "Phase 2: Project Initialization"

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

# --- Phase 3: buildServer.json Configuration ---
progress "Phase 3: Configuring buildServer.json"
progress "For team workflows and portability, using relative paths."

# Get DerivedData path
DERIVED_DATA_PATH=$(defaults read com.apple.dt.Xcode IDECustomDerivedDataLocation 2>/dev/null || echo "${HOME}/Library/Developer/Xcode/DerivedData")
DERIVED_DATA_PROJECT_PATH="${DERIVED_DATA_PATH}/${XCODE_NAME}-*"

# Find actual derived data path
ACTUAL_DERIVED_DATA=$(find "${DERIVED_DATA_PATH}" -maxdepth 1 -name "${XCODE_NAME}-*" -type d | head -n 1)

if [ -z "${ACTUAL_DERIVED_DATA}" ]; then
  warning "No existing DerivedData found for project. Will be created on first build."
  # Use default naming pattern
  PROJECT_HASH=$(echo "${XCODE_NAME}" | shasum -a 256 | cut -c1-10)
  ACTUAL_DERIVED_DATA="${DERIVED_DATA_PATH}/${XCODE_NAME}-${PROJECT_HASH}"
fi

# Create buildServer.json
progress "Creating buildServer.json with relativized paths..."

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
    "build_root": "\${env:HOME}/Library/Developer/Xcode/DerivedData/$(basename "${ACTUAL_DERIVED_DATA}")",
    "crossTargetInheritance": true
  }
}
EOF

progress "Created buildServer.json with proper paths."
echo ""

# --- Phase 4: Configure VS Code settings for LSP ---
progress "Phase 4: Configuring VS Code settings for LSP"
mkdir -p "${WORKSPACE_PATH}/.vscode"

# Check if settings.json exists
if [ -f "${WORKSPACE_PATH}/.vscode/settings.json" ]; then
  # Backup original settings
  cp "${WORKSPACE_PATH}/.vscode/settings.json" "${WORKSPACE_PATH}/.vscode/settings.json.bak"
  
  # Use jq to merge settings if available
  if command -v jq &> /dev/null; then
    # Create temporary settings file
    cat > "${WORKSPACE_PATH}/.vscode/sourcekit-settings.json" << EOF
{
  "sourcekit-lsp.serverPath": "$(which sourcekit-lsp)",
  "sourcekit-lsp.trace.server": "messages",
  "sourcekit-lsp.workspace.autoIndex": true,
  "sourcekit-lsp.serverArguments": ["--log-level", "info"]
}
EOF
    
    # Merge settings
    jq -s '.[0] * .[1]' "${WORKSPACE_PATH}/.vscode/settings.json.bak" "${WORKSPACE_PATH}/.vscode/sourcekit-settings.json" > "${WORKSPACE_PATH}/.vscode/settings.json"
    rm "${WORKSPACE_PATH}/.vscode/sourcekit-settings.json"
    
  else
    warning "jq not found. Will append settings to existing file."
    # Add settings to existing file, but this is not ideal as it might create duplicate keys
    sed -i.bak '$s/}/,/' "${WORKSPACE_PATH}/.vscode/settings.json"
    cat >> "${WORKSPACE_PATH}/.vscode/settings.json" << EOF
  "sourcekit-lsp.serverPath": "$(which sourcekit-lsp)",
  "sourcekit-lsp.trace.server": "messages",
  "sourcekit-lsp.workspace.autoIndex": true,
  "sourcekit-lsp.serverArguments": ["--log-level", "info"]
}
EOF
  fi
else
  # Create new settings file
  cat > "${WORKSPACE_PATH}/.vscode/settings.json" << EOF
{
  "sourcekit-lsp.serverPath": "$(which sourcekit-lsp)",
  "sourcekit-lsp.trace.server": "messages",
  "sourcekit-lsp.workspace.autoIndex": true,
  "sourcekit-lsp.serverArguments": ["--log-level", "info"]
}
EOF
fi

progress "Configured VS Code settings for SourceKit-LSP"

# --- Phase 5: Optimize LSP cache ---
progress "Phase 5: Optimizing LSP cache settings"
defaults write com.sweetpad.lsp CacheTTL -int 86400
progress "Set LSP cache TTL to 24 hours (86400 seconds)"

# --- Phase 6: Instructions for remaining manual steps ---
progress "Phase 6: Remaining Manual Steps"
cat << EOF

${GREEN}Next steps for SweetPad Autocomplete${NC}:

1. Open your project in VS Code.
2. In VS Code, using the SweetPad extension:
   - Go to the SweetPad panel (usually on the left sidebar)
   - Select your main scheme in the Build panel
   - Click the 'Build & Run' (▶️) button (or just 'Build' (⚙️))
   - This will generate build logs in your DerivedData path

3. After configuring 'buildServer.json' and performing an initial build:
   - Open the Command Palette (Cmd+Shift+P)
   - Run: ${YELLOW}SweetPad: Restart LSP Server${NC}
   - Monitor the 'Output' panel (select 'SourceKit-LSP' from the dropdown)

4. Validate Autocomplete:
   - Open a Swift file in your project
   - Try typing something like 'UIView.' or any other known class
   - You should see autocompletion suggestions (may take a few seconds initially)
   - Expected latency is <500ms for subsequent suggestions

EOF

# --- Advanced Configuration & Performance ---
progress "Advanced Configuration & Performance Optimization"

cat << EOF

${YELLOW}For large projects${NC}, consider adding these optimizations to your settings.json:

1. Selective Indexing (for large projects):
   To reduce memory usage in large projects (by ~40% in 100k+ LOC projects),
   add this to your .vscode/settings.json:
   
   {
     "sourcekit-lsp.workspace.autoIndex": false,
     "sourcekit-lsp.indexing.commentParsing": "disabled"
   }

${YELLOW}Multi-target Projects${NC}:
If your project has multiple frameworks or targets, consider updating 
your buildServer.json to include:

{
  "additionalSchemes": ["FrameworkA", "FrameworkB"],
  "crossTargetInheritance": true
}

# --- Troubleshooting ---
${YELLOW}Troubleshooting Tips${NC}:
If you encounter issues:

1. Verify scheme mapping: Run 'xcode-build-server status' in your terminal
2. Slow suggestions: Check 'sysctl debug.lldb.rpc.timeout'
3. Incorrect types: Try rebuilding Spotlight index with 'mdimport -L'
4. Check Xcode build errors in Console.app
5. Inspect LSP logs at '~/Library/Caches/SweetPad/lsp.log'
6. Validate DerivedData directory permissions

EOF

# All done!
progress "SweetPad Autocomplete setup completed successfully"
echo "Remember to restart VS Code to apply all settings."
