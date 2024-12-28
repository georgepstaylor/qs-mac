#!/bin/zsh

# Parameters

# $1: type of setup - personal or work

type=$(echo "$1" | xargs)
if [ "$type" != "personal" ] && [ "$type" != "work" ]; then
  echo "Invalid setup type. Please provide either 'personal' or 'work' as the first argument"
  exit 1
fi

echo "Setting up $type environment"

vault_name=$(echo "$2" | xargs)
if [ -z "$vault_name" ]; then
  echo "Please provide the 1Password vault name as the second argument"
  exit 1
fi

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Homebrew packages

## Install ghostty terminal
brew install --cask ghostty

## Install antidote (for zsh plugins)
brew install antidote

## Install gh (github cli)
brew install gh

## Install vscode insiders
brew install --cask visual-studio-code@insiders

## Install one-password
brew install --cask 1password

## Install 1password cli
brew install --cask 1password-cli

## Install docker
brew install --cask docker

## Install aws cli  
brew install awscli

## Install terraform
brew install terraform

## Install python
brew install python
## Install uv and ruff
brew install uv ruff

## Install git
brew install git

## Install fzf
brew install fzf

## Install jq
brew install jq

## Install kubectl
brew install kubectl

## Install helm
brew install helm

## Install curl
brew install curl

## Install monaspace font
brew install --cask font-monaspace

## Install eza (enhanced ls)
brew install eza
echo "alias ls='eza --all --long --group --group-directories-first --icons --header --time-style long-iso'" >> ~/.zshrc

## Update some tools
brew install grep
brew install openssh

# Remove outdated versions from the cellar.
brew cleanup

# Configure zsh plugins
cp .zsh/zsh_plugins.txt ~/.zsh_plugins.txt
echo "reload zsh to apply changes"
echo "run: source ~/.zshrc"

echo "export EDITOR="code-insiders -w" >> ~/.zshrc
cat > ~/.zshrc <<EOF
source $HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh
antidote load ${ZDOTDIR:-$HOME}/.zsh_plugins.txt
autoload -Uz promptinit && promptinit && prompt pure

autoload -U compinit && compinit
autoload -U +X bashcompinit && bashcompinit

complete -o nospace -C $HOMEBREW_PREFIX/bin/terraform terraform
EOF

# Configure fzf
echo "eval \"\$(fzf --zsh)\"" >> ~/.zshrc

# Configure eza as ls
# alias ls='eza --all --long --group --group-directories-first --icons --header --time-style long-iso'
echo "alias ls='eza --all --long --group --group-directories-first --icons --header --time-style long-iso'" >> ~/.zshrc

# replace zsh plugins line in zshrc file
sed -i '' 's/^plugins=.*/plugins=(git aws docker brew emoji gh python terraform common-aliases)/g' ~/.zshrc

# auto update oh-my-zsh
echo "zstyle ':omz:update' check 1" >> ~/.zshrc
echo "zstyle ':omz:update' mode auto" >> ~/.zshrc

# set zsh history size unlimited
echo "HISTSIZE=-1" >> ~/.zshrc
echo "SAVEHIST=-1" >> ~/.zshrc

# set zsh autosuggest strategy
echo "ZSH_AUTOSUGGEST_STRATEGY=(history completion)" >> ~/.zshrc

# set zsh history stamp format
echo "HIST_STAMPS='dd/mm/yyyy'" >> ~/.zshrc

# cp other dotfiles/configs
cp .gitconfig ~/.gitconfig
cp .gitignore ~/.gitignore
cp .ghostty/config ~/.config/ghostty/config

# Setup 1password ssh agent
echo "export SSH_AUTH_SOCK=~/.1password/agent.sock" >> ~/.zshrc
mkdir -p ~/.config/1Password/ssh
touch ~/.config/1Password/ssh/config
cat > ~/.config/1Password/ssh/config <<EOF
[[ssh-keys]]
vault = "$vault_name"
EOF
