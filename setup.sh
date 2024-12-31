#!/bin/zsh

install_oh_my_zsh() {
    # check if zsh is installed
    if ! command -v zsh &>/dev/null; then
        echo "zsh is not installed. Please install zsh before running this script"
        exit 1
    fi
    # check if oh-my-zsh is installed
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "oh-my-zsh is already installed"
        return
    fi
    # Install oh-my-zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_homebrew() {
    # check if homebrew is installed
    if ! command -v brew &>/dev/null; then
        echo "Homebrew is not installed. Installing Homebrew"
    else
        echo "Homebrew is already installed"
        return
    fi
    # Install Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

install_homebrew_packages() {
    list_str=$1
    list=$(echo $list_str | tr "," "\n")
    for package in $list; do
        brew install $package
    done
}

install_homebrew_casks() {
    list_str=$1
    list=$(echo $list_str | tr "," "\n")
    for cask in $list; do
        brew install --cask $cask
    done
}

add_homebrew_taps() {
    taps_str=$1
    taps=$(echo $taps_str | tr "," "\n")
    for tap in $taps; do
        brew tap $tap
    done
}

# Parameters

# $1: type of setup - personal or work

type=$(echo "$1" | xargs)
if [ "$type" != "personal" ] && [ "$type" != "work" ]; then
    echo "Invalid setup type. Please provide either 'personal' or 'work' as the first argument"
    exit 1
fi
add_homebrew_taps "common-fate/granted"
common_packages="zsh, git, gh, python, terraform, awscli, docker, kubectl, helm, curl, grep, openssh, eza, uv, ruff, fzf, jq"
common_casks="font-monaspace, 1password-cli, 1password, ghostty, antidote, slack"

if [ "$type" = "work" ]; then
    echo "Setting up work environment"
    homebrew_packages="${common_packages}, granted"
    homebrew_casks="${common_casks}, google-chrome"
elif [ "$type" = "personal" ]; then
    echo "Setting up personal environment"
    homebrew_packages="${common_packages}"
    homebrew_casks="${common_casks}, spotify, yaak, finicky"
fi

vault_name=$(echo "$2" | xargs)
if [ -z "$vault_name" ]; then
    echo "Please provide the 1Password vault name as the second argument"
    exit 1
fi

# Check for --skip-install flag
skip_install=false
for arg in "$@"; do
    # if not skip_install flag run install function
    if [ "$arg" = "--skip-install" ]; then
        echo "Skipping installation of Oh-My-Zsh and Homebrew + packages/casks - only updating dotfiles"
        skip_install=true
    else
        skip_install=false
    fi
done

if [ "$skip_install" = false ]; then
    echo "Installing Oh-My-Zsh"
    install_oh_my_zsh
    echo "Installing Homebrew"
    install_homebrew
    echo "Installing Homebrew packages"
    install_homebrew_packages $homebrew_packages
    echo "Installing Homebrew casks"
    install_homebrew_casks $homebrew_casks
fi

# alias eza as ls
echo "alias ls='eza --all --long --group --group-directories-first --icons --header --time-style long-iso'" >>~/.zshrc

# Remove outdated versions from the cellar.\
echo "Cleaning up Homebrew"
brew cleanup

# Configure zsh plugins
cp .zsh/zsh_plugins.txt ~/.zsh_plugins.txt
echo "reload zsh to apply changes"
echo "run: exec zsh"

echo "export EDITOR=\"code-insiders -w\"" >>~/.zshrc
cat >>~/.zshrc <<EOF
source $HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh
antidote load ${ZDOTDIR:-$HOME}/.zsh_plugins.txt
autoload -Uz promptinit && promptinit && prompt pure

autoload -U compinit && compinit
autoload -U +X bashcompinit && bashcompinit

complete -o nospace -C $HOMEBREW_PREFIX/bin/terraform terraform
EOF

# Configure fzf
echo "eval \"\$(fzf --zsh)\"" >>~/.zshrc

# Configure eza as ls
# alias ls='eza --all --long --group --group-directories-first --icons --header --time-style long-iso'
if ! grep -Fxq "alias ls='eza --all --long --group --group-directories-first --icons --header --time-style long-iso'" ~/.zshrc; then
    echo "alias ls='eza --all --long --group --group-directories-first --icons --header --time-style long-iso'" >>~/.zshrc
fi

# replace zsh plugins line in zshrc file
sed -i '' 's/^plugins=.*/plugins=(git aws docker brew emoji gh python terraform common-aliases)/g' ~/.zshrc

# auto update oh-my-zsh
echo "zstyle ':omz:update' check 1" >>~/.zshrc
echo "zstyle ':omz:update' mode auto" >>~/.zshrc

# set zsh history size to very large
echo "HISTSIZE=999999999" >>~/.zshrc
echo "SAVEHIST=999999999" >>~/.zshrc
echo "HISTFILE=~/.zsh_history" >>~/.zshrc

# add fpath for zsh completions
echo "fpath+=$HOMEBREW_PREFIX/share/zsh/site-functions" >>~/.zshrc

# set zsh autosuggest strategy
echo "ZSH_AUTOSUGGEST_STRATEGY=(history completion)" >>~/.zshrc

# set zsh history stamp format
echo "HIST_STAMPS='dd/mm/yyyy'" >>~/.zshrc

# cp other dotfiles/configs
# cp .gitconfig ~/.gitconfig
cp .gitignore ~/.gitignore
cp ./ghostty/config ~/.config/ghostty/config

# Setup 1password ssh agent
echo "export SSH_AUTH_SOCK=~/.1password/agent.sock" >>~/.zshrc
mkdir -p ~/.config/1Password/ssh
touch ~/.config/1Password/ssh/config
cat >~/.config/1Password/ssh/config <<EOF
[[ssh-keys]]
vault = "$vault_name"
EOF
