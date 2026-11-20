
#!/usr/bin/env bash

set -Eeuo pipefail

# ==========================================
# ARIX THEME INSTALLER
# ==========================================

PANEL_DIR="/var/www/pterodactyl"
ZIP_URL="https://raw.githubusercontent.com/kaanaltacc67-hub/arixx/main/files.zip"
ZIP_FILE="$PANEL_DIR/files.zip"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# ==========================================
# TERMINAL INPUT
# ==========================================

if [[ ! -r /dev/tty ]]; then
    error "Interactive terminal not found."
fi

ask() {
    local prompt="$1"
    local result

    read -r -p "$prompt" result </dev/tty || error "Input failed."
    REPLY="$result"
}

# ==========================================
# ROOT CHECK
# ==========================================

if [[ "$EUID" -ne 0 ]]; then
    error "Please run this script as root."
fi

# ==========================================
# OS CHECK
# ==========================================

if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect operating system."
fi

source /etc/os-release

case "$ID" in
    ubuntu)
        case "$VERSION_ID" in
            22.04|24.04)
                success "Ubuntu $VERSION_ID detected."
                ;;
            *)
                error "Only Ubuntu 22.04 and 24.04 are supported."
                ;;
        esac
        ;;

    debian)
        case "$VERSION_ID" in
            11|12|13)
                success "Debian $VERSION_ID detected."
                ;;
            *)
                error "Unsupported Debian version."
                ;;
        esac
        ;;

    *)
        error "Unsupported operating system: $ID"
        ;;
esac

# ==========================================
# PANEL CHECK
# ==========================================

echo ""
echo "======================================"
echo "       ARIX THEME INSTALLER"
echo "======================================"
echo ""

if [[ ! -d "$PANEL_DIR" ]]; then
    error "Pterodactyl directory not found."
fi

if [[ ! -f "$PANEL_DIR/package.json" ]]; then
    error "Invalid Pterodactyl directory."
fi

success "Pterodactyl panel directory found."

# ==========================================
# DEPENDENCY QUESTION
# ==========================================

echo ""
echo "Did you install panel dependencies from:"
echo "https://docs.pterodactyl.io/v1/guides/customization/panel"
echo ""
echo "[1] No, install for me"
echo "[2] Yes"
echo "[3] No (end the script)"
echo ""

ask "Choose an option [1-3]: "
choice="$REPLY"

case "$choice" in

    1)
        # Install Node.js 22 and Yarn

        info "Installing required packages..."

        apt-get update -y
        apt-get install -y curl ca-certificates unzip

        info "Installing Node.js 22..."

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

        success "Panel build completed."
        ;;

    2)
        # Skip ALL dependency installation and build operations.

        info "Skipping dependency installation."
        info "Skipping panel build."
        info "Proceeding directly to Arix installation."
        ;;

    3)
        info "Installation cancelled."
        exit 0
        ;;

    *)
        error "Invalid option: $choice"
        ;;
esac

# ==========================================
# ARIX CONFIRMATION
# ==========================================

echo ""
echo "======================================"
echo "          ARIX THEME SETUP"
echo "======================================"
echo ""

ask "Do you want to continue installing Arix Theme? [y/N]: "
arix_choice="$REPLY"

case "$arix_choice" in
    y|Y|yes|YES|Yes)
        info "Continuing Arix installation..."
        ;;
    *)
        info "Arix installation skipped."
        exit 0
        ;;
esac

# ==========================================
# INSTALL REQUIRED TOOLS
# ==========================================

info "Checking required tools..."

apt-get update -y
apt-get install -y curl unzip

# ==========================================
# DOWNLOAD ARIX
# ==========================================

cd "$PANEL_DIR"

info "Downloading Arix Theme..."

rm -f "$ZIP_FILE"

curl -fL --retry 3 "$ZIP_URL" -o "$ZIP_FILE" \
    || error "Failed to download Arix Theme."

success "Arix Theme downloaded."

# ==========================================
# EXTRACT ARIX
# ==========================================

info "Extracting Arix Theme..."

unzip -o "$ZIP_FILE" -d "$PANEL_DIR" \
    || error "Failed to extract Arix Theme."

success "Arix files extracted."

# ==========================================
# DELETE ZIP
# ==========================================

info "Removing ZIP file..."

rm -f "$ZIP_FILE"

success "ZIP file removed."

# ==========================================
# PHP CHECK
# ==========================================

command -v php >/dev/null 2>&1 \
    || error "PHP is not installed."

# ==========================================
# RUN ARIX INSTALLER
# ==========================================

cd "$PANEL_DIR"

echo ""
echo "======================================"
echo "       ARIX INSTALLATION"
echo "======================================"
echo ""

info "Starting Arix installer..."
info "Waiting for installer to finish..."
echo ""

# Run directly so all installer output is visible.
# Bash waits until PHP exits.

set +e
php arix install
INSTALL_EXIT_CODE=$?
set -e

echo ""

if [[ "$INSTALL_EXIT_CODE" -ne 0 ]]; then
    error "Arix installer failed with exit code: $INSTALL_EXIT_CODE"
fi

# ==========================================
# FINISHED
# ==========================================

echo ""
echo "======================================"
success "ARIX INSTALLATION FINISHED!"
echo "======================================"
