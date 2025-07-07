#!/bin/bash
set -e

# Function to get the latest Claude Desktop download URL
get_latest_claude_url() {
    echo "🔍 Fetching latest Claude Desktop download URL..." >&2
    
    # Known working fallback URL (update this if needed)
    local fallback_url="https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe"
    
    # Try to get the download page with proper headers to bypass simple bot detection
    local download_page=$(curl -s -L \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
        -H "Accept-Language: en-US,en;q=0.5" \
        -H "Connection: keep-alive" \
        "https://claude.ai/download" 2>/dev/null)
    
    local claude_url=""
    
    # Check if we got content and try multiple extraction patterns
    if [ -n "$download_page" ]; then
        # Pattern 1: Direct .exe links with Claude in the name
        claude_url=$(echo "$download_page" | grep -oP 'https://[^"]*Claude[^"]*\.exe' | head -1)
        
        # Pattern 2: Storage URLs with osprey (known pattern)
        if [ -z "$claude_url" ]; then
            claude_url=$(echo "$download_page" | grep -oP 'https://storage\.googleapis\.com/[^"]*osprey[^"]*\.exe' | head -1)
        fi
        
        # Pattern 3: Storage URLs with nest-win-x64 (specific pattern for Windows)
        if [ -z "$claude_url" ]; then
            claude_url=$(echo "$download_page" | grep -oP 'https://storage\.googleapis\.com/[^"]*nest-win-x64[^"]*\.exe' | head -1)
        fi
        
        # Pattern 4: Any storage.googleapis.com .exe file
        if [ -z "$claude_url" ]; then
            claude_url=$(echo "$download_page" | grep -oP 'https://storage\.googleapis\.com/[^"]*\.exe' | head -1)
        fi
        
        # Pattern 5: Look for download URLs in script tags or JSON (for React apps)
        if [ -z "$claude_url" ]; then
            claude_url=$(echo "$download_page" | grep -oP '"https://[^"]*Claude[^"]*\.exe"' | sed 's/"//g' | head -1)
        fi
    fi
    
    # If no URL found or download failed, use fallback
    if [ -z "$claude_url" ]; then
        echo "⚠️  Could not find download URL in page, using known fallback URL" >&2
        claude_url="$fallback_url"
    else
        echo "✅ Found Claude Desktop download URL: $claude_url" >&2
        
        # Quick validation: check if the URL is accessible
        if ! curl --max-time 10 -sI "$claude_url" >/dev/null 2>&1; then
            echo "⚠️  Found URL is not accessible, using fallback URL" >&2
            claude_url="$fallback_url"
        fi
    fi
    
    echo "$claude_url"
    return 0
}

# Get the latest Claude Desktop download URL
# CLAUDE_DOWNLOAD_URL=$(get_latest_claude_url)
# if [ $? -ne 0 ]; then
#     echo "❌ Failed to get latest download URL, exiting..."
#     exit 1
# fi

CLAUDE_DOWNLOAD_URL="https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe"


set -x

echo AAAAAAAAAAAAAAAAAAAAAA


# Inclusive check for Fedora-based system
is_fedora_based() {
    if [ -f "/etc/fedora-release" ]; then
        return 0
    fi
    
    if [ -f "/etc/os-release" ]; then
        grep -qi "fedora" /etc/os-release && return 0
    fi
    
    # Not a Fedora-based system
    return 1
}

if ! is_fedora_based; then
    echo "❌ This script requires a Fedora-based Linux distribution"
    exit 1
fi

# Check for root/sudo or container environment
IS_SUDO=false
IS_CONTAINER=false

# Check if we're running in a container (where dependencies are pre-installed)
if [ -f "/.dockerenv" ] || [ -n "${CONTAINER}" ] || [ -d "/workspace" ]; then
    IS_CONTAINER=true
    echo "📦 Detected container environment, skipping sudo check"
fi

if [ "$EUID" -eq 0 ]; then
    IS_SUDO=true
    # Check if running via sudo (and not directly as root)
    if [ -n "$SUDO_USER" ]; then
        ORIGINAL_USER="$SUDO_USER"
        ORIGINAL_HOME=$(eval echo ~$ORIGINAL_USER)
    else
        # Running directly as root, no original user context
        ORIGINAL_USER="root"
        ORIGINAL_HOME="/root"
    fi
elif [ "$IS_CONTAINER" = false ]; then
    echo "Please run with sudo to install dependencies (or use the containerized version with 'make run')"
    exit 1
fi

# Preserve NVM path if running under sudo and NVM exists for the original user
if [ "$IS_SUDO" = true ] && [ "$ORIGINAL_USER" != "root" ] && [ -d "$ORIGINAL_HOME/.nvm" ]; then
    echo "Found NVM installation for user $ORIGINAL_USER, attempting to preserve npm/npx path..."
    # Source NVM script to set up NVM environment variables temporarily
    export NVM_DIR="$ORIGINAL_HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

    # Find the path to the currently active or default Node version's bin directory
    # nvm_find_node_version might not be available, try finding the latest installed version
    NODE_BIN_PATH=$(find "$NVM_DIR/versions/node" -maxdepth 2 -type d -name 'bin' | sort -V | tail -n 1)

    if [ -n "$NODE_BIN_PATH" ] && [ -d "$NODE_BIN_PATH" ]; then
        echo "Adding $NODE_BIN_PATH to PATH"
        export PATH="$NODE_BIN_PATH:$PATH"
    else
        echo "Warning: Could not determine NVM Node bin path. npm/npx might not be found."
    fi
fi

# Print system information
echo "System Information:"
echo "Distribution: $(cat /etc/os-release | grep "PRETTY_NAME" | cut -d'"' -f2)"
echo "Fedora version: $(cat /etc/fedora-release)"

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ $1 not found"
        return 1
    else
        echo "✓ $1 found"
        return 0
    fi
}

# Check and install dependencies
echo "Checking dependencies..."
DEPS_TO_INSTALL=""

# Check system package dependencies
for cmd in sqlite3 7z wget wrestool icotool convert npx rpm rpmbuild; do
    if ! check_command "$cmd"; then
        case "$cmd" in
            "sqlite3")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL sqlite3"
                ;;
            "7z")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL p7zip-plugins"
                ;;
            "wget")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL wget"
                ;;
            "wrestool"|"icotool")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL icoutils"
                ;;
            "convert")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL ImageMagick"
                ;;
            "npx")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL nodejs npm"
                ;;
            "rpm")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL rpm"
                ;;
            "rpmbuild")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL rpmbuild"
                ;;
            "curl")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL curl"
        esac
    fi
done

# Install system dependencies if any (skip in container)
if [ "$IS_CONTAINER" = false ] && [ ! -z "$DEPS_TO_INSTALL" ]; then
    echo "Installing system dependencies: $DEPS_TO_INSTALL"
    dnf install -y $DEPS_TO_INSTALL
    echo "System dependencies installed successfully"
elif [ "$IS_CONTAINER" = true ]; then
    echo "📦 Running in container, system dependencies already installed"
fi

# Install electron globally via npm if not present (skip in container)
if [ "$IS_CONTAINER" = false ] && ! check_command "electron"; then
    echo "Installing electron via npm..."
    npm install -g electron
    if ! check_command "electron"; then
        echo "Failed to install electron. Please install it manually:"
        echo "sudo npm install -g electron"
        exit 1
    fi
    echo "Electron installed successfully"
elif [ "$IS_CONTAINER" = true ]; then
    echo "📦 Running in container, electron already installed"
fi

PACKAGE_NAME="claude-desktop"
ARCHITECTURE="amd64"
MAINTAINER="Claude Desktop Linux Maintainers"
DESCRIPTION="Claude Desktop for Linux"

# Create working directories
WORK_DIR="/workspace/build"
FEDORA_ROOT="$WORK_DIR/fedora-package"
INSTALL_DIR="$FEDORA_ROOT/usr"

# Ensure we're in the right starting directory
echo "📦 Initial working directory: $(pwd)"
echo "📦 WORK_DIR set to: $WORK_DIR"

# Clean previous build
if [ "$IS_CONTAINER" = true ]; then
    # In container, just clean the contents instead of removing the directory (it might be a mount)
    echo "🧹 Cleaning previous build directory contents..."
    rm -rf "$WORK_DIR"/* "$WORK_DIR"/.* 2>/dev/null || true
    mkdir -p "$WORK_DIR"
else
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
fi
mkdir -p "$FEDORA_ROOT/FEDORA"
mkdir -p "$INSTALL_DIR/lib/$PACKAGE_NAME"
mkdir -p "$INSTALL_DIR/share/applications"
mkdir -p "$INSTALL_DIR/share/icons"
mkdir -p "$INSTALL_DIR/bin"

# Install asar if needed
if ! command -v asar > /dev/null 2>&1; then
    echo "Installing asar package globally..."
    npm install -g asar
fi

# Download Claude Windows installer
echo "📥 Downloading Claude Desktop installer..."
CLAUDE_EXE="$WORK_DIR/Claude-Setup-x64.exe"
if ! curl -o "$CLAUDE_EXE" "$CLAUDE_DOWNLOAD_URL"; then
    echo "❌ Failed to download Claude Desktop installer"
    exit 1
fi
echo "✓ Download complete"

# Extract resources
echo "📦 Extracting resources..."
cd "$WORK_DIR"
if ! 7z x -y "$CLAUDE_EXE"; then
    echo "❌ Failed to extract installer"
    exit 1
fi

# Find the nupkg file
NUPKG_FILE=$(find . -name "AnthropicClaude-*-full.nupkg" | head -1)
if [ -z "$NUPKG_FILE" ]; then
    echo "❌ Could not find AnthropicClaude nupkg file"
    exit 1
fi

# Extract the version from the nupkg filename
VERSION=$(echo "$NUPKG_FILE" | grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+(?=-full\.nupkg)')
echo "📋 Detected Claude version: $VERSION"

if ! 7z x -y "$NUPKG_FILE"; then
    echo "❌ Failed to extract nupkg"
    exit 1
fi
echo "✓ Resources extracted"

# Extract and convert icons
echo "🎨 Processing icons..."
if ! wrestool -x -t 14 "lib/net45/claude.exe" -o claude.ico; then
    echo "❌ Failed to extract icons from exe"
    exit 1
fi

if ! icotool -x claude.ico; then
    echo "❌ Failed to convert icons"
    exit 1
fi
echo "✓ Icons processed"

# Map icon sizes to their corresponding extracted files
declare -A icon_files=(
    ["16"]="claude_13_16x16x32.png"
    ["24"]="claude_11_24x24x32.png"
    ["32"]="claude_10_32x32x32.png"
    ["48"]="claude_8_48x48x32.png"
    ["64"]="claude_7_64x64x32.png"
    ["256"]="claude_6_256x256x32.png"
)

# Install icons
for size in 16 24 32 48 64 256; do
    icon_dir="$INSTALL_DIR/share/icons/hicolor/${size}x${size}/apps"
    mkdir -p "$icon_dir"
    if [ -f "${icon_files[$size]}" ]; then
        echo "Installing ${size}x${size} icon..."
        install -Dm 644 "${icon_files[$size]}" "$icon_dir/claude-desktop.png"
    else
        echo "Warning: Missing ${size}x${size} icon"
    fi
done

# Process app.asar
mkdir -p electron-app
cp "lib/net45/resources/app.asar" electron-app/
cp -r "lib/net45/resources/app.asar.unpacked" electron-app/

cd electron-app
npx asar extract app.asar app.asar.contents || { echo "asar extract failed"; exit 1; }

echo "Attempting to set frame:true and remove titleBarStyle/titleBarOverlay in index.js..."

sed -i 's/height:e\.height,titleBarStyle:"default",titleBarOverlay:[^,]\+,/height:e.height,frame:true,/g' app.asar.contents/.vite/build/index.js || echo "Warning: sed command failed to modify index.js"

# Replace native module with stub implementation
echo "Creating stub native module..."
cat > app.asar.contents/node_modules/claude-native/index.js << EOF
// Stub implementation of claude-native using KeyboardKey enum values
const KeyboardKey = {
  Backspace: 43,
  Tab: 280,
  Enter: 261,
  Shift: 272,
  Control: 61,
  Alt: 40,
  CapsLock: 56,
  Escape: 85,
  Space: 276,
  PageUp: 251,
  PageDown: 250,
  End: 83,
  Home: 154,
  LeftArrow: 175,
  UpArrow: 282,
  RightArrow: 262,
  DownArrow: 81,
  Delete: 79,
  Meta: 187
};

Object.freeze(KeyboardKey);

module.exports = {
  getWindowsVersion: () => "10.0.0",
  setWindowEffect: () => {},
  removeWindowEffect: () => {},
  getIsMaximized: () => false,
  flashFrame: () => {},
  clearFlashFrame: () => {},
  showNotification: () => {},
  setProgressBar: () => {},
  clearProgressBar: () => {},
  setOverlayIcon: () => {},
  clearOverlayIcon: () => {},
  KeyboardKey
};
EOF

# Copy Tray icons
mkdir -p app.asar.contents/resources
cp ../lib/net45/resources/Tray* app.asar.contents/resources/

# Repackage app.asar
mkdir -p app.asar.contents/resources/i18n/
cp ../lib/net45/resources/*.json app.asar.contents/resources/i18n/

echo "Downloading Main Window Fix Assets"
cd app.asar.contents
wget -O- https://github.com/emsi/claude-desktop/raw/refs/heads/main/assets/main_window.tgz | tar -zxvf -
cd ..

npx asar pack app.asar.contents app.asar || { echo "asar pack failed"; exit 1; }

# Create native module with keyboard constants
mkdir -p "$INSTALL_DIR/lib/$PACKAGE_NAME/app.asar.unpacked/node_modules/claude-native"
cat > "$INSTALL_DIR/lib/$PACKAGE_NAME/app.asar.unpacked/node_modules/claude-native/index.js" << EOF
// Stub implementation of claude-native using KeyboardKey enum values
const KeyboardKey = {
  Backspace: 43,
  Tab: 280,
  Enter: 261,
  Shift: 272,
  Control: 61,
  Alt: 40,
  CapsLock: 56,
  Escape: 85,
  Space: 276,
  PageUp: 251,
  PageDown: 250,
  End: 83,
  Home: 154,
  LeftArrow: 175,
  UpArrow: 282,
  RightArrow: 262,
  DownArrow: 81,
  Delete: 79,
  Meta: 187
};

Object.freeze(KeyboardKey);

module.exports = {
  getWindowsVersion: () => "10.0.0",
  setWindowEffect: () => {},
  removeWindowEffect: () => {},
  getIsMaximized: () => false,
  flashFrame: () => {},
  clearFlashFrame: () => {},
  showNotification: () => {},
  setProgressBar: () => {},
  clearProgressBar: () => {},
  setOverlayIcon: () => {},
  clearOverlayIcon: () => {},
  KeyboardKey
};
EOF

# Copy app files
echo "📦 About to copy app files"
cp app.asar "$INSTALL_DIR/lib/$PACKAGE_NAME/"
cp -r app.asar.unpacked "$INSTALL_DIR/lib/$PACKAGE_NAME/"
echo "📦 App files copied successfully"

# Return to work directory and download electron
echo "📦 Current directory before cd: $(pwd)"
echo "📦 WORK_DIR is: $WORK_DIR"
cd "$WORK_DIR" || { echo "❌ Failed to change to work directory: $WORK_DIR"; exit 1; }
echo "📦 Current directory after cd: $(pwd)"
echo "📦 Downloading Electron for bundling..."

ELECTRON_VERSION="v37.0.0"
ELECTRON_URL="https://github.com/electron/electron/releases/download/${ELECTRON_VERSION}/electron-${ELECTRON_VERSION}-linux-x64.zip"
ELECTRON_ZIP="electron-${ELECTRON_VERSION}-linux-x64.zip"

wget "$ELECTRON_URL" -O "$ELECTRON_ZIP"
if [ $? -ne 0 ]; then
    echo "❌ Failed to download electron"
    exit 1
fi

# Extract electron to the package
echo "📦 Extracting Electron to package..."
mkdir -p "$INSTALL_DIR/lib/$PACKAGE_NAME/electron"
unzip -q "$ELECTRON_ZIP" -d "$INSTALL_DIR/lib/$PACKAGE_NAME/electron"
chmod +x "$INSTALL_DIR/lib/$PACKAGE_NAME/electron/electron"
echo "✓ Electron bundled successfully"

# Create desktop entry
cat > "$INSTALL_DIR/share/applications/claude-desktop.desktop" << EOF
[Desktop Entry]
Name=Claude
Exec=claude-desktop %u
Icon=claude-desktop
Type=Application
Terminal=false
Categories=Office;Utility;
MimeType=x-scheme-handler/claude;
StartupWMClass=Claude
EOF

# Create launcher script with bundled Electron
cat > "$INSTALL_DIR/bin/claude-desktop" << EOF
#!/bin/bash
LOG_FILE="\$HOME/claude-desktop-launcher.log"

# Set environment to avoid GTK conflicts
export GDK_BACKEND=x11
export GTK_USE_PORTAL=0
export ELECTRON_DISABLE_SECURITY_WARNINGS=true

# Use bundled electron
ELECTRON_CMD="/usr/lib64/claude-desktop/electron/electron"

# Check if bundled electron exists
if [ ! -x "\$ELECTRON_CMD" ]; then
    echo "❌ Error: Bundled electron not found at \$ELECTRON_CMD" >&2
    echo "The Claude Desktop installation may be corrupted." >&2
    exit 1
fi

# Launch Claude Desktop with proper flags
\$ELECTRON_CMD /usr/lib64/claude-desktop/app.asar --ozone-platform-hint=auto --enable-logging=file --log-file=\$LOG_FILE --log-level=INFO --disable-gpu-sandbox --no-sandbox "\$@"
EOF
chmod +x "$INSTALL_DIR/bin/claude-desktop"

# Create RPM spec file
cat > "$WORK_DIR/claude-desktop.spec" << EOF
Name:           claude-desktop
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        Claude Desktop for Linux
License:        Proprietary
URL:            https://www.anthropic.com
BuildArch:      x86_64
Requires:       nodejs >= 12.0.0, npm, p7zip

%description
Claude is an AI assistant from Anthropic.
This package provides the desktop interface for Claude.

%install
mkdir -p %{buildroot}/usr/lib64/%{name}
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/applications
mkdir -p %{buildroot}/usr/share/icons

# Copy files from the INSTALL_DIR
cp -r ${INSTALL_DIR}/lib/%{name}/* %{buildroot}/usr/lib64/%{name}/
cp -r ${INSTALL_DIR}/bin/* %{buildroot}/usr/bin/
cp -r ${INSTALL_DIR}/share/applications/* %{buildroot}/usr/share/applications/
cp -r ${INSTALL_DIR}/share/icons/* %{buildroot}/usr/share/icons/

%files
%{_bindir}/claude-desktop
%{_libdir}/%{name}
%{_datadir}/applications/claude-desktop.desktop
%{_datadir}/icons/hicolor/*/apps/claude-desktop.png

%post
# Update icon caches
gtk-update-icon-cache -f -t %{_datadir}/icons/hicolor || :
# Force icon theme cache rebuild
touch -h %{_datadir}/icons/hicolor >/dev/null 2>&1 || :
update-desktop-database %{_datadir}/applications || :

# Set correct permissions for chrome-sandbox
echo "Setting chrome-sandbox permissions..."
SANDBOX_PATH=""
# Check for sandbox in bundled electron first
if [ -f "/usr/lib64/claude-desktop/electron/chrome-sandbox" ]; then
    SANDBOX_PATH="/usr/lib64/claude-desktop/electron/chrome-sandbox"
# Check for sandbox in locally packaged electron
elif [ -f "/usr/lib64/claude-desktop/app.asar.unpacked/node_modules/electron/dist/chrome-sandbox" ]; then
    SANDBOX_PATH="/usr/lib64/claude-desktop/app.asar.unpacked/node_modules/electron/dist/chrome-sandbox"

elif [ -n "$SUDO_USER" ]; then
    # Running via sudo: try to get electron from the invoking user's environment
    if su - "$SUDO_USER" -c "command -v electron >/dev/null 2>&1"; then
        ELECTRON_PATH=$(su - "$SUDO_USER" -c "command -v electron")

        POTENTIAL_SANDBOX="\$(dirname "\$(dirname "\$ELECTRON_PATH")")/lib/node_modules/electron/dist/chrome-sandbox"
        if [ -f "\$POTENTIAL_SANDBOX" ]; then
            SANDBOX_PATH="\$POTENTIAL_SANDBOX"
        fi
    fi
else
    # Running directly as root (no SUDO_USER); attempt to find electron in root's PATH
    if command -v electron >/dev/null 2>&1; then
        ELECTRON_PATH=$(command -v electron)
        POTENTIAL_SANDBOX="\$(dirname "\$(dirname "\$ELECTRON_PATH")")/lib/node_modules/electron/dist/chrome-sandbox"
        if [ -f "\$POTENTIAL_SANDBOX" ]; then
            SANDBOX_PATH="\$POTENTIAL_SANDBOX"
        fi
    fi
fi

if [ -n "\$SANDBOX_PATH" ] && [ -f "\$SANDBOX_PATH" ]; then
    echo "Found chrome-sandbox at: \$SANDBOX_PATH"
    chown root:root "\$SANDBOX_PATH" || echo "Warning: Failed to chown chrome-sandbox"
    chmod 4755 "\$SANDBOX_PATH" || echo "Warning: Failed to chmod chrome-sandbox"
    echo "Permissions set for \$SANDBOX_PATH"
else
    echo "Warning: chrome-sandbox binary not found. Sandbox may not function correctly."
fi

echo "✓ Claude Desktop installed with bundled Electron"
echo "You can now run: claude-desktop"

%changelog
* $(date '+%a %b %d %Y') ${MAINTAINER} ${VERSION}-1
- Initial package
EOF

# Build RPM package
echo "📦 Building RPM package..."
mkdir -p "${WORK_DIR}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Detect Fedora version for RPM filename
FEDORA_VERSION=$(cat /etc/fedora-release | grep -oP 'release \K[0-9]+')
RPM_FILE="$(pwd)/x86_64/claude-desktop-${VERSION}-1.fc${FEDORA_VERSION}.$(uname -m).rpm"
if rpmbuild -bb \
    --define "_topdir ${WORK_DIR}" \
    --define "_rpmdir $(pwd)" \
    "${WORK_DIR}/claude-desktop.spec"; then
    echo "✓ RPM package built successfully at: $RPM_FILE"
    
    # If running in container, copy output to /output directory
    if [ -d "/output" ] && [ -w "/output" ]; then
        echo "📦 Copying RPM to output directory..."
        cp "$RPM_FILE" /output/
        echo "✓ RPM copied to /output/$(basename "$RPM_FILE")"
        echo "🎉 Done! RPM available in output directory"
    else
        echo "🎉 Done! You can now install the RPM with: dnf install $RPM_FILE"
    fi
else
    echo "❌ Failed to build RPM package"
    exit 1
fi
