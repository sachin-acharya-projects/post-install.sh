#!/bash/bin

POST_INSTALL_CONFIG = $HOME/.config/PostInstall
FISH_CONFIG = $HOME/.config/fish/config.fish
BASHRC_CONFIG = $HOME/.bashrc

mkdir -p $POST_INSTALL_CONFIG

# Updating System
echo "Updating System"
sudo apt update && apt upgrade -y

# Installing useful packages
echo "Installing useful packages"
sudo apt install curl git unzip htop wget gpg xz-utils zip libglu1-mesa tmux -y
sudo apt install libc6:amd64 libstdc++6:amd64 lib32z1 libbz2-1.0:amd64 -y

# Installing IDE for development
echo "Installing Visual Studio Code"
sudo snap install code --classic

echo "Installing Intellij IDEA Community Editon - For Java and Kotlin"
sudo snap install intellij-idea-community --classic

# Installing Languages
echo "Installing Python3"
sudo apt install python3 python3-pip python3-venv -y
python3 --version

echo "Installing Java"
sudo apt install default-jre -y
java -version

echo "Installing Node.js"
sudo apt install nodejs npm -y
sudo corepack enable
node -v
npm -v
yarn -v

echo Installing Android Development Tools
mkdir -p $HOME/Android/cmdline-tools
cd ~/Android/cmdline-tools

wget https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip

unzip commandlinetools-linux-*.zip
rm commandlinetools-linux-*.zip

mkdir latest
mv cmdline-tools/* latest/

echo "export ANDROID_HOME=$HOME/Android" >>$POST_INSTALL_CONFIG/environment.sh
echo "export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH" >>$POST_INSTALL_CONFIG/environment.sh
echo "export PATH=$ANDROID_HOME/platform-tools:$PATH" >>$POST_INSTALL_CONFIG/environment.sh
echo "source $POST_INSTALL_CONFIG/environment.sh" >>entry.sh

echo "source $POST_INSTALL_CONFIG/entry.sh" >>$BASHRC_CONFIG
chmod +x $POST_INSTALL_CONFIG/environment.sh
chmod +x $POST_INSTALL_CONFIG/entry.sh

source $BASHRC_CONFIG

sdkmanager --sdk_root=${ANDROID_HOME} --update
sdkmanager --sdk_root=${ANDROID_HOME} "platform-tools" "platforms;android-34" "build-tools;34.0.0" "emulator"
yes | sdkmanager --sdk_root=${ANDROID_HOME} --licenses

cd -

echo "Please use VSCode's Flutter extension to install Flutter SDK"

echo Installing NGINX
sudo apt install nginx -y

echo Installing NGROK
snap install ngrok

echo "Please run ngrok config add-authtoken <token>"

echo Installing Fish
sudo apt install fish

# Customization
sudo apt install fortune neofetch lolcat
mkdir -p $HOME/.config/fish
echo "$POST_INSTALL_CONFIG/entry.sh | source" >>$FISH_CONFIG
echo "oh-my-posh init fish | source" >>$FISH_CONFIG
echo "neofetch --ascii_distro Arch | lolcat -a -d 1" >>$FISH_CONFIG
echo "echo" >>$FISH_CONFIG
echo "fortune | lolcat -a -d 1" >>$FISH_CONFIG
echo "echo" >>$FISH_CONFIG

echo Installing Oh-My-Posh
curl -s https://ohmyposh.dev/install.sh | bash -s

oh-my-posh font install meslo

echo Installing GNOME Tweaks and other tools
sudo apt install gnome-tweak chrome-gnome-shell

echo "exec fish" >>$BASHRC_CONFIG
