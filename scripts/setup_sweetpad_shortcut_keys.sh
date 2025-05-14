#!/bin/zsh

# setup_sweetpad_shortcut_keys.sh
# Script to set up VSCode/Cursor keyboard shortcuts for sweetpad

# Constants
VSCODE_CONFIG_DIR="$HOME/Library/Application Support/Code/User"
VSCODE_INSIDERS_CONFIG_DIR="$HOME/Library/Application Support/Code - Insiders/User"
CURSOR_CONFIG_DIR="$HOME/Library/Application Support/Cursor/User"
KEYBINDINGS_FILE="keybindings.json"
BACKUP_SUFFIX=".backup-$(date +%Y%m%d%H%M%S)"

# Define the sweetpad keybindings as a JSON array
SWEETPAD_KEYBINDINGS=$(cat <<EOF
[
  {
    "key": "cmd+b",
    "command": "runCommands",
    "args": {
      "commands": [
        {
          "command": "workbench.action.tasks.terminate",
          "args": "terminateAll"
        },
        {
          "command": "workbench.action.tasks.runTask",
          "args": "sweetpad: build"
        }
      ]
    }
  },
  {
    "key": "ctrl+cmd+r",
    "command": "runCommands",
    "args": {
      "commands": [
        {
          "command": "workbench.action.tasks.terminate",
          "args": "terminateAll"
        },
        {
          "command": "sweetpad.build.launch"
        }
      ]
    }
  },
  {
    "key": "cmd+u",
    "command": "runCommands",
    "args": {
      "commands": [
        {
          "command": "workbench.action.tasks.terminate",
          "args": "terminateAll"
        },
        {
          "command": "sweetpad.build.test"
        }
      ]
    }
  },
  {
    "key": "cmd+.",
    "command": "runCommands",
    "args": {
      "commands": [
        {
          "command": "workbench.action.terminal.killAll"
        }
      ]
    },
    "when": "inDebugMode || taskRunning"
  }
]
EOF
)

# Function to check for directory existence or create it
ensure_config_dir() {
  local config_dir=$1
  if [[ ! -d "$config_dir" ]]; then
    echo "Creating configuration directory: $config_dir"
    mkdir -p "$config_dir" || {
      echo "Error: Failed to create directory $config_dir"
      return 1
    }
  fi
  return 0
}

# Main function to update keybindings
update_keybindings() {
  local config_dir=$1
  local full_path="$config_dir/$KEYBINDINGS_FILE"
  
  # Ensure the config directory exists
  ensure_config_dir "$config_dir" || return 1
  
  # Initialize with empty array if file doesn't exist
  if [[ ! -f "$full_path" ]]; then
    echo "[]" > "$full_path"
    echo "Created new keybindings file at $full_path"
  fi
  
  # Check if the existing file is valid JSON
  if ! jq empty "$full_path" 2>/dev/null; then
    echo "Warning: Existing keybindings file is not valid JSON. Creating backup and starting with empty array."
    cp "$full_path" "$full_path$BACKUP_SUFFIX.invalid"
    echo "[]" > "$full_path"
  fi
  
  # Create backup
  cp "$full_path" "$full_path$BACKUP_SUFFIX"
  echo "Backup created at $full_path$BACKUP_SUFFIX"
  
  # Read existing keybindings and remove any that match our keys
  local new_keybindings
  new_keybindings=$(jq -n --argjson existing "$(cat "$full_path")" \
                    --argjson sweetpad "$SWEETPAD_KEYBINDINGS" \
                    'if $existing | type == "array" then
                        $existing | [.[] | 
                        select(.key != "cmd+b" and 
                               .key != "ctrl+cmd+r" and 
                               .key != "cmd+u" and 
                               .key != "cmd+." )] + $sweetpad
                     else
                        $sweetpad
                     end')
  
  # Check if jq command was successful
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to process JSON. Reverting changes."
    return 1
  fi
  
  # Write the merged keybindings back to the file
  echo "$new_keybindings" > "$full_path"
  echo "Updated keybindings in $full_path"
  
  # Final validation
  if ! jq empty "$full_path" 2>/dev/null; then
    echo "Error: Generated invalid JSON. Reverting changes."
    return 1
  fi
  
  return 0
}

# Check dependencies
check_dependencies() {
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed."
    echo "Please install it using: brew install jq"
    exit 1
  fi
}

# Revert changes on failure
revert_on_failure() {
  local config_dir=$1
  local full_path="$config_dir/$KEYBINDINGS_FILE"
  local backup_path="$full_path$BACKUP_SUFFIX"
  
  if [[ -f "$backup_path" ]]; then
    echo "Error occurred. Reverting changes..."
    mv "$backup_path" "$full_path"
    echo "Reverted to backup."
  fi
  exit 1
}

# Function to print help
print_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Sets up sweetpad shortcut keys for VSCode, VSCode Insiders, and/or Cursor editors."
  echo ""
  echo "Options:"
  echo "  --help, -h         Show this help message"
  echo "  --vscode-only      Update only VSCode keybindings"
  echo "  --insiders-only    Update only VSCode Insiders keybindings"
  echo "  --cursor-only      Update only Cursor keybindings"
  echo "  --dry-run          Show what would be done without making changes"
  echo ""
  echo "Keybindings to be added:"
  echo "  cmd+b:         Build the project (sweetpad: build)"
  echo "  ctrl+cmd+r:    Build and run the project (sweetpad.build.launch)"
  echo "  cmd+u:         Run tests (sweetpad.build.test)"
  echo "  cmd+.:         Terminate tasks when in debug mode or when a task is running"
  echo ""
}

# Main execution
main() {
  local vscode_only=0
  local insiders_only=0
  local cursor_only=0
  local dry_run=0
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --help|-h)
        print_help
        exit 0
        ;;
      --vscode-only)
        vscode_only=1
        ;;
      --insiders-only)
        insiders_only=1
        ;;
      --cursor-only)
        cursor_only=1
        ;;
      --dry-run)
        dry_run=1
        echo "🔍 DRY RUN: No changes will be made"
        ;;
      *)
        echo "Unknown option: $1"
        print_help
        exit 1
        ;;
    esac
    shift
  done
  
  # Check dependencies
  check_dependencies
  
  local updated=0
  
  # Try to update VSCode keybindings
  if [[ $cursor_only -eq 0 && $insiders_only -eq 0 && (-d "$VSCODE_CONFIG_DIR" || $dry_run -eq 1) ]]; then
    echo "🔄 Updating VSCode keybindings..."
    if [[ $dry_run -eq 1 ]]; then
      echo "Would update: $VSCODE_CONFIG_DIR/$KEYBINDINGS_FILE"
    else
      update_keybindings "$VSCODE_CONFIG_DIR" || revert_on_failure "$VSCODE_CONFIG_DIR"
      updated=1
    fi
  fi
  
  # Try to update VSCode Insiders keybindings
  if [[ $cursor_only -eq 0 && $vscode_only -eq 0 && (-d "$VSCODE_INSIDERS_CONFIG_DIR" || $dry_run -eq 1) ]]; then
    echo "🔄 Updating VSCode Insiders keybindings..."
    if [[ $dry_run -eq 1 ]]; then
      echo "Would update: $VSCODE_INSIDERS_CONFIG_DIR/$KEYBINDINGS_FILE"
    else
      update_keybindings "$VSCODE_INSIDERS_CONFIG_DIR" || revert_on_failure "$VSCODE_INSIDERS_CONFIG_DIR"
      updated=1
    fi
  fi
  
  # Try to update Cursor keybindings
  if [[ $vscode_only -eq 0 && $insiders_only -eq 0 && (-d "$CURSOR_CONFIG_DIR" || $dry_run -eq 1) ]]; then
    echo "🔄 Updating Cursor keybindings..."
    if [[ $dry_run -eq 1 ]]; then
      echo "Would update: $CURSOR_CONFIG_DIR/$KEYBINDINGS_FILE"
    else
      update_keybindings "$CURSOR_CONFIG_DIR" || revert_on_failure "$CURSOR_CONFIG_DIR"
      updated=1
    fi
  fi
  
  # Check if any updates were performed
  if [[ $updated -eq 0 && $dry_run -eq 0 ]]; then
    echo "⚠️ No editor configurations were found or updated."
    echo "If you're using VSCode, VSCode Insiders, or Cursor, please check their installation paths:"
    echo "Expected VSCode path: $VSCODE_CONFIG_DIR"
    echo "Expected VSCode Insiders path: $VSCODE_INSIDERS_CONFIG_DIR"
    echo "Expected Cursor path: $CURSOR_CONFIG_DIR"
    exit 1
  fi
  
  if [[ $dry_run -eq 0 ]]; then
    echo "✅ Sweetpad shortcut keys set up successfully!"
  else
    echo "✅ Dry run completed. No changes were made."
  fi
}

main "$@"
