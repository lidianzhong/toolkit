#!/bin/bash
set -euo pipefail

# Color output
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

# Paths
LOCAL_BIN="${HOME}/.local/bin"
CLAUDE_BIN="${LOCAL_BIN}/claude"
CLAUDE_CODE_SHIM="${LOCAL_BIN}/claude-code"

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
            print_info "Running: curl -fsSL https://claude.ai/install.sh | bash"
            curl -fsSL https://claude.ai/install.sh | bash
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
