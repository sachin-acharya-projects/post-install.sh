#!/bin/bash
set -euo pipefail

# ========================
# Constants & Configs
# ========================

POST_INSTALL_CONFIG="$HOME/.config/PostInstall"
LOG_FILE="$POST_INSTALL_CONFIG/install.log"
ENV_SCRIPT="$POST_INSTALL_CONFIG/environment.sh"
ENTRY_SCRIPT="$POST_INSTALL_CONFIG/entry.sh"

AUTO_YES=""
RETRIES=3
MIN_PYTHON_VERSION="3.8"
MIN_JAVA_VERSION=11
MIN_NODE_VERSION=18

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

# Packages grouped by manager and category
declare -A APT_PACKAGES=(
    # CLI Tools / Utils
    ["curl"]="curl -> Transfer data from URLs (API testing, downloads)"
    ["git"]="git -> Version control system for source code"
    ["unzip"]="unzip -> Extract .zip archives"
    ["btop"]="btop -> Modern terminal resource monitor (alternative to htop)"
    ["wget"]="wget -> Command-line file downloader"
    ["gpg"]="gpg -> Encrypt and sign files/data securely"
    ["xz-utils"]="xz-utils -> Compression tool for .xz files"
    ["zip"]="zip -> Create .zip archive files"
    ["libglu1-mesa"]="libglu1-mesa -> OpenGL utility library (graphics support)"
    ["tmux"]="tmux -> Terminal multiplexer"
    ["libc6:amd64"]="libc6:amd64 -> Required system C libraries"
    ["libstdc++6:amd64"]="libstdc++6:amd64 -> Standard C++ library (32-bit)"
    ["lib32z1"]="lib32z1 -> 32-bit zlib support"
    ["libbz2-1.0:amd64"]="libbz2-1.0:amd64 -> BZip2 compression support (32-bit)"
    ["build-essential"]="build-essential -> Compiler tools like gcc, make"
    ["software-properties-common"]="software-properties-common -> Manage PPAs"
    ["net-tools"]="net-tools -> Legacy networking tools (ifconfig, netstat)"
    ["tree"]="tree -> Visual directory listing as tree"
    ["jq"]="jq -> Lightweight JSON parser"
    ["ca-certificates"]="ca-certificates -> SSL certs for HTTPS"
    ["lsb-release"]="lsb-release -> Distro version info"
    ["gdb"]="gdb -> Debugger for C/C++"
    ["nmap"]="nmap -> Network scanner"
    ["iotop"]="iotop -> Disk I/O monitoring"
    ["sysstat"]="sysstat -> System monitoring tools"
    ["shellcheck"]="shellcheck -> Shell script static analysis"
    ["dconf-editor"]="dconf-editor -> GNOME advanced config editor"
    ["gnome-tweaks"]="gnome-tweaks -> GNOME tweaks UI"
    ["chrome-gnome-shell"]="chrome-gnome-shell -> GNOME shell integration"
    ["flatpak"]="flatpak -> Flatpak package manager"
    ["fish"]="fish -> Friendly interactive shell"
    ["fortune"]="fortune -> Random quotes"
    ["neofetch"]="neofetch -> System info display"
    ["libpam-gnome-keyring"]="libpam-gnome-keyring -> GNOME keyring PAM support"
)

declare -A SNAP_PACKAGES=(
    ["code"]="Visual Studio Code"
    ["intellij-idea-community"]="IntelliJ IDEA Community Edition"
    ["gnome-shell-extension-manager"]="GNOME Shell Extension Manager"
    ["tmate"]="tmate -> Terminal sharing"
    ["bat"]="bat -> Enhanced cat with syntax highlight"
    ["exa"]="exa -> Modern ls replacement"
    ["zoxide"]="zoxide -> Directory jumper"
    ["fd"]="fd-find -> Simple find replacement"
    ["rg"]="ripgrep -> Fast grep alternative"
    ["ngrok"]="ngrok -> Tunnel services"
    ["spotify"]="Spotify Music Client"
)

declare -A FLATPAK_PACKAGES=(
    ["com.visualstudio.code"]="Visual Studio Code"
    ["com.spotify.Client"]="Spotify"
    ["org.gnome.Platform"]="GNOME Platform"
)

# GNOME Extensions to optionally install
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

# Special Packages in Zenity checklist for targeted installs
SPECIAL_PACKAGES=(
    "android_sdk"
    "flutter"
    "rust"
    "docker"
    "gnomeext"
)

# Mapping special package names to display names for Zenity
declare -A SPECIAL_PACKAGE_NAMES=(
    ["android_sdk"]="Android SDK"
    ["flutter"]="Flutter SDK"
    ["rust"]="Rust programming language"
    ["docker"]="Docker & Docker Compose"
    ["gnomeext"]="GNOME Extensions (developer-friendly set)"
)

# ========================
# Functions
# ========================

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}ERROR: $1${RESET}" | tee -a "$LOG_FILE" >&2
}

success() {
    echo -e "${GREEN}$1${RESET}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${YELLOW}$1${RESET}" | tee -a "$LOG_FILE"
}

check_internet() {
    local tries=5
    local count=0
    while ! ping -c1 google.com &>/dev/null; do
        ((count++))
        if ((count >= tries)); then
            error "No internet connection after $tries tries. Exiting."
            exit 1
        fi
        info "Waiting for internet connection... retry $count/$tries"
        sleep 5
    done
    success "Internet connection detected."
}

retry_command() {
    local cmd="$1"
    local max_tries=${2:-$RETRIES}
    local count=0

    until $cmd; do
        ((count++))
        if ((count >= max_tries)); then
            return 1
        fi
        info "Retrying ($count/$max_tries) command: $cmd"
        sleep 3
    done
    return 0
}

install_apt_package() {
    local pkg="$1"
    local desc="$2"
    info "Installing APT package: $pkg ($desc)..."
    if retry_command "sudo apt install -y $pkg"; then
        success "Installed APT package: $pkg"
        INSTALLED_PACKAGES["apt-$pkg"]="$pkg"
        return 0
    else
        error "Failed to install APT package: $pkg"
        FAILED_PACKAGES["apt-$pkg"]="$pkg"
        return 1
    fi
}

install_snap_package() {
    local pkg="$1"
    local desc="$2"
    info "Installing Snap package: $pkg ($desc)..."
    if retry_command "sudo snap install $pkg --classic"; then
        success "Installed Snap package: $pkg"
        INSTALLED_PACKAGES["snap-$pkg"]="$pkg"
        return 0
    else
        error "Failed to install Snap package: $pkg"
        FAILED_PACKAGES["snap-$pkg"]="$pkg"
        return 1
    fi
}

install_flatpak_package() {
    local pkg="$1"
    local desc="$2"
    info "Installing Flatpak package: $pkg ($desc)..."
    if retry_command "flatpak install -y flathub $pkg"; then
        success "Installed Flatpak package: $pkg"
        INSTALLED_PACKAGES["flatpak-$pkg"]="$pkg"
        return 0
    else
        error "Failed to install Flatpak package: $pkg"
        FAILED_PACKAGES["flatpak-$pkg"]="$pkg"
        return 1
    fi
}

check_python_version() {
    if command -v python3 &>/dev/null; then
        local ver
        ver=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')
        info "Detected Python version: $ver"
        if python3 -c "import sys; sys.exit(0) if sys.version_info >= ($MIN_PYTHON_VERSION,0) else sys.exit(1)"; then
            success "Python version is $ver (meets minimum requirement $MIN_PYTHON_VERSION.x)"
            INSTALLED_PACKAGES["python"]="$ver"
            return 0
        else
            error "Python version $ver is below minimum required $MIN_PYTHON_VERSION.x"
            return 1
        fi
    else
        error "Python3 not found."
        return 1
    fi
}

install_python() {
    info "Installing Python 3 and related tools..."
    install_apt_package "python3" "Python 3 interpreter"
    install_apt_package "python3-pip" "Python 3 pip"
    install_apt_package "python3-venv" "Python 3 virtual environment support"
}

check_java_version() {
    if command -v java &>/dev/null; then
        local ver
        ver=$(java -version 2>&1 | head -n1 | awk -F '"' '{print $2}')
        info "Detected Java version: $ver"
        local major=${ver%%.*}
        if ((major >= MIN_JAVA_VERSION)); then
            success "Java version $ver meets minimum requirement $MIN_JAVA_VERSION+"
            INSTALLED_PACKAGES["java"]="$ver"
            return 0
        else
            error "Java version $ver is below minimum $MIN_JAVA_VERSION"
            return 1
        fi
    else
        error "Java not found."
        return 1
    fi
}

install_java() {
    info "Installing default Java Runtime Environment..."
    install_apt_package "default-jre" "Default Java Runtime"
}

check_node_version() {
    if command -v node &>/dev/null; then
        local ver
        ver=$(node -v | sed 's/v//')
        info "Detected Node.js version: $ver"
        local major=${ver%%.*}
        if ((major >= MIN_NODE_VERSION)); then
            success "Node.js version $ver meets minimum requirement $MIN_NODE_VERSION+"
            INSTALLED_PACKAGES["nodejs"]="$ver"
            return 0
        else
            error "Node.js version $ver below minimum $MIN_NODE_VERSION"
            return 1
        fi
    else
        error "Node.js not found."
        return 1
    fi
}

install_nodejs() {
    info "Installing Node.js and npm..."
    # Add NodeSource repo for latest Node.js
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    install_apt_package "nodejs" "Node.js LTS"
    install_apt_package "npm" "Node Package Manager"
    sudo corepack enable || info "Corepack enable failed or already enabled."
}

install_android_sdk() {
    info "Installing Android Command Line Tools..."
    ANDROID_SDK_ROOT="$HOME/Android"
    CMDLINE_DIR="$ANDROID_SDK_ROOT/cmdline-tools"
    mkdir -p "$CMDLINE_DIR"
    cd "$CMDLINE_DIR" || exit

    if [ ! -d "$CMDLINE_DIR/latest" ]; then
        wget https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
        unzip commandlinetools-linux-*.zip
        rm commandlinetools-linux-*.zip
        mkdir -p latest && mv cmdline-tools/* latest/
    else
        info "Android SDK command line tools already installed."
    fi

    # Setup environment variables
    echo "export ANDROID_HOME=\"$ANDROID_SDK_ROOT\"" >"$ENV_SCRIPT"
    env_append_path "$ANDROID_HOME/cmdline-tools/latest/bin"
    env_append_path "$ANDROID_HOME/platform-tools"

    # Source env script
    source "$ENV_SCRIPT"

    # Accept licenses and install platform tools
    yes | sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" --licenses
    sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" --update
    sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" "platform-tools" "platforms;android-34" "build-tools;34.0.0" "emulator"
    success "Android SDK installed."
}

install_flutter() {
    info "Installing Flutter SDK..."
    if [ ! -d "$HOME/flutter" ]; then
        git clone https://github.com/flutter/flutter.git "$HOME/flutter" --depth 1
    else
        info "Flutter SDK already cloned."
    fi
    env_append_path "$HOME/flutter/bin"
    source "$ENV_SCRIPT"
    flutter precache
    flutter doctor
    success "Flutter SDK installed."
}

install_rust() {
    info "Installing Rust..."
    if ! command -v rustc &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    else
        info "Rust already installed."
    fi
    success "Rust installation complete."
}

install_docker() {
    info "Installing Docker CE & Compose..."
    if ! command -v docker &>/dev/null; then
        sudo apt install -y ca-certificates curl gnupg lsb-release
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        sudo usermod -aG docker "$USER"
        success "Docker installed. You need to logout/login or run 'newgrp docker' to update group permissions."
    else
        info "Docker already installed."
    fi
}

install_gnome_extension() {
    local ext_id=$1
    if gnome-extensions info "$ext_id" &>/dev/null; then
        info "GNOME Extension $ext_id already installed."
    else
        info "Installing GNOME Extension $ext_id"
        gnome-shell-extension-installer "$ext_id" --yes || error "Failed to install GNOME extension $ext_id"
    fi
}

env_append_path() {
    local new_path="$1"
    if ! grep -qF "$new_path" "$ENV_SCRIPT" 2>/dev/null; then
        echo "export PATH=\"\$PATH:$new_path\"" >>"$ENV_SCRIPT"
    fi
}

# Setup environment scripts and config files
setup_environment() {
    mkdir -p "$POST_INSTALL_CONFIG"
    touch "$ENV_SCRIPT" "$ENTRY_SCRIPT"
    chmod +x "$ENV_SCRIPT" "$ENTRY_SCRIPT"

    echo "source \"$ENV_SCRIPT\"" >"$ENTRY_SCRIPT"

    # Source entry script in .bashrc and fish config
    if ! grep -qF "$ENTRY_SCRIPT" "$HOME/.bashrc" 2>/dev/null; then
        echo "source \"$ENTRY_SCRIPT\"" >>"$HOME/.bashrc"
    fi
    if [ -d "$HOME/.config/fish" ]; then
        if ! grep -qF "$ENTRY_SCRIPT" "$HOME/.config/fish/config.fish" 2>/dev/null; then
            echo "source \"$ENTRY_SCRIPT\"" >>"$HOME/.config/fish/config.fish"
        fi
    fi
}

# ========================
# Main script
# ========================

INSTALLED_PACKAGES=()
FAILED_PACKAGES=()

# Parse flags
for arg in "$@"; do
    case $arg in
    -y | --yes)
        AUTO_YES="-y"
        ;;
    esac
done

setup_environment
check_internet

# Prepare Zenity checklist options
ZENITY_OPTIONS=()
for key in "${!APT_PACKAGES[@]}"; do
    ZENITY_OPTIONS+=("apt-$key" "${APT_PACKAGES[$key]}" "FALSE")
done
for key in "${!SNAP_PACKAGES[@]}"; do
    ZENITY_OPTIONS+=("snap-$key" "${SNAP_PACKAGES[$key]}" "FALSE")
done
for key in "${!FLATPAK_PACKAGES[@]}"; do
    ZENITY_OPTIONS+=("flatpak-$key" "${FLATPAK_PACKAGES[$key]}" "FALSE")
done
for sp in "${SPECIAL_PACKAGES[@]}"; do
    ZENITY_OPTIONS+=("$sp" "${SPECIAL_PACKAGE_NAMES[$sp]}" "FALSE")
done

# User selection via Zenity checklist
SELECTED_PACKAGES=$(zenity --width=800 --height=600 --list --checklist --title="Select packages to install" \
    --column "Select" --column "Package" --column "Description" \
    "${ZENITY_OPTIONS[@]}" \
    2>/dev/null)

if [ -z "$SELECTED_PACKAGES" ]; then
    info "No packages selected. Exiting."
    exit 0
fi

# Convert selected to array (handle Zenity output format)
IFS="|" read -r -a SELECTED_ARRAY <<<"$SELECTED_PACKAGES"

# Function to update progress bar in background
update_progress() {
    local current=$1
    local total=$2
    echo $((current * 100 / total))
}

TOTAL_TASKS=$((${#SELECTED_ARRAY[@]} + 10)) # Rough estimate for progress bar
CURRENT_TASK=0

(
    for pkg_id in "${SELECTED_ARRAY[@]}"; do
        ((CURRENT_TASK++))
        update_progress "$CURRENT_TASK" "$TOTAL_TASKS"
        if [[ "$pkg_id" =~ ^apt- ]]; then
            pkg="${pkg_id#apt-}"
            install_apt_package "$pkg" "${APT_PACKAGES[$pkg]}"
        elif [[ "$pkg_id" =~ ^snap- ]]; then
            pkg="${pkg_id#snap-}"
            install_snap_package "$pkg" "${SNAP_PACKAGES[$pkg]}"
        elif [[ "$pkg_id" =~ ^flatpak- ]]; then
            pkg="${pkg_id#flatpak-}"
            install_flatpak_package "$pkg" "${FLATPAK_PACKAGES[$pkg]}"
        else
            case "$pkg_id" in
            android_sdk)
                install_android_sdk
                ;;
            flutter)
                install_flutter
                ;;
            rust)
                install_rust
                ;;
            docker)
                install_docker
                ;;
            gnomeext)
                for ext in "${GNOME_EXTENSIONS[@]}"; do
                    install_gnome_extension "$ext"
                done
                ;;
            *)
                error "Unknown special package: $pkg_id"
                ;;
            esac
        fi
    done

    # After package installs, check Python version and install if needed
    if ! check_python_version; then
        zenity --question --title="Python Upgrade" --text="Python version is below ${MIN_PYTHON_VERSION}. Install/upgrade Python now?"
        if [ $? -eq 0 ]; then
            install_python
        else
            error "User declined Python upgrade."
            FAILED_PACKAGES["python"]="Python version < $MIN_PYTHON_VERSION"
        fi
    fi

    # Check and install Java if needed
    if ! check_java_version; then
        zenity --question --title="Java Install" --text="Java not found or version below $MIN_JAVA_VERSION. Install default Java now?"
        if [ $? -eq 0 ]; then
            install_java
        else
            error "User declined Java install."
            FAILED_PACKAGES["java"]="Java missing or old version"
        fi
    fi

    # Check and install Node.js if needed
    if ! check_node_version; then
        zenity --question --title="Node.js Install" --text="Node.js not found or version below $MIN_NODE_VERSION. Install Node.js now?"
        if [ $? -eq 0 ]; then
            install_nodejs
        else
            error "User declined Node.js install."
            FAILED_PACKAGES["nodejs"]="Node.js missing or old version"
        fi
    fi

    # Final progress step
    update_progress "$TOTAL_TASKS" "$TOTAL_TASKS"

) | zenity --progress --title="Installing selected packages" --auto-close --width=500 --percentage=0

# Show summary dialog
INSTALLED_LIST=$(printf '%s\n' "${INSTALLED_PACKAGES[@]}")
FAILED_LIST=$(printf '%s\n' "${FAILED_PACKAGES[@]}")

SUMMARY="Installed packages:\n$INSTALLED_LIST\n\nFailed packages:\n$FAILED_LIST"

zenity --info --title="Installation Summary" --text="$SUMMARY"

success "Installation complete. See log file at $LOG_FILE"

exit 0
