#!/bin/zsh

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if jq is available, install if not
ensure_jq() {
    if ! command -v jq &>/dev/null; then
        log_info "jq not found, installing via Homebrew..."
        if ! command -v brew &>/dev/null; then
            log_error "Homebrew is required to install jq. Please install Homebrew first."
            exit 1
        fi
        brew install jq
    fi
}

# Function to validate profile structure
validate_profile() {
    local profile_path="$1"
    local errors=()
    
    # Check required top-level fields
    local required_fields=("name" "description" "homebrew" "zsh" "git" "editor")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$profile_path" >/dev/null 2>&1; then
            errors+=("Missing required field: $field")
        fi
    done
    
    # Check homebrew structure
    local homebrew_fields=("taps" "packages" "casks")
    for field in "${homebrew_fields[@]}"; do
        if ! jq -e ".homebrew.$field" "$profile_path" >/dev/null 2>&1; then
            errors+=("Missing required field: homebrew.$field")
        elif ! jq -e ".homebrew.$field | type == \"array\"" "$profile_path" >/dev/null 2>&1; then
            errors+=("Field homebrew.$field must be an array")
        fi
    done
    
    # Check zsh structure
    local zsh_required_fields=("plugins" "antidote_plugins")
    for field in "${zsh_required_fields[@]}"; do
        if ! jq -e ".zsh.$field" "$profile_path" >/dev/null 2>&1; then
            errors+=("Missing required field: zsh.$field")
        elif ! jq -e ".zsh.$field | type == \"array\"" "$profile_path" >/dev/null 2>&1; then
            errors+=("Field zsh.$field must be an array")
        fi
    done
    
    # Check optional zsh object fields
    local zsh_optional_objects=("config" "aliases" "exports" "oh_my_zsh_settings")
    for field in "${zsh_optional_objects[@]}"; do
        if jq -e ".zsh.$field" "$profile_path" >/dev/null 2>&1; then
            if ! jq -e ".zsh.$field | type == \"object\"" "$profile_path" >/dev/null 2>&1; then
                errors+=("Field zsh.$field must be an object")
            fi
        fi
    done
    
    # Check optional zsh array fields
    if jq -e ".zsh.init_commands" "$profile_path" >/dev/null 2>&1; then
        if ! jq -e ".zsh.init_commands | type == \"array\"" "$profile_path" >/dev/null 2>&1; then
            errors+=("Field zsh.init_commands must be an array")
        fi
    fi
    
    # Check git config structure
    if ! jq -e ".git.config" "$profile_path" >/dev/null 2>&1; then
        errors+=("Missing required field: git.config")
    elif ! jq -e ".git.config | type == \"object\"" "$profile_path" >/dev/null 2>&1; then
        errors+=("Field git.config must be an object")
    fi
    
    # Check editor structure
    if ! jq -e ".editor.default" "$profile_path" >/dev/null 2>&1; then
        errors+=("Missing required field: editor.default")
    fi
    
    # Report errors
    if [ ${#errors[@]} -gt 0 ]; then
        log_error "Profile validation failed:"
        for error in "${errors[@]}"; do
            log_error "  - $error"
        done
        exit 1
    fi
    
    log_success "Profile validation passed"
}

# Function to load and validate profile
load_profile() {
    local profile_path="$1"
    
    if [[ ! -f "$profile_path" ]]; then
        log_error "Profile file not found: $profile_path"
        exit 1
    fi
    
    # Validate JSON format
    if ! jq empty "$profile_path" 2>/dev/null; then
        log_error "Invalid JSON format in profile: $profile_path"
        exit 1
    fi
    
    # Validate profile structure
    validate_profile "$profile_path"
    
    log_success "Profile loaded successfully: $(jq -r '.name' "$profile_path")"
}

install_oh_my_zsh() {
    # check if zsh is installed
    if ! command -v zsh &>/dev/null; then
        log_error "zsh is not installed. Please install zsh before running this script"
        exit 1
    fi
    # check if oh-my-zsh is installed
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log_info "oh-my-zsh is already installed"
        return
    fi
    # Install oh-my-zsh
    log_info "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_homebrew() {
    # check if homebrew is installed
    if ! command -v brew &>/dev/null; then
        log_info "Homebrew is not installed. Installing Homebrew"
    else
        log_info "Homebrew is already installed"
        return
    fi
    # Install Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

install_homebrew_packages() {
    local profile_path="$1"
    local packages=$(jq -r '.homebrew.packages[]' "$profile_path")
    
    log_info "Installing Homebrew packages..."
    while IFS= read -r package; do
        if [[ -n "$package" ]]; then
            log_info "Installing package: $package"
            brew install "$package" --force
        fi
    done <<< "$packages"
}

install_homebrew_casks() {
    local profile_path="$1"
    local casks=$(jq -r '.homebrew.casks[]' "$profile_path")
    
    log_info "Installing Homebrew casks..."
    while IFS= read -r cask; do
        if [[ -n "$cask" ]]; then
            log_info "Installing cask: $cask"
            brew install --cask "$cask" --force
        fi
    done <<< "$casks"
}

add_homebrew_taps() {
    local profile_path="$1"
    local taps=$(jq -r '.homebrew.taps[]' "$profile_path")
    
    log_info "Adding Homebrew taps..."
    while IFS= read -r tap; do
        if [[ -n "$tap" ]]; then
            log_info "Adding tap: $tap"
            brew tap "$tap"
        fi
    done <<< "$taps"
}

# Parameters
# $1: profile name or path to profile file
# Additional arguments: [--skip-install]

profile_input=$(echo "$1" | xargs)
if [ -z "$profile_input" ]; then
    log_error "Please provide a profile name (personal/work) or path to a profile file as the first argument"
    echo "Usage: $0 <profile_name_or_path> [--skip-install]"
    echo "Examples:"
    echo "  $0 personal"
    echo "  $0 work"
    echo "  $0 /path/to/custom-profile.json"
    exit 1
fi

# Determine profile path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$profile_input" == "personal" ]] || [[ "$profile_input" == "work" ]]; then
    profile_dir="${SCRIPT_DIR}/profiles/${profile_input}"
    profile_path="${profile_dir}/config.json"
    log_info "Using built-in profile: $profile_input"
    log_info "Profile directory: $profile_dir"
    log_info "Profile path: $profile_path"
else
    # Check if it's a folder with config.json or a direct file path
    if [[ -d "$profile_input" ]] && [[ -f "$profile_input/config.json" ]]; then
        profile_dir="$profile_input"
        profile_path="$profile_input/config.json"
        log_info "Using custom profile folder: $profile_input"
    elif [[ -f "$profile_input" ]]; then
        # Legacy support for direct JSON files
        profile_dir="$(dirname "$profile_input")"
        profile_path="$profile_input"
        log_info "Using legacy profile file: $profile_input"
    else
        log_error "Profile not found: $profile_input"
        exit 1
    fi
fi

# Verify the profile file exists
if [[ ! -f "$profile_path" ]]; then
    log_error "Profile config file not found: $profile_path"
    exit 1
fi

# Ensure jq is available and load profile
ensure_jq
load_profile "$profile_path"

# Get vault name from profile only
vault_name=$(jq -r '.onepassword.vault_name // empty' "$profile_path")

if [ -z "$vault_name" ]; then
    log_error "No vault name found in profile. Please specify 'vault_name' in the onepassword section."
    echo "Example profile structure:"
    echo '  "onepassword": {'
    echo '    "vault_name": "Personal"'
    echo '  }'
    exit 1
fi

log_info "Using vault name from profile: $vault_name"

log_info "Setting up environment: $(jq -r '.description' "$profile_path")"

# Check for --skip-install flag
skip_install=false
for arg in "$@"; do
    if [ "$arg" = "--skip-install" ]; then
        log_warning "Skipping installation of Oh-My-Zsh and Homebrew + packages/casks - only updating dotfiles"
        skip_install=true
        break
    fi
done

if [ "$skip_install" = false ]; then
    install_oh_my_zsh
    install_homebrew
    add_homebrew_taps "$profile_path"
    install_homebrew_packages "$profile_path"
    install_homebrew_casks "$profile_path"
    
    # Remove outdated versions from the cellar
    log_info "Cleaning up Homebrew"
    brew cleanup
fi

# Generate complete zsh configuration declaratively
generate_zsh_config() {
    local profile_path="$1"
    local vault_name="$2"
    
    log_info "Generating declarative Zsh configuration..."
    
    # Create antidote plugins file
    log_info "Creating antidote plugins file..."
    jq -r '.zsh.antidote_plugins[]' "$profile_path" > ~/.zsh_plugins.txt
    
    # Get configuration values from profile
    local plugins=$(jq -r '.zsh.plugins | join(" ")' "$profile_path")
    local editor=$(jq -r '.editor.default' "$profile_path")
    
    # Create a temporary zsh config file
    local temp_config=$(mktemp)
    
    # Generate the complete zshrc configuration
    cat > "$temp_config" << 'EOF'
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="robbyrussell"

EOF
    
    # Add plugins from profile
    echo "plugins=($plugins)" >> "$temp_config"
    
    cat >> "$temp_config" << 'EOF'

source $ZSH/oh-my-zsh.sh

### START Profile-based configurations ###
EOF
    
    # Add editor setting
    echo "export EDITOR=\"$editor\"" >> "$temp_config"
    
    # Setup Homebrew environment
    echo "" >> "$temp_config"
    echo "# Homebrew environment setup" >> "$temp_config"
    echo "eval \"\$(/opt/homebrew/bin/brew shellenv)\"" >> "$temp_config"
    
    # Add exports from profile
    local exports=$(jq -r '.zsh.exports // {} | to_entries | .[] | "export \(.key)=\"\(.value)\""' "$profile_path")
    
    # Add 1Password SSH agent configuration if present
    # Use the symlink approach as per 1Password's official guide
    if jq -e '.onepassword' "$profile_path" >/dev/null 2>&1; then
        if [[ -n "$exports" ]]; then
            exports="${exports}\nexport SSH_AUTH_SOCK=~/.1password/agent.sock"
        else
            exports="export SSH_AUTH_SOCK=~/.1password/agent.sock"
        fi
    fi
    
    if [[ -n "$exports" ]]; then
        echo "" >> "$temp_config"
        echo "# Environment exports" >> "$temp_config"
        echo -e "$exports" >> "$temp_config"
    fi
    
    # Add config variables from profile
    local config_vars=$(jq -r '.zsh.config // {} | to_entries | .[] | "\(.key)=\(.value)"' "$profile_path")
    if [[ -n "$config_vars" ]]; then
        echo "" >> "$temp_config"
        echo "# Zsh configuration variables" >> "$temp_config"
        echo "$config_vars" >> "$temp_config"
    fi
    
    # Add aliases from profile
    local aliases=$(jq -r '.zsh.aliases // {} | to_entries | .[] | "alias \(.key)=\"\(.value)\""' "$profile_path")
    if [[ -n "$aliases" ]]; then
        echo "" >> "$temp_config"
        echo "# Aliases" >> "$temp_config"
        echo "$aliases" >> "$temp_config"
    fi
    
    # Add oh-my-zsh settings
    local omz_settings=$(jq -r '.zsh.oh_my_zsh_settings // {} | to_entries | .[] | "\(.key) \(.value)"' "$profile_path")
    if [[ -n "$omz_settings" ]]; then
        echo "" >> "$temp_config"
        echo "# Oh My Zsh settings" >> "$temp_config"
        echo "$omz_settings" >> "$temp_config"
    fi
    
    # Add init commands
    local init_commands=$(jq -r '.zsh.init_commands[]?' "$profile_path")
    if [[ -n "$init_commands" ]]; then
        echo "" >> "$temp_config"
        echo "# Initialization commands" >> "$temp_config"
        echo "$init_commands" >> "$temp_config"
    fi
    
    cat >> "$temp_config" << 'EOF'

### END Profile-based configurations ###
EOF
    
    # Replace the existing zshrc with the generated one
    cp "$temp_config" ~/.zshrc
    rm "$temp_config"
    
    log_success "Generated complete zsh configuration from profile"
}

generate_zsh_config "$profile_path" "$vault_name"

# Generate 1Password SSH agent configuration declaratively
configure_onepassword() {
    local profile_path="$1"
    local vault_name="$2"
    
    # Check if 1Password configuration exists in profile
    if ! jq -e '.onepassword' "$profile_path" >/dev/null 2>&1; then
        log_warning "No 1Password configuration found in profile, skipping..."
        return
    fi
    
    log_info "Configuring 1Password SSH agent..."
    
    # Create 1Password SSH configuration directory
    mkdir -p ~/.config/1Password/ssh
    
    # Generate agent.toml file for SSH key vault configuration
    cat >~/.config/1Password/ssh/agent.toml <<EOF
[[ssh-keys]]
vault = "$vault_name"
EOF
    
    # Create symlink as per 1Password's official guide
    # "For an agent path that's easier to type, you can optionally run the following command"
    mkdir -p ~/.1password
    ln -sf ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ~/.1password/agent.sock
    
    log_success "1Password SSH agent configured for vault: $vault_name"
    log_info "SSH agent socket symlinked to ~/.1password/agent.sock (as per 1Password guide)"
}

configure_onepassword "$profile_path" "$vault_name"

# Copy files dynamically based on profile configuration
copy_profile_files() {
    local profile_path="$1"
    local profile_dir="$2"
    
    log_info "Copying profile files..."
    
    # Check if profile has a files section
    if ! jq -e '.files' "$profile_path" >/dev/null 2>&1; then
        log_info "No files section in profile, skipping file copying"
        return
    fi
    
    # Get all file mappings from the profile
    local file_mappings=$(jq -r '.files | to_entries | .[] | "\(.key):\(.value)"' "$profile_path")
    
    while IFS= read -r mapping; do
        if [[ -n "$mapping" ]]; then
            local source_file=$(echo "$mapping" | cut -d':' -f1)
            local dest_path=$(echo "$mapping" | cut -d':' -f2-)
            
            # Expand tilde in destination path
            dest_path="${dest_path/#\~/$HOME}"
            
            # Full source path relative to profile directory
            local full_source_path="$profile_dir/$source_file"
            
            if [[ -f "$full_source_path" ]]; then
                # Create destination directory if it doesn't exist
                local dest_dir=$(dirname "$dest_path")
                mkdir -p "$dest_dir"
                
                # Copy the file
                cp "$full_source_path" "$dest_path"
                log_success "Copied $source_file → $dest_path"
            else
                log_warning "Source file not found: $full_source_path"
            fi
        fi
    done <<< "$file_mappings"
}

# Configure git from profile
configure_git() {
    local profile_path="$1"
    
    log_info "Configuring Git..."
    
    # Check if git user.name and email are both set
    if [ -z "$(git config --global user.name)" ] || [ -z "$(git config --global user.email)" ]; then
        # Input prompt for git user name and email
        log_warning "Git user name and email not set"
        read -p "Enter your git user name: " git_user_name
        read -p "Enter your git email: " git_email
        git config --global user.name "$git_user_name"
        git config --global user.email "$git_email"
        log_success "Git user name and email set"
    fi
    
    # Apply git configurations from profile
    local git_configs=$(jq -r '.git.config | to_entries | .[] | "\(.key)=\(.value)"' "$profile_path")
    if [[ -n "$git_configs" ]]; then
        while IFS= read -r config; do
            if [[ -n "$config" ]]; then
                key=$(echo "$config" | cut -d'=' -f1)
                value=$(echo "$config" | cut -d'=' -f2-)
                git config --global "$key" "$value"
                log_info "Set git config: $key = $value"
            fi
        done <<< "$git_configs"
    fi
}

# Generate starship configuration if present
configure_starship() {
    local profile_path="$1"
    
    # Check if starship configuration exists in profile
    if ! jq -e '.starship' "$profile_path" >/dev/null 2>&1; then
        log_info "No starship configuration found in profile, using starship defaults"
        return
    fi
    
    log_info "Configuring starship with profile customizations..."
    
    # Create starship config directory
    mkdir -p ~/.config
    
    # Generate starship.toml from profile configuration (additive approach)
    local temp_config=$(mktemp)
    
    # Only add global settings if they're explicitly defined in the profile
    if jq -e '.starship.format' "$profile_path" >/dev/null 2>&1; then
        local format=$(jq -r '.starship.format' "$profile_path")
        echo "format = \"$format\"" >> "$temp_config"
    fi
    
    if jq -e '.starship.add_newline' "$profile_path" >/dev/null 2>&1; then
        local add_newline=$(jq -r '.starship.add_newline' "$profile_path")
        echo "add_newline = $add_newline" >> "$temp_config"
    fi
    
    # Add a newline if we have global settings
    if [[ -s "$temp_config" ]]; then
        echo "" >> "$temp_config"
    fi
    
    # Add module configurations (these override/extend defaults)
    local modules=$(jq -r '.starship.modules // {} | keys[]' "$profile_path" 2>/dev/null)
    while IFS= read -r module; do
        if [[ -n "$module" ]]; then
            echo "[$module]" >> "$temp_config"
            # Get all key-value pairs for this module, preserving data types
            local module_config=$(jq -r ".starship.modules.$module | to_entries | .[] | if (.value | type) == \"string\" then \"\(.key) = \\\"\(.value)\\\"\" else \"\(.key) = \(.value)\" end" "$profile_path")
            echo "$module_config" >> "$temp_config"
            echo "" >> "$temp_config"
        fi
    done <<< "$modules"
    
    # Only create/update config if we have customizations
    if [[ -s "$temp_config" ]]; then
        cp "$temp_config" ~/.config/starship.toml
        log_success "Starship configuration customized at ~/.config/starship.toml"
    else
        # Remove any existing config to use defaults
        rm -f ~/.config/starship.toml
        log_info "Using starship default configuration"
    fi
    
    rm "$temp_config"
}

copy_profile_files "$profile_path" "$profile_dir"
configure_starship "$profile_path"
configure_git "$profile_path"

log_success "Setup completed successfully!"
log_info "Please reload your shell with: exec zsh"
