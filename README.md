# Claude Desktop Fedora Builder

A containerized solution for building Claude Desktop RPM packages for Fedora Linux systems.

## 🚀 Quick Start

### Prerequisites

- **Podman** (or Docker) installed on your system
- **Make** utility

### Install Podman (if needed)

```bash
# Fedora/RHEL/CentOS
sudo dnf install podman

# Ubuntu/Debian
sudo apt install podman
```

### Build and Run

1. **Clone this repository:**
   ```bash
   git clone <repository-url>
   cd claude-desktop-fedora
   ```

2. **Build the Claude Desktop RPM:**
   
   **Option A: Using Make (Recommended)**
   ```bash
   make run
   ```
   
   **Option B: Using Docker Compose**
   ```bash
   docker-compose run --rm claude-builder
   ```

3. **Install the package:**
   ```bash
   make install-rpm
   # or find the RPM in ./output/ and install manually
   ```

That's it! The process will:
- Automatically fetch the latest Claude Desktop version
- Build the RPM package in a clean container environment
- Make the package available in the `./output/` directory

## 📋 Available Commands

Run `make help` to see all available commands:

```bash
make help
```

### Main Commands

| Command | Description |
|---------|-------------|
| `make run` | Build Claude Desktop RPM package |
| `make install-rpm` | Install the built RPM package |
| `make status` | Show container and build status |
| `make clean` | Clean up containers |
| `make clean-all` | Clean everything including images |

### Development Commands

| Command | Description |
|---------|-------------|
| `make shell` | Get an interactive shell in the container |
| `make run-interactive` | Run container interactively for debugging |
| `make dev-build` | Build container without cache |
| `make logs` | Show logs from the last container run |

### Docker Compose Alternative

If you prefer Docker Compose over Make:

```bash
# Build the RPM package
docker-compose run --rm claude-builder

# Get an interactive shell
docker-compose run --rm claude-shell

# Build the image
docker-compose build

# Clean up
docker-compose down --rmi all
```

## 🐳 Container Details

### Base Image
- **Fedora:latest** - Ensures compatibility with Fedora systems

### Pre-installed Dependencies
- Build tools: `rpm-build`, `rpmdevtools`, `make`
- Archive tools: `p7zip-plugins`, `tar`, `gzip`
- Image processing: `ImageMagick`, `icoutils`
- Node.js ecosystem: `nodejs`, `npm`, `electron`, `asar`
- Network tools: `wget`, `curl`
- Database: `sqlite3`

### Security
- Runs as non-root user (`builder`) inside container
- Uses Podman's security features and SELinux integration
- Volume mounts with appropriate permissions

## 📁 Directory Structure

```
.
├── Containerfile          # Container definition
├── Makefile              # Build automation
├── build-fedora.sh       # Main build script
├── README.md             # This file
├── output/               # Generated RPM packages (created on first run)
└── build/                # Temporary build files (created on first run)
```

## 🔧 Configuration

### Environment Variables

The container can be customized with environment variables:

```bash
# Example: Custom output directory
OUTPUT_DIR=/custom/path make run
```

### Volume Mounts

The Makefile automatically sets up these volume mounts:
- `./output/` → `/output` (RPM packages)
- `./build/` → `/workspace/build` (temporary build files)

## 🚨 Troubleshooting

### Common Issues

**1. Permission Denied Errors**
```bash
# Ensure Podman is properly installed and your user is in the right group
sudo usermod -aG podman $USER
# Log out and back in
```

**2. Build Fails to Download Claude**
```bash
# Check internet connectivity and try again
make clean
make run
```

**3. Container Won't Start**
```bash
# Check Podman status
podman version
make status
```

### Debug Mode

For troubleshooting, use the interactive mode:

```bash
# Get a shell inside the container
make shell

# Or run the build interactively
make run-interactive
```

### Logs

View detailed logs from the build process:

```bash
make logs
```

## 🔄 How It Works

1. **Auto-fetch Latest Version**: The script automatically downloads the latest Claude Desktop installer from `https://claude.ai/download`

2. **Extract Resources**: Uses 7zip to extract the Windows installer and extracts necessary files

3. **Process Icons**: Converts Windows icons to Linux-compatible formats

4. **Patch Application**: Applies necessary patches for Linux compatibility

5. **Build RPM**: Creates a proper RPM package with correct dependencies and metadata

6. **Output**: Places the final RPM in the `./output/` directory

## 📦 Package Details

The generated RPM package includes:
- **Application files** in `/usr/lib64/claude-desktop/`
- **Desktop entry** for application launcher
- **Icons** in standard Linux locations
- **Launcher script** with Wayland compatibility
- **Proper dependencies** and metadata

### Installation Locations

After installation:
- Binary: `/usr/bin/claude-desktop`
- Application: `/usr/lib64/claude-desktop/`
- Icons: `/usr/share/icons/hicolor/*/apps/`
- Desktop entry: `/usr/share/applications/claude-desktop.desktop`

## 🛠️ Development

### Modifying the Build Script

1. Edit `build-fedora.sh`
2. Rebuild the container: `make dev-build`
3. Test: `make run`

### Container Customization

1. Edit `Containerfile`
2. Rebuild: `make build`
3. Test: `make run`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `make run`
5. Submit a pull request

## 📄 License

This project is provided as-is for educational and personal use. Claude Desktop is property of Anthropic.

## ⚠️ Disclaimer

This is an unofficial packaging tool. It downloads and repackages the official Claude Desktop application for use on Fedora systems. Claude Desktop and its assets are property of Anthropic.

# Claude Desktop for Linux

This project was inspired by [k3d3's claude-desktop-linux-flake](https://github.com/k3d3/claude-desktop-linux-flake) and their [Reddit post](https://www.reddit.com/r/ClaudeAI/comments/1hgsmpq/i_successfully_ran_claude_desktop_natively_on/) about running Claude Desktop natively on Linux. Their work provided valuable insights into the application's structure and the native bindings implementation.

And now by me, via [Aaddrick's claude-desktop-debian](https://github.com/aaddrick/claude-desktop-debian), modified to work for Fedora 41.

Supports MCP!
![image](https://github.com/user-attachments/assets/93080028-6f71-48bd-8e59-5149d148cd45)

Location of the MCP-configuration file is: ~/.config/Claude/claude_desktop_config.json

Supports the Ctrl+Alt+Space popup!
![image](https://github.com/user-attachments/assets/1deb4604-4c06-4e4b-b63f-7f6ef9ef28c1)

Supports the Tray menu! (Screenshot of running on KDE)
![image](https://github.com/user-attachments/assets/ba209824-8afb-437c-a944-b53fd9ecd559)

# Installation Options

## 1. Fedora Package (New!)

For Fedora-based distributions you can build and install Claude Desktop using the provided build script (updated):

```bash
sudo dnf install rpm-build
# Clone this repository
git clone https://github.com/bsneed/claude-desktop-fedora.git
cd claude-desktop-fedora

# Build the package
sudo ./build-fedora.sh

# Install the package
# Check what file was actually created
ls build/electron-app/x86_64/

# Install using the correct filename (example - your version may differ)
sudo dnf install build/electron-app/x86_64/claude-desktop-*.rpm

# Download standalone Electron
# The installed Claude Desktop will have GTK conflicts with your system Electron. Download a clean Electron binary
cd /tmp
wget https://github.com/electron/electron/releases/download/v37.0.0/electron-v37.0.0-linux-x64.zip

# Extract into /opt
sudo unzip electron-v37.0.0-linux-x64.zip -d /opt
sudo mv /opt/electron-v37.0.0-linux-x64 /opt/electron
sudo chmod +x /opt/electron/electron

# Fix the Claude Desktop Script The default script will try to use your system Electron. Replace it with one that uses the standalone version:

# Backup the original script
sudo cp /usr/bin/claude-desktop /usr/bin/claude-desktop.backup

# Create the fixed script
sudo tee /usr/bin/claude-desktop << 'EOF'
#!/usr/bin/bash
LOG_FILE="$HOME/claude-desktop-launcher.log"

# Set environment to avoid GTK conflicts
export GDK_BACKEND=x11
export GTK_USE_PORTAL=0
export ELECTRON_DISABLE_SECURITY_WARNINGS=true

# Use the standalone electron installation
/opt/electron/electron /usr/lib64/claude-desktop/app.asar --ozone-platform-hint=auto --enable-logging=file --log-file=$LOG_FILE --log-level=INFO --disable-gpu-sandbox --no-sandbox "$@"
EOF

# Make it executable
sudo chmod +x /usr/bin/claude-desktop

# Launch Claude Desktop
claude-desktop

```

Installation video here : https://youtu.be/dvU1yJsyJ5k

Requirements:
- Fedora 41 Linux distribution
- Node.js >= 12.0.0 and npm
- Root/sudo access for dependency installation

## 2. Debian Package (New!)

For Debian users, please refer to [Aaddrick's claude-desktop-debian](https://github.com/aaddrick/claude-desktop-debian) repository.  Their implementation is specifically designed for Debian and provides the original build script that inspired THIS project.

## 3. NixOS Implementation

For NixOS users, please refer to [k3d3's claude-desktop-linux-flake](https://github.com/k3d3/claude-desktop-linux-flake) repository. Their implementation is specifically designed for NixOS and provides the original Nix flake that inspired this project.

# How it works

Claude Desktop is an Electron application packaged as a Windows executable. Our build script performs several key operations to make it work on Linux:

1. Downloads and extracts the Windows installer
2. Unpacks the app.asar archive containing the application code
3. Replaces the Windows-specific native module with a Linux-compatible implementation
4. Repackages everything into a proper RPM package

The process works because Claude Desktop is largely cross-platform, with only one platform-specific component that needs replacement.

## The Native Module Challenge

The only platform-specific component is a native Node.js module called `claude-native-bindings`. This module provides system-level functionality like:

- Keyboard input handling
- Window management
- System tray integration
- Monitor information

Our build script replaces this Windows-specific module with a Linux-compatible implementation that:

1. Provides the same API surface to maintain compatibility
2. Implements keyboard handling using the correct key codes from the reference implementation
3. Stubs out unnecessary Windows-specific functionality
4. Maintains critical features like the Ctrl+Alt+Space popup and system tray

The replacement module is carefully designed to match the original API while providing Linux-native functionality where needed. This approach allows the rest of the application to run unmodified, believing it's still running on Windows.

## Build Process Details

> Note: The build script was generated by Claude (Anthropic) to help create a Linux-compatible version of Claude Desktop.

The build script (`build-fedora.sh`) handles the entire process:

1. Checks for a Fedora-based system and required dependencies
2. Downloads the official Windows installer
3. Extracts the application resources
4. Processes icons for Linux desktop integration
5. Unpacks and modifies the app.asar:
   - Replaces the native module with our Linux version
   - Updates keyboard key mappings
   - Preserves all other functionality
6. Creates a proper RPM package with:
   - Desktop entry for application menus
   - System-wide icon integration
   - Proper dependency management
   - Post-install configuration

## Updating the Build Script

When a new version of Claude Desktop is released, simply update the `CLAUDE_DOWNLOAD_URL` constant at the top of `build-deb.sh` to point to the new installer. The script will handle everything else automatically.

# License

The build scripts in this repository, are dual-licensed under the terms of the MIT license and the Apache License (Version 2.0).

See [LICENSE-MIT](LICENSE-MIT) and [LICENSE-APACHE](LICENSE-APACHE) for details.

The Claude Desktop application, not included in this repository, is likely covered by [Anthropic's Consumer Terms](https://www.anthropic.com/legal/consumer-terms).

## Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any
additional terms or conditions.
# claude-desktop-fedora
