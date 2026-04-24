#!/bin/bash
set -euo pipefail

# 颜色定义
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m' # No Color

# 脚本配置
SCRIPT_URL_BASE="https://raw.githubusercontent.com/lidianzhong/toolkit/main"
INSTALL_SCRIPT="install-claude-code.sh"

# 打印函数
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

# 显示帮助信息
show_help() {
    cat << EOF
${GREEN}Toolkit Installer${NC}

Usage:
    curl -fsSL ${SCRIPT_URL_BASE}/install.sh | bash -s -- [command] [options]

Commands:
    claude-code              Install Claude Code
  claude-code --uninstall  Uninstall Claude Code
  help                     Show this help message

Examples:
  # Install Claude Code
    curl -fsSL ${SCRIPT_URL_BASE}/install.sh | bash -s -- claude-code
  
  # Uninstall Claude Code
    curl -fsSL ${SCRIPT_URL_BASE}/install.sh | bash -s -- claude-code --uninstall
  
  # Show help
    curl -fsSL ${SCRIPT_URL_BASE}/install.sh | bash -s -- help
EOF
}

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos" ;;
        Linux*)     echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

# 检测架构
detect_arch() {
    case "$(uname -m)" in
        x86_64)  echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        *)       echo "unknown" ;;
    esac
}

# 下载并执行安装脚本
run_install_script() {
    local action="${1:-install}"
    local os=$(detect_os)
    local arch=$(detect_arch)
    
    print_info "Detected OS: ${os}, Arch: ${arch}"
    print_info "Downloading ${INSTALL_SCRIPT}..."
    
    # 下载脚本
    local script_content
    if ! script_content=$(curl -fsSL "${SCRIPT_URL_BASE}/scripts/${INSTALL_SCRIPT}" 2>/dev/null); then
        print_error "Failed to download ${INSTALL_SCRIPT}"
        print_error "Please check your network connection"
        exit 1
    fi
    
    # 传递参数给子脚本
    if [ "$action" = "uninstall" ]; then
        print_info "Running uninstall..."
        echo "$script_content" | bash -s -- --uninstall --os "$os" --arch "$arch"
    else
        print_info "Running install..."
        echo "$script_content" | bash -s -- --os "$os" --arch "$arch"
    fi
}

# 主函数
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    local command="${1:-}"
    local option="${2:-}"
    
    case "$command" in
        claude-code)
            if [ "$option" = "--uninstall" ]; then
                run_install_script "uninstall"
            else
                run_install_script "install"
            fi
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
