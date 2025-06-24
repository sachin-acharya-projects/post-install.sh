#!/bin/bash

# Configuration Paths
POST_INSTALL_CONFIG="$HOME/.config/PostInstall"
FISH_CONFIG="$HOME/.config/fish/config.fish"
BASHRC_CONFIG="$HOME/.bashrc"
ENV_SCRIPT="$POST_INSTALL_CONFIG/environment.sh"
ENTRY_SCRIPT="$POST_INSTALL_CONFIG/entry.sh"

# Default: no auto-yes
AUTO_YES=""

# Parse flags
for arg in "$@"; do
    case $arg in
    -y | --yes)
        AUTO_YES="-y"
        shift
        ;;
    *) ;;
    esac
done

function env_append_path() {
    local new_path="$1"
    if ! grep -q "$new_path" "$ENV_SCRIPT"; then
        echo "export PATH=\"\$PATH:$new_path\"" >> "$ENV_SCRIPT"
    fi
}

# Ensure config directory exists
mkdir -p "$POST_INSTALL_CONFIG"

# Update System
echo "🔄 Updating system..."
sudo apt update && sudo apt upgrade $AUTO_YES

echo "📦 Installing useful CLI tools and dev utilities..."

# Associative array: tool => description
declare -A TOOL_DESCRIPTIONS=(
    ["curl"]="curl -> Transfer data from URLs (API testing, downloads)"
    ["git"]="git -> Version control system for source code"
    ["unzip"]="unzip -> Extract .zip archives"
    ["btop"]="btop -> Modern terminal resource monitor (alternative to htop)"
    ["wget"]="wget -> Command-line file downloader"
    ["gpg"]="gpg -> Encrypt and sign files/data securely"
    ["xz-utils"]="xz-utils -> Compression tool for .xz files"
    ["zip"]="zip -> Create .zip archive files"
    ["libglu1-mesa"]="libglu1-mesa -> OpenGL utility library (graphics support)"
    ["tmux"]="tmux -> Terminal multiplexer (manage multiple shell sessions)"
    ["libc6:amd64"]="libc6:amd64 -> Required system C libraries"
    ["libstdc++6:amd64"]="libstdc++6:amd64 -> Standard C++ library (32-bit)"
    ["lib32z1"]="lib32z1 -> 32-bit zlib support (for compatibility)"
    ["libbz2-1.0:amd64"]="libbz2-1.0:amd64 -> BZip2 compression support (32-bit)"
    ["build-essential"]="build-essential -> Compiler tools like gcc, make, etc."
    ["software-properties-common"]="software-properties-common -> Manage software sources and PPAs"
    ["net-tools"]="net-tools -> Legacy networking tools (ifconfig, netstat)"
    ["tree"]="tree -> Visual directory listing as a tree"
    ["jq"]="jq -> Lightweight JSON parser for shell"
    ["ca-certificates"]="ca-certificates -> Required for SSL connections (HTTPS)"
    ["lsb-release"]="lsb-release -> Show distro version (used by scripts/installers)"
    ["gdb"]="gdb -> Debugger for C/C++ programs"
    ["nmap"]="nmap -> Network scanner and discovery tool"
    ["iotop"]="iotop -> Monitor disk I/O usage per process"
    ["sysstat"]="sysstat -> Includes iostat/mpstat for system monitoring"
    ["fzf"]="fzf -> Fuzzy finder for files, git branches, etc."
    ["shellcheck"]="shellcheck -> Static analysis for shell scripts"
    ["dconf-editor"]="dconf-editor -> Advanced configuration editor for GNOME"
    ["gnome-shell-extension-manager"]="gnome-shell-extension-manager -> GUI to manage GNOME extensions"
    ["tmate"]="tmate -> Share terminal sessions securely"
    ["bat"]="bat -> Enhanced 'cat' with syntax highlighting"
    ["exa"]="exa -> Modern replacement for 'ls' with colors and git support"
    ["zoxide"]="zoxide -> Smarter 'cd' command (remembers directories)"
    ["fd-find"]="fd-find -> Faster and simpler alternative to 'find'"
    ["ripgrep"]="ripgrep -> Super fast 'grep'-like tool for code searching"
    ["neofetch"]="neofetch -> System info display tool (great in terminals)"
    ["fortune"]="fortune -> Show a random quote (fun and motivational)"
    ["xfce4-clipman"]="xfce4-clipman -> Supports clipboard history, persistent history, and keyboard shortcuts."
)

# Print what's being installed
for tool in "${!TOOL_DESCRIPTIONS[@]}"; do
    echo "🔧 ${TOOL_DESCRIPTIONS[$tool]}"
done

# Perform installation
sudo apt install $AUTO_YES \
    xfce4-clipman curl git unzip btop wget gpg xz-utils zip libglu1-mesa tmux \
    libc6:amd64 libstdc++6:amd64 lib32z1 libbz2-1.0:amd64 \
    build-essential software-properties-common net-tools tree jq \
    ca-certificates lsb-release gdb nmap iotop sysstat \
    fzf shellcheck dconf-editor gnome-shell-extension-manager \
    tmate bat exa zoxide fd-find ripgrep neofetch fortune

clipman &

# Helper for snap check + install with message
function snap_check_install() {
    local name=$1
    local snap_name=${2:-$1}
    printf "Checking %s... " "$name"
    if snap list "$snap_name" >/dev/null 2>&1; then
        echo "Already installed, skipping."
    else
        echo "Installing..."
        if sudo snap install "$snap_name" --classic; then
            echo "$name installation success."
        else
            echo "$name installation failed!"
        fi
    fi
}

# Helper for command check + apt install with message
function apt_check_install() {
    local cmd=$1
    local pkg=$2
    printf "Checking %s... " "$pkg"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "Already installed, skipping."
    else
        echo "Installing..."
        if sudo apt install $AUTO_YES "$pkg"; then
            echo "$pkg installation success."
        else
            echo "$pkg installation failed!"
        fi
    fi
}

# Helper to check directory and clone git repo
function git_check_clone() {
    local dir=$1
    local repo=$2
    local name=$3
    printf "Checking %s... " "$name"
    if [ -d "$dir" ]; then
        echo "Already installed, skipping."
    else
        echo "Installing..."
        if git clone "$repo" "$dir" --depth 1; then
            echo "$name installation success."
        else
            echo "$name installation failed!"
        fi
    fi
}

# Install IDEs
echo "💻 Installing IDEs..."
snap_check_install "Visual Studio Code" "code"
snap_check_install "IntelliJ IDEA Community" "intellij-idea-community"
# sudo snap install code --classic
# sudo snap install intellij-idea-community --classic

# Install Languages
echo "🐍 Installing Python..."
sudo apt install $AUTO_YES python3 python3-pip python3-venv
python3 --version

echo "☕ Installing Java..."
# sudo apt install $AUTO_YES default-jre
apt_check_install "java" "default-jre"
java -version

echo "📦 Installing Node.js and NPM..."
# sudo apt install $AUTO_YES nodejs npm
apt_check_install "node" "nodejs"
sudo apt install $AUTO_YES npm
sudo corepack enable || true
node -v
npm -v
yarn -v 2>/dev/null || echo "ℹ️ Yarn not found (may not be included by corepack yet)"

# Android Development Tools
echo "📱 Installing Android Command Line Tools..."
ANDROID_SDK_ROOT="$HOME/Android"
CMDLINE_DIR="$ANDROID_SDK_ROOT/cmdline-tools"
mkdir -p "$CMDLINE_DIR"
cd "$CMDLINE_DIR" || exit

wget https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
unzip commandlinetools-linux-*.zip
rm commandlinetools-linux-*.zip
mkdir -p latest && mv cmdline-tools/* latest/

# Setup Android paths
cat <<EOF >"$ENV_SCRIPT"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
EOF
# export PATH="\$ANDROID_HOME/platform-tools:\$PATH"
# export PATH="\$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH"

env_append_path "$ANDROID_HOME/cmdline-tools/latest/bin"
env_append_path "$ANDROID_HOME/platform-tools"

cat <<EOF >"$ENTRY_SCRIPT"
source "$ENV_SCRIPT"
EOF

chmod +x "$ENV_SCRIPT" "$ENTRY_SCRIPT"

# Source entry script in .bashrc and fish
grep -q "$ENTRY_SCRIPT" "$BASHRC_CONFIG" || echo "source \"$ENTRY_SCRIPT\"" >>"$BASHRC_CONFIG"
mkdir -p "$(dirname "$FISH_CONFIG")"
grep -q "$ENTRY_SCRIPT" "$FISH_CONFIG" || echo "source \"$ENTRY_SCRIPT\"" >>"$FISH_CONFIG"

# Android SDK Installation
echo "📦 Installing Android SDK packages..."
source "$ENV_SCRIPT"
if [ -d "$HOME/Android/cmdline-tools/latest" ]; then
    echo "Already installed, skipping."
else
    echo "Installing..."
    sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" --update
    sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" \
        "platform-tools" "platforms;android-34" "build-tools;34.0.0" "emulator"
    yes | sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" --licenses
    echo "Android SDK installation success."
fi
# sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" --update
# sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" \
#     "platform-tools" "platforms;android-34" "build-tools;34.0.0" "emulator"
# yes | sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" --licenses

cd - || exit

# Flutter Reminder
echo "🐦 Installing Flutter SDK..."
git_check_clone "$HOME/flutter" "https://github.com/flutter/flutter.git" "Flutter SDK"
# git clone https://github.com/flutter/flutter.git "$HOME/flutter" --depth 1
# grep -q 'flutter/bin' "$HOME/.bashrc" || echo 'export PATH="$HOME/flutter/bin:$PATH"' >>$ENV_SCRIPT
# export PATH="$HOME/flutter/bin:$PATH"
env_append_path "$HOME/flutter/bin"
source "$ENV_SCRIPT"
flutter precache
flutter doctor

# 🏗️ Installing Go
echo "🐹 Installing Go (latest)..."
if command -v go >/dev/null 2>&1; then
    echo "Already installed, skipping."
else
    echo "Installing..."
    GO_VERSION=$(curl -s https://go.dev/VERSION?m=text)
    wget "https://dl.google.com/go/${GO_VERSION}.linux-amd64.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "${GO_VERSION}.linux-amd64.tar.gz"
    rm "${GO_VERSION}.linux-amd64.tar.gz"
    echo "Go installation success."
fi

# GO_VERSION=$(curl -s https://go.dev/VERSION?m=text)
# wget "https://dl.google.com/go/${GO_VERSION}.linux-amd64.tar.gz"
# sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf "${GO_VERSION}.linux-amd64.tar.gz"
# grep -q '/usr/local/go/bin' ~/.bashrc || echo 'export PATH="/usr/local/go/bin:$PATH"' >>$ENV_SCRIPT
# rm "${GO_VERSION}.linux-amd64.tar.gz"

# 🦀 Installing Rust
echo "🦀 Installing Rust (via rustup)..."
if command -v rustc >/dev/null 2>&1; then
    echo "Already installed, skipping."
else
    echo "Installing..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    echo "Rust installation success."
fi
# curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
# source "$HOME/.cargo/env"

# 🐳 Installing Docker & Compose
echo "🐳 Installing Docker CE & Compose..."
if command -v docker >/dev/null 2>&1; then
    echo "Already installed, skipping."
else
    echo "Installing..."
    sudo apt install $AUTO_YES ca-certificates curl gnupg lsb-release
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt update
    sudo apt install $AUTO_YES docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo usermod -aG docker "$USER"
    echo "Docker installation success. Please logout/login or run 'newgrp docker' to activate group."
fi
# sudo apt install $AUTO_YES \
#     ca-certificates curl gnupg lsb-release
# sudo mkdir -p /etc/apt/keyrings
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
#     sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# echo \
#     "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
#   https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" |
#     sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
# sudo apt update
# sudo apt install $AUTO_YES docker-ce docker-ce-cli containerd.io docker-compose-plugin
# sudo usermod -aG docker "$USER"

# 🛢️ Installing Databases
echo "🛢️ Installing MySQL, PostgreSQL, MongoDB..."

sudo apt install $AUTO_YES mysql-server postgresql postgresql-contrib
sudo apt install $AUTO_YES gnupg

# MongoDB
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc |
    sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu \
  $(lsb_release -cs)/mongodb-org/6.0 multiverse" |
    sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
sudo apt update
sudo apt install $AUTO_YES mongodb-org

# 🐂 Flatpak & GUI Apps
echo "📦 Installing Flatpak and useful apps..."
sudo apt install $AUTO_YES flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install -y flathub com.spotify.Client com.visualstudio.code

# 🖋️ Install Fonts & Themes
echo "🎨 Installing Nerd Fonts..."
wget -O /tmp/JetBrainsMono.zip \
    https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.3/JetBrainsMono.zip
sudo unzip /tmp/JetBrainsMono.zip -d /usr/share/fonts/truetype/nerd-fonts/
sudo fc-cache -fv

echo "Palette GTK theme..."
sudo apt install $AUTO_YES snapd
sudo snap install communitheme

# Install Web Dev Tools
echo "🌐 Installing NGINX and NGROK..."
sudo apt install $AUTO_YES nginx
sudo snap install ngrok
echo "👉 Please run: ngrok config add-authtoken <your-token>"

# Install Fish Shell and Enhancements
echo "🐟 Installing Fish Shell..."
sudo apt install $AUTO_YES fish fortune neofetch lolcat

# Fish Config
cat <<EOF >>"$FISH_CONFIG"
source "$ENTRY_SCRIPT"
oh-my-posh init fish | source
neofetch --ascii_distro Arch | lolcat -a -d 1
echo
fortune | lolcat -a -d 1
echo
EOF

# Install Oh-My-Posh
echo "🎨 Installing Oh-My-Posh..."
curl -s https://ohmyposh.dev/install.sh | bash -s
oh-my-posh font install meslo

# GNOME Tweaks and Chrome Shell Integration
echo "🛠️ Installing GNOME Tweaks and Shell Integration..."
sudo apt install $AUTO_YES gnome-tweaks chrome-gnome-shell

# === GNOME Extension Installer ===

echo "🧩 Installing gnome-shell-extension-installer..."
if ! command -v gnome-shell-extension-installer &>/dev/null; then
    sudo curl -o /usr/local/bin/gnome-shell-extension-installer \
        https://raw.githubusercontent.com/brunelli/gnome-shell-extension-installer/master/gnome-shell-extension-installer
    sudo chmod +x /usr/local/bin/gnome-shell-extension-installer
fi

# Define GNOME extension IDs
GNOME_EXTENSIONS=(
    7855 # Dash in Panel
    19   # User Themes
    615  # Blur My Shell
    600  # Caffeine
    779  # Clipboard Indicator
    6807 # System Monitor
    3088 # Extension List
    6    # App Menu
)

# Install GNOME extensions
echo "🔌 Installing selected GNOME extensions..."
for ext_id in "${GNOME_EXTENSIONS[@]}"; do
    echo "Installing extension ID: $ext_id"
    gnome-shell-extension-installer "$ext_id" --yes
done

# Start Fish Shell by default
grep -q "exec fish" "$BASHRC_CONFIG" || echo "exec fish" >>"$BASHRC_CONFIG"

echo "✅ Post-installation setup complete!"
echo "⚠️ Please restart your terminal or run 'source $ENTRY_SCRIPT' to load environment variables."
echo "⚠️ For Docker permissions, logout/login or run 'newgrp docker'."