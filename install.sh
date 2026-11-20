
#!/usr/bin/env bash

set -Eeuo pipefail

# ==========================================
#             ARIX THEME INSTALLER
# ==========================================

PANEL_DIR="/var/www/pterodactyl"
ZIP_URL="https://github.com/kaanaltacc67-hub/arixx/files.zip"
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
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# ==========================================
# TERMINAL INPUT
# ==========================================

# Use a separate file descriptor for terminal input.
# This allows curl | sudo bash to work correctly.

if ! { exec 3<>/dev/tty; } 2>/dev/null; then
    error "No interactive terminal available."
fi

ask() {
    local prompt="$1"
    local variable="$2"

    printf "%b" "$prompt" >/dev/tty

    IFS= read -r -u 3 "$variable" || error "Failed to read terminal input."
}

# ==========================================
# ROOT CHECK
# ==========================================

if [[ "$EUID" -ne 0 ]]; then
    error "Please run this installer as root."
fi

# ==========================================
# OPERATING SYSTEM CHECK
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
                error "Supported Ubuntu versions: 22.04 and 24.04."
                ;;
        esac
        ;;

    debian)
        case "$VERSION_ID" in
            11|12|13)
                success "Debian $VERSION_ID detected."
                ;;
            *)
                error "Supported Debian versions: 11, 12 and 13."
                ;;
        esac
        ;;

    *)
        error "Unsupported operating system: $ID"
        ;;
esac

# ==========================================
# PANEL DIRECTORY CHECK
# ==========================================

echo ""
echo "======================================"
echo "       ARIX THEME INSTALLER"
echo "======================================"
echo ""

if [[ ! -d "$PANEL_DIR" ]]; then
    error "Pterodactyl panel directory not found: $PANEL_DIR"
fi

if [[ ! -f "$PANEL_DIR/package.json" ]]; then
    error "Pterodactyl package.json not found."
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

ask "Choose an option [1-3]: " choice

case "$choice" in
    1)
        info "Installing panel build dependencies..."

        apt-get update -y
        apt-get install -y curl ca-certificates

        info "Setting up Node.js 22..."

        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -

        apt-get install -y nodejs

        info "Installing Yarn..."

        npm install -g yarn

        success "Dependencies installed."
        ;;

    2)
        info "Checking installed dependencies..."

        command -v node >/dev/null 2>&1 || error "Node.js is not installed."
        command -v npm >/dev/null 2>&1 || error "NPM is not installed."
        command -v yarn >/dev/null 2>&1 || error "Yarn is not installed."

        NODE_VERSION=$(node -p "Number(process.versions.node.split('.')[0])")

        if [[ "$NODE_VERSION" -lt 22 ]]; then
            error "Node.js 22 or newer is required."
        fi

        success "Dependencies found."
        ;;

    3)
        info "Installation cancelled."
        exit 0
        ;;

    *)
        error "Invalid option. Please choose 1, 2 or 3."
        ;;
esac

# ==========================================
# INSTALL BUILD TOOLS
# ==========================================

apt-get install -y curl ca-certificates unzip

# ==========================================
# BUILD PANEL
# ==========================================

cd "$PANEL_DIR"

info "Installing panel packages..."

yarn

info "Building production assets..."

export NODE_OPTIONS=--openssl-legacy-provider

yarn build:production

success "Panel build completed!"

# ==========================================
# ARIX THEME CONFIRMATION
# ==========================================

echo ""
echo "======================================"
echo "          ARIX THEME SETUP"
echo "======================================"
echo ""

ask "Do you want to continue installing Arix Theme? [y/N]: " arix_choice

case "$arix_choice" in
    y|Y|yes|YES|Yes)
        info "Continuing Arix Theme installation..."
        ;;
    *)
        info "Arix Theme installation skipped."
        exit 0
        ;;
esac

# ==========================================
# DOWNLOAD ARIX THEME
# ==========================================

cd "$PANEL_DIR"

info "Downloading Arix Theme files..."

rm -f "$ZIP_FILE"

curl -fL --retry 3 "$ZIP_URL" -o "$ZIP_FILE" \
    || error "Failed to download Arix Theme."

success "Arix Theme downloaded."

# ==========================================
# EXTRACT FILES
# ==========================================

info "Extracting Arix Theme files..."

unzip -o "$ZIP_FILE" -d "$PANEL_DIR" \
    || error "Failed to extract Arix Theme."

# ==========================================
# REMOVE ZIP
# ==========================================

info "Removing downloaded ZIP..."

rm -f "$ZIP_FILE"

success "ZIP file removed."

# ==========================================
# RUN ARIX INSTALLER
# ==========================================

cd "$PANEL_DIR"

if ! command -v php >/dev/null 2>&1; then
    error "PHP is not installed."
fi

info "Running Arix installer..."

php install arix

success "Arix installer executed."

# ==========================================
# FINISHED
# ==========================================

echo ""
echo "======================================"
echo -e "${GREEN}       INSTALLATION FINISHED!${NC}"
echo "======================================"
