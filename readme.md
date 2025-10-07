# Quick Setup for Mac

A profile-based Mac development environment setup script that installs and configures all your essential development tools. This script uses JSON configuration profiles to make it easy to customize and maintain different setups for different environments (personal, work, etc.).

## Quick Start

```bash
# For personal setup (vault name from profile)
./setup.sh personal

# For work setup (vault name from profile)
./setup.sh work

# Override vault name from command line
./setup.sh personal MyCustomVault

# Skip installation and only update configs
./setup.sh personal --skip-install
```

## What This Script Does

### Core Installations

- **Homebrew** - Package manager for macOS
- **Oh My Zsh** - Zsh framework with plugins and themes
- **Development Tools** - Git, Python, Node.js, kubectl, Terraform, etc.
- **Applications** - 1Password, Ghostty terminal, Slack, Docker, and more

### Configuration

- **Declarative Zsh Configuration** - Complete `.zshrc` generated from profile (plugins, aliases, exports, init commands)
- **Git Configuration** - Global settings, delta pager, and SSH signing setup
- **1Password SSH Agent** - Secure SSH key management
- **Terminal Tools** - fzf for fuzzy finding, eza for enhanced ls, bat for syntax highlighting

### Declarative Approach

Both zsh and 1Password configurations are completely declarative - your entire `.zshrc` and 1Password SSH agent configuration files are generated from the profile. This means:

- **Predictable** - No manual edits or appending, files are regenerated each time
- **Version Controlled** - All configuration lives in your profile JSON files
- **Consistent** - Same profile always produces the same configuration
- **Maintainable** - Easy to add/remove plugins, aliases, vault names, or settings
- **Self-Healing** - Re-running the script always restores the correct configuration

## Profile-Based Configuration

### Using Built-in Profiles

The script comes with two pre-configured profile folders:

- `personal/` - Personal development setup with Spotify, Yaak, Finicky
- `work/` - Work environment with additional security tools like Granted

### Creating Custom Profiles

You can create your own profile by copying and modifying one of the existing profile folders:

```bash
cp -r profiles/personal profiles/my-custom
# Edit profiles/my-custom/config.json to your preferences
# Add/modify files in the profile folder as needed
./setup.sh my-custom
```

### Profile Structure

Profiles are folders containing a `config.json` file and associated dotfiles:

```
profiles/
├── personal/
│   ├── config.json          # Profile configuration
│   ├── dotfiles/
│   │   └── .gitignore       # Files to copy to home directory
│   ├── ghostty/
│   │   └── config           # Ghostty terminal configuration
│   └── zed/
│       └── settings.json    # Zed editor settings
└── work/
    └── ... (same structure)
```

#### config.json Structure

```json
{
  "name": "Profile Name",
  "description": "Profile description",
  "homebrew": {
    "taps": ["tap1", "tap2"],
    "packages": ["package1", "package2"],
    "casks": ["app1", "app2"]
  },
  "zsh": {
    "plugins": ["git", "docker", "aws"],
    "antidote_plugins": ["zsh-users/zsh-autosuggestions"],
    "config": {
      "HISTSIZE": "999999999",
      "SAVEHIST": "999999999"
    },
    "aliases": {
      "ls": "eza --all --long --icons"
    },
    "exports": {},
    "init_commands": ["eval \"$(fzf --zsh)\""]
  },
  "git": {
    "config": {
      "user.name": "Your Name",
      "core.editor": "code"
    }
  },
  "editor": {
    "default": "code -w"
  },
  "onepassword": {
    "vault_name": "MyVault"
  },
  "files": {
    "dotfiles/.gitignore": "~/.gitignore",
    "ghostty/config": "~/.config/ghostty/config",
    "zed/settings.json": "~/.config/zed/settings.json"
  }
}
```

#### Dynamic File Copying

The `files` section maps source files (relative to the profile folder) to destination paths:

- **Source**: Relative to the profile folder
- **Destination**: Absolute path or `~` for home directory
- **Automatic**: Creates destination directories as needed

## Usage Examples

```bash
# Basic usage with built-in profiles (vault name from profile)
./setup.sh personal
./setup.sh work

# Override vault name from command line
./setup.sh personal MyCustomVault
./setup.sh work MyWorkVault

# Using a custom profile file
./setup.sh /path/to/custom-profile.json
./setup.sh /path/to/custom-profile.json MyVault

# Skip software installation, only update configurations
./setup.sh personal --skip-install

# Validate a profile without running setup
jq empty profiles/personal.json && echo "Valid JSON"
```

## Command Line Arguments

1. **Profile** (required): Either `personal`, `work`, or path to a custom profile JSON file
2. **Vault Name** (optional): Your 1Password vault name for SSH key configuration. If not provided, uses `vault_name` from the profile
3. **--skip-install** (optional): Skip installation steps, only update configurations

## What This Script Doesn't Handle

### Manual Steps Required

- **VSCode**: Sign in with GitHub and sync settings manually
- **1Password Git SSH Signing**: Use the 1Password app to configure Git commit signing ([docs](https://developer.1password.com/docs/ssh/git-commit-signing))
- **Application-specific Settings**: Some apps may require manual configuration

### Customization Tips

- Modify the profile JSON files to add/remove packages or applications
- Add your own dotfiles to the respective directories (ghostty/, zed/, etc.)
- The script preserves existing Git user.name and user.email if already set

## Directory Structure

```
├── setup.sh              # Main setup script
├── profiles/              # Configuration profiles
│   ├── schema.json        # JSON schema for profile validation
│   ├── personal/          # Personal development setup
│   │   ├── config.json    # Profile configuration
│   │   ├── dotfiles/      # Files to copy to home directory
│   │   ├── ghostty/       # Ghostty terminal configuration
│   │   └── zed/           # Zed editor settings
│   └── work/              # Work environment setup
│       └── ... (same structure as personal)
├── ghostty/              # Legacy ghostty config (use profile folders instead)
├── zed/                  # Legacy zed config (use profile folders instead)
└── zsh/                  # Zsh configuration files
```

## Troubleshooting

- **jq not found**: The script will automatically install jq via Homebrew if needed
- **Profile validation errors**: Check your JSON syntax and ensure all required fields are present
- **Permission errors**: Some installations may require sudo access - the script will prompt when needed
- **Homebrew issues**: Run `brew doctor` to diagnose common Homebrew problems
