#!/bin/bash
set -e

# =============================================================================
# install.sh — Bootstrap script for a new Mac dev environment
# Usage: git clone https://github.com/you/dotfiles.git ~/dotfiles
#        cd ~/dotfiles && chmod +x install.sh && ./install.sh
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

step() { echo -e "\n${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}Warning:${NC} $1"; }
error() { echo -e "${RED}Error:${NC} $1"; }

# -----------------------------------------------------------------------------
# 1. Xcode Command Line Tools
# -----------------------------------------------------------------------------
step "Checking for Xcode Command Line Tools..."
if ! xcode-select -p &>/dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Press any key once the installation is complete."
    read -n 1 -s
else
    echo "Already installed."
fi

# -----------------------------------------------------------------------------
# 2. Homebrew
# -----------------------------------------------------------------------------
step "Checking for Homebrew..."
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "Already installed. Updating..."
    brew update
fi

# -----------------------------------------------------------------------------
# 3. Install packages from Brewfile
# -----------------------------------------------------------------------------
step "Installing packages from Brewfile..."
if [ -f "$DOTFILES_DIR/Brewfile" ]; then
    brew bundle --file="$DOTFILES_DIR/Brewfile"
else
    error "Brewfile not found at $DOTFILES_DIR/Brewfile"
    exit 1
fi

# -----------------------------------------------------------------------------
# 4. Oh My Zsh
# -----------------------------------------------------------------------------
step "Checking for Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Already installed."
fi

# Install custom plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# -----------------------------------------------------------------------------
# 5. Symlink dotfiles
# -----------------------------------------------------------------------------
step "Symlinking dotfiles..."

symlink() {
    local src="$1"
    local dest="$2"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
            echo "  ✓ $dest already linked"
            return
        fi
        warn "$dest already exists — backing up to ${dest}.backup"
        mv "$dest" "${dest}.backup"
    fi

    ln -s "$src" "$dest"
    echo "  ✓ Linked $dest → $src"
}

symlink "$DOTFILES_DIR/.zshrc"             "$HOME/.zshrc"
symlink "$DOTFILES_DIR/.gitconfig"         "$HOME/.gitconfig"
symlink "$DOTFILES_DIR/.gitignore_global"  "$HOME/.gitignore_global"

# SSH config (create .ssh dir if needed, don't overwrite keys)
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
symlink "$DOTFILES_DIR/.ssh/config"        "$HOME/.ssh/config"

# -----------------------------------------------------------------------------
# 6. Node.js via nvm
# -----------------------------------------------------------------------------
step "Setting up Node.js via nvm..."
export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR"

# Source nvm if installed via Homebrew
if [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
    source "/opt/homebrew/opt/nvm/nvm.sh"
elif [ -s "$NVM_DIR/nvm.sh" ]; then
    source "$NVM_DIR/nvm.sh"
fi

if command -v nvm &>/dev/null; then
    echo "Installing latest LTS Node.js..."
    nvm install --lts
    nvm use --lts
    nvm alias default node
else
    warn "nvm not found — you may need to restart your shell first."
fi

# -----------------------------------------------------------------------------
# 7. Global npm packages
# -----------------------------------------------------------------------------
step "Installing global npm packages..."
if command -v npm &>/dev/null; then
    npm install -g \
        typescript \
        ts-node \
        eslint \
        prettier \
        npm-check-updates
else
    warn "npm not found — skipping global packages."
fi

# -----------------------------------------------------------------------------
# 8. Claude Code
# -----------------------------------------------------------------------------
step "Installing Claude Code..."
if command -v npm &>/dev/null; then
    npm install -g @anthropic-ai/claude-code
else
    warn "npm not found — install Claude Code manually after nvm is set up."
fi

# -----------------------------------------------------------------------------
# 9. PostgreSQL
# -----------------------------------------------------------------------------
step "Setting up PostgreSQL 17..."
if brew list postgresql@17 &>/dev/null; then
    brew services start postgresql@17
    echo "PostgreSQL 17 is running."
    echo ""
    echo "  To restore a database backup:"
    echo "    createdb your_database_name"
    echo "    psql -d your_database_name < ~/db_backup.sql"
else
    warn "postgresql@17 not in Brewfile — skipping."
fi

# -----------------------------------------------------------------------------
# 10. macOS defaults (optional, comment out what you don't want)
# -----------------------------------------------------------------------------
step "Setting macOS preferences..."

# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show path bar in Finder
defaults write com.apple.finder ShowPathbar -bool true

# Show status bar in Finder
defaults write com.apple.finder ShowStatusBar -bool true

# Disable press-and-hold for keys (enable key repeat)
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Fast key repeat rate
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Show file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

echo "Some preferences require a logout/restart to take effect."

# -----------------------------------------------------------------------------
# 11. SSH key reminder
# -----------------------------------------------------------------------------
step "SSH key setup"
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo ""
    echo "  No SSH key found. Generate one with:"
    echo ""
    echo "    ssh-keygen -t ed25519 -C \"your@email.com\""
    echo "    ssh-add --apple-use-keychain ~/.ssh/id_ed25519"
    echo "    gh auth login   # or paste public key into GitHub settings"
    echo ""
else
    echo "SSH key found at ~/.ssh/id_ed25519"
fi

# -----------------------------------------------------------------------------
# Done!
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup complete! 🎉${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "  Next steps:"
echo "    1. Restart your terminal (or run: source ~/.zshrc)"
echo "    2. Set up SSH keys if you haven't (see above)"
echo "    3. Sign into VS Code Settings Sync"
echo "    4. Restore any database backups"
echo "    5. Clone your project repos"
echo ""
echo "  If you have a .zshrc.local for machine-specific config,"
echo "  create it at ~/.zshrc.local — it won't be tracked by git."
echo ""
