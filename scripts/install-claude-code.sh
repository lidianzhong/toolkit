#!/bin/bash
set -euo pipefail

# Color output
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

# Paths
LOCAL_PREFIX="${HOME}/.local"
LOCAL_BIN="${HOME}/.local/bin"
CLAUDE_BIN="${LOCAL_BIN}/claude"
CLAUDE_CODE_SHIM="${LOCAL_BIN}/claude-code"
NPM_PACKAGE="@anthropic-ai/claude-code"

# Parsed args
OS=""
ARCH=""
ACTION="install"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

run_with_privilege() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command_exists sudo; then
        sudo "$@"
    else
        print_error "Root permission is required to install npm automatically"
        print_info "Please install Node.js/npm manually, then rerun this installer"
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --os)
            OS="$2"
            shift 2
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --uninstall)
            ACTION="uninstall"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

detect_os() {
    if [ -n "$OS" ]; then
        echo "$OS"
        return
    fi

    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*) echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

detect_arch() {
    if [ -n "$ARCH" ]; then
        echo "$ARCH"
        return
    fi

    case "$(uname -m)" in
        x86_64) echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        *) echo "unknown" ;;
    esac
}

ensure_unix_requirements() {
    if ! command_exists curl; then
        print_error "curl is required but not found"
        exit 1
    fi

    if ! command_exists bash; then
        print_error "bash is required but not found"
        exit 1
    fi
}

install_npm_linux() {
    if command_exists apt-get; then
        print_info "Installing npm via apt-get"
        run_with_privilege apt-get update
        run_with_privilege apt-get install -y nodejs npm
    elif command_exists dnf; then
        print_info "Installing npm via dnf"
        run_with_privilege dnf install -y nodejs npm
    elif command_exists yum; then
        print_info "Installing npm via yum"
        run_with_privilege yum install -y nodejs npm
    elif command_exists pacman; then
        print_info "Installing npm via pacman"
        run_with_privilege pacman -Sy --noconfirm nodejs npm
    elif command_exists zypper; then
        print_info "Installing npm via zypper"
        run_with_privilege zypper --non-interactive install nodejs npm
    elif command_exists apk; then
        print_info "Installing npm via apk"
        run_with_privilege apk add --no-cache nodejs npm
    else
        print_error "Unsupported Linux package manager for auto npm install"
        print_info "Please install Node.js/npm manually, then rerun this installer"
        exit 1
    fi
}

install_npm_macos() {
    if ! command_exists brew; then
        print_error "Homebrew is required to auto-install npm on macOS"
        print_info "Install Homebrew first, or install Node.js manually"
        exit 1
    fi

    print_info "Installing npm via Homebrew"
    brew install node
}

ensure_npm() {
    if ! command_exists npm; then
        print_warning "npm not found, trying to install automatically..."

        case "$(detect_os)" in
            linux)
                install_npm_linux
                ;;
            macos)
                install_npm_macos
                ;;
            *)
                print_error "Automatic npm installation is only supported on Linux/macOS"
                exit 1
                ;;
        esac

        if ! command_exists npm; then
            print_error "Automatic npm installation failed"
            print_info "Please install Node.js/npm manually, then rerun this installer"
            exit 1
        fi

        print_success "npm installed successfully"
    fi
}

install_via_npm_fallback() {
    ensure_npm

    mkdir -p "${LOCAL_PREFIX}" "${LOCAL_BIN}"
    print_warning "Falling back to npm install: ${NPM_PACKAGE}"
    npm install -g "${NPM_PACKAGE}" --prefix "${LOCAL_PREFIX}"
}

create_claude_code_shim() {
    mkdir -p "${LOCAL_BIN}"

    cat > "${CLAUDE_CODE_SHIM}" << 'EOF'
#!/bin/bash
exec "${HOME}/.local/bin/claude" "$@"
EOF
    chmod +x "${CLAUDE_CODE_SHIM}"
}

print_path_hint_if_needed() {
    case ":$PATH:" in
        *":${LOCAL_BIN}:"*) ;;
        *)
            print_warning "${LOCAL_BIN} is not in your PATH"
            print_info "Run: export PATH=\"${LOCAL_BIN}:\$PATH\""
            ;;
    esac
}

install() {
    local os
    local arch
    os=$(detect_os)
    arch=$(detect_arch)

    print_info "Starting Claude Code installation..."
    print_info "OS: ${os}, Architecture: ${arch}"

    case "$os" in
        linux|macos)
            ensure_unix_requirements

            local tmp_installer
            local http_code
            tmp_installer=$(mktemp)

            print_info "Running: curl -fsSL https://claude.ai/install.sh | bash"
            http_code=$(curl -sSL -w "%{http_code}" -o "${tmp_installer}" https://claude.ai/install.sh || true)

            if [ "${http_code}" = "200" ]; then
                bash "${tmp_installer}"
            else
                print_warning "Official installer request failed (HTTP ${http_code:-unknown})"
                install_via_npm_fallback
            fi

            rm -f "${tmp_installer}"
            ;;
        windows)
            if command_exists powershell.exe; then
                print_info "Running: irm https://claude.ai/install.ps1 | iex"
                powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://claude.ai/install.ps1 | iex"
            elif command_exists pwsh; then
                print_info "Running: irm https://claude.ai/install.ps1 | iex"
                pwsh -NoProfile -Command "irm https://claude.ai/install.ps1 | iex"
            else
                print_error "PowerShell not found. Please run in PowerShell: irm https://claude.ai/install.ps1 | iex"
                exit 1
            fi
            ;;
        *)
            print_error "Unsupported operating system: ${os}"
            exit 1
            ;;
    esac

    if command_exists claude && [ ! -x "${CLAUDE_CODE_SHIM}" ]; then
        create_claude_code_shim
        print_info "Created compatibility command: claude-code"
    fi

    if command_exists claude; then
        print_success "Claude installed successfully"
        claude --version 2>/dev/null || true
        print_info "Command available: claude"
    elif command_exists claude-code; then
        print_success "Claude Code installed successfully"
        claude-code --version 2>/dev/null || true
        print_info "Command available: claude-code"
    else
        print_warning "Install finished, but no claude command found in current PATH"
    fi

    print_path_hint_if_needed
}

uninstall() {
    print_info "Uninstalling Claude Code..."

    print_warning "Official installer uninstall is not handled automatically in this script"
    print_info "For Linux/macOS, rerun official installer uninstall if supported by your version"
    print_info "For Windows, run uninstall from PowerShell if available"

    if [ -f "${CLAUDE_CODE_SHIM}" ] || [ -L "${CLAUDE_CODE_SHIM}" ]; then
        rm -f "${CLAUDE_CODE_SHIM}"
        print_info "Removed ${CLAUDE_CODE_SHIM}"
    fi

    print_success "Uninstall finished"
    print_path_hint_if_needed
}

main() {
    if [ "$ACTION" = "uninstall" ]; then
        uninstall
    else
        install
    fi
}

main
