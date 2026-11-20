
#!/bin/bash

set -Eeuo pipefail

PANEL_DIR="/var/www/pterodactyl"
ZIP_URL="https://raw.githubusercontent.com/kaanaltacc67-hub/arixx/main/files.zip"
ZIP_FILE="$PANEL_DIR/files.zip"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

info() {
    echo -e "${YELLOW}[INFO] $1${NC}"
}

# Root check
if [[ $EUID -ne 0 ]]; then
    error "Please run this script as root: sudo bash install.sh"
fi

# OS check
if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect operating system."
fi

source /etc/os-release

if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
    error "Only Ubuntu and Debian-based systems are supported."
fi

if [[ "$ID" == "ubuntu" ]]; then
    if [[ "${VERSION_ID%%.*}" != "22" && "${VERSION_ID%%.*}" != "24" ]]; then
        error "Supported Ubuntu versions: 22.04 and 24.04."
    fi
fi

echo ""
echo "======================================"
echo "       ARIX THEME INSTALLER"
echo "======================================"
echo ""

# Panel directory check
if [[ ! -d "$PANEL_DIR" ]]; then
    error "Pterodactyl panel directory not found: $PANEL_DIR"
fi

success "Pterodactyl panel directory found."

# Dependency question
echo ""
echo "Did you install panel dependencies from:"
echo "https://docs.pterodactyl.io/v1/guides/customization/panel"
echo ""
echo "[1] No, install for me"
echo "[2] Yes"
echo "[3] No (end the script)"
echo ""

read -rp "Choose an option [1-3]: " choice

case "$choice" in
    1)
        info "Installing panel dependencies..."
        ;;
    2)
        info "Skipping dependency installation."
        ;;
    3)
        info "Installation cancelled."
        exit 0
        ;;
    *)
        error "Invalid option."
        ;;
esac

# Install Node.js and Yarn
info "Installing Node.js 22..."

apt-get update -y
apt-get install -y curl ca-certificates

curl -fsSL https://deb.nodesource.com/setup_22.x | bash -

apt-get install -y nodejs

info "Installing Yarn..."

npm install -g yarn

# Build panel
cd "$PANEL_DIR"

info "Installing panel packages..."
yarn

export NODE_OPTIONS=--openssl-legacy-provider

info "Building production assets..."
yarn build:production

success "Panel build completed!"

# Arix installation question
echo ""
echo "======================================"
read -rp "Do you want to continue installing Arix Theme? [y/N]: " arix_choice

case "$arix_choice" in
    [yY]|[yY][eE][sS])
        info "Continuing with Arix Theme installation..."
        ;;
    *)
        info "Arix Theme installation skipped."
        exit 0
        ;;
esac

# Download Arix files
info "Downloading Arix Theme..."

cd "$PANEL_DIR"

curl -fL "$ZIP_URL" -o "$ZIP_FILE" || error "Failed to download Arix files."

# Extract ZIP
info "Extracting Arix Theme..."

apt-get install -y unzip

unzip -o "$ZIP_FILE" -d "$PANEL_DIR" || error "Failed to extract Arix files."

# Remove ZIP
rm -f "$ZIP_FILE"

success "Arix files extracted."

# Run Arix installer
info "Running Arix installer..."

cd "$PANEL_DIR"

php install arix

success "Arix Theme installation completed!"

echo ""
echo "======================================"
success "INSTALLATION FINISHED!"
echo "======================================"
