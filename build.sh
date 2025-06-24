#!/bin/bash
set -euo pipefail

PACKAGE_NAME="post-install"
VERSION="1.0.0"
MAINTAINER="Sachin Acharya <post-install@gmail.com>"
DESCRIPTION="Custom developer system setup tool with Zenity UI"

# Paths (adjust if your scripts are elsewhere)
SRC_SCRIPT_DIR="src"
SRC_SCRIPT="src/post-install.sh"
BIN_SCRIPT="post-install" # wrapper script to call post-install.sh

BUILD_DIR="./${PACKAGE_NAME}_build"
DIST_DIR="./dist"
DEBIAN_DIR="${BUILD_DIR}/DEBIAN"
BIN_DIR="${BUILD_DIR}/usr/local/bin"
SHARE_DIR="${BUILD_DIR}/usr/local/share/${PACKAGE_NAME}"

# Clean previous build
echo "Cleaning old build directory..."
rm -rf "$BUILD_DIR"

# Create directory structure
echo "Creating directory structure..."
mkdir -p "$DEBIAN_DIR" "$BIN_DIR" "$SHARE_DIR"

# Create control file
echo "Creating control file..."
cat >"$DEBIAN_DIR/control" <<EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: all
Maintainer: $MAINTAINER
Description: $DESCRIPTION
Depends: zenity, bash, coreutils
EOF

# Copy scripts into place
echo "Copying scripts..."
if [[ ! -f "$SRC_SCRIPT" ]]; then
    echo "Error: Source script '$SRC_SCRIPT' not found!"
    exit 1
fi

cp -r "$SRC_SCRIPT_DIR" "$SHARE_DIR/"
chmod -R 755 "$SHARE_DIR/$SRC_SCRIPT_DIR"

# Create the wrapper executable in bin
cat >"$BIN_DIR/$BIN_SCRIPT" <<EOF
#!/bin/bash
set -e
SCRIPT="/usr/local/share/$PACKAGE_NAME/$SRC_SCRIPT"
if [[ ! -x "\$SCRIPT" ]]; then
    echo "Error: \$SCRIPT is not executable or not found!"
    exit 1
fi
exec bash "\$SCRIPT" "\$@"
EOF
chmod 755 "$BIN_DIR/$BIN_SCRIPT"

# Set permissions on control and DEBIAN dir
chmod 755 "$DEBIAN_DIR"
chmod 644 "$DEBIAN_DIR/control"

echo "Building .deb package..."
dpkg-deb --build "$BUILD_DIR" || {
    echo "Build failed"
    exit 1
}

# Creating dist directory
mkdir -p "$DIST_DIR"

OUTPUT_DEB="$DIST_DIR/${PACKAGE_NAME}_${VERSION}.deb"
mv "${BUILD_DIR}.deb" "$OUTPUT_DEB"

echo -e "\nPackage built successfully: $OUTPUT_DEB"
echo -e "You can install it using:\n>> sudo dpkg -i $OUTPUT_DEB"
