#!/bin/bash
set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
CLAUDE_CODE_DIR="${HOME}/.claude-code"
CLAUDE_CODE_BIN="${HOME}/.local/bin/claude-code"
CLAUDE_CODE_SYMLINK="/usr/local/bin/claude-code"  # Linux/macOS
CLAUDE_CODE_SYMLINK_WIN="${HOME}/bin/claude-code" # Windows

# 版本信息
VERSION="latest"
GITHUB_REPO="anthropics/claude-code"  # 请替换为实际的 Claude Code 仓库

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

# 解析参数
OS=""
ARCH=""
ACTION="install"

while [[ $# -gt 0 ]]; do
    case $1 in
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

# 自动检测操作系统
detect_os() {
    if [ -n "$OS" ]; then
        echo "$OS"
        return
    fi
    
    case "$(uname -s)" in
        Darwin*)    echo "macos" ;;
        Linux*)     echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

# 自动检测架构
detect_arch() {
    if [ -n "$ARCH" ]; then
        echo "$ARCH"
        return
    fi
    
    case "$(uname -m)" in
        x86_64)  echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        *)       echo "unknown" ;;
    esac
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 卸载 Claude Code
uninstall() {
    print_info "Uninstalling Claude Code..."
    
    local os=$(detect_os)
    local removed=0
    
    # 删除主要安装目录
    if [ -d "$CLAUDE_CODE_DIR" ]; then
        print_info "Removing $CLAUDE_CODE_DIR"
        rm -rf "$CLAUDE_CODE_DIR"
        removed=1
    fi
    
    # 删除用户 bin 目录中的二进制文件
    if [ -f "$CLAUDE_CODE_BIN" ]; then
        print_info "Removing $CLAUDE_CODE_BIN"
        rm -f "$CLAUDE_CODE_BIN"
        removed=1
    fi
    
    # 根据操作系统删除系统链接
    case "$os" in
        macos|linux)
            if [ -L "$CLAUDE_CODE_SYMLINK" ] || [ -f "$CLAUDE_CODE_SYMLINK" ]; then
                print_info "Removing $CLAUDE_CODE_SYMLINK (requires sudo)"
                sudo rm -f "$CLAUDE_CODE_SYMLINK" 2>/dev/null || {
                    print_warning "Cannot remove $CLAUDE_CODE_SYMLINK, please run: sudo rm -f $CLAUDE_CODE_SYMLINK"
                }
                removed=1
            fi
            ;;
        windows)
            if [ -f "$CLAUDE_CODE_SYMLINK_WIN" ]; then
                print_info "Removing $CLAUDE_CODE_SYMLINK_WIN"
                rm -f "$CLAUDE_CODE_SYMLINK_WIN"
                removed=1
            fi
            ;;
    esac
    
    # 删除 PATH 中的其他可能位置
    for path in "/usr/local/bin/claude-code" "${HOME}/.local/bin/claude-code" "${HOME}/bin/claude-code"; do
        if [ -f "$path" ] || [ -L "$path" ]; then
            print_info "Removing $path"
            rm -f "$path" 2>/dev/null || sudo rm -f "$path" 2>/dev/null
        fi
    done
    
    # 清理配置文件（可选，注释掉以保留配置）
    # if [ -f "${HOME}/.claude-code-config.json" ]; then
    #     read -p "Remove configuration file? (y/N): " -n 1 -r
    #     echo
    #     if [[ $REPLY =~ ^[Yy]$ ]]; then
    #         rm -f "${HOME}/.claude-code-config.json"
    #     fi
    # fi
    
    if [ $removed -eq 1 ]; then
        print_success "Claude Code has been uninstalled"
    else
        print_warning "Claude Code installation not found"
    fi
    
    # 清理 PATH 中的条目（提示用户）
    print_info "If you added Claude Code to your PATH manually, please remove it from your shell config file (~/.bashrc, ~/.zshrc, etc.)"
}

# macOS 安装
install_macos() {
    local arch=$1
    print_info "Installing Claude Code for macOS (${arch})..."
    
    # 创建目录
    mkdir -p "${CLAUDE_CODE_DIR}"
    mkdir -p "${HOME}/.local/bin"
    
    # 确定下载 URL（这里需要替换为实际的下载链接）
    local download_url
    if [ "$arch" = "amd64" ]; then
        download_url="https://github.com/${GITHUB_REPO}/releases/${VERSION}/download/claude-code-darwin-amd64"
    else
        download_url="https://github.com/${GITHUB_REPO}/releases/${VERSION}/download/claude-code-darwin-arm64"
    fi
    
    # 下载
    print_info "Downloading from ${download_url}"
    if command_exists curl; then
        curl -L -o "${CLAUDE_CODE_DIR}/claude-code" "$download_url"
    elif command_exists wget; then
        wget -O "${CLAUDE_CODE_DIR}/claude-code" "$download_url"
    else
        print_error "Neither curl nor wget found"
        exit 1
    fi
    
    # 设置权限
    chmod +x "${CLAUDE_CODE_DIR}/claude-code"
    
    # 创建软链接
    ln -sf "${CLAUDE_CODE_DIR}/claude-code" "${CLAUDE_CODE_BIN}"
    
    # 尝试创建系统链接（需要 sudo）
    if [ -w "/usr/local/bin" ]; then
        ln -sf "${CLAUDE_CODE_DIR}/claude-code" "$CLAUDE_CODE_SYMLINK"
        print_success "Installed to ${CLAUDE_CODE_SYMLINK}"
    else
        print_warning "Cannot create symlink in /usr/local/bin, trying with sudo..."
        sudo ln -sf "${CLAUDE_CODE_DIR}/claude-code" "$CLAUDE_CODE_SYMLINK" 2>/dev/null || {
            print_warning "Installation completed but 'claude-code' command not in system PATH"
            print_info "Add ${HOME}/.local/bin to your PATH or run: export PATH=\$PATH:${HOME}/.local/bin"
        }
    fi
    
    print_success "Claude Code installed successfully!"
    print_info "Run 'claude-code' to start"
}

# Linux 安装
install_linux() {
    local arch=$1
    print_info "Installing Claude Code for Linux (${arch})..."
    
    # 创建目录
    mkdir -p "${CLAUDE_CODE_DIR}"
    mkdir -p "${HOME}/.local/bin"
    
    # 确定下载 URL
    local download_url
    if [ "$arch" = "amd64" ]; then
        download_url="https://github.com/${GITHUB_REPO}/releases/${VERSION}/download/claude-code-linux-amd64"
    else
        download_url="https://github.com/${GITHUB_REPO}/releases/${VERSION}/download/claude-code-linux-arm64"
    fi
    
    # 下载
    print_info "Downloading from ${download_url}"
    if command_exists curl; then
        curl -L -o "${CLAUDE_CODE_DIR}/claude-code" "$download_url"
    elif command_exists wget; then
        wget -O "${CLAUDE_CODE_DIR}/claude-code" "$download_url"
    else
        print_error "Neither curl nor wget found"
        exit 1
    fi
    
    # 设置权限
    chmod +x "${CLAUDE_CODE_DIR}/claude-code"
    
    # 创建软链接
    ln -sf "${CLAUDE_CODE_DIR}/claude-code" "${CLAUDE_CODE_BIN}"
    
    # 尝试创建系统链接
    if [ -w "/usr/local/bin" ]; then
        ln -sf "${CLAUDE_CODE_DIR}/claude-code" "$CLAUDE_CODE_SYMLINK"
        print_success "Installed to ${CLAUDE_CODE_SYMLINK}"
    else
        print_warning "Cannot create symlink in /usr/local/bin, trying with sudo..."
        sudo ln -sf "${CLAUDE_CODE_DIR}/claude-code" "$CLAUDE_CODE_SYMLINK" 2>/dev/null || {
            print_warning "Installation completed but 'claude-code' command not in system PATH"
            print_info "Add ${HOME}/.local/bin to your PATH or run: export PATH=\$PATH:${HOME}/.local/bin"
        }
    fi
    
    print_success "Claude Code installed successfully!"
    print_info "Run 'claude-code' to start"
}

# Windows 安装
install_windows() {
    local arch=$1
    print_info "Installing Claude Code for Windows (${arch})..."
    
    # 创建目录
    mkdir -p "${CLAUDE_CODE_DIR}"
    mkdir -p "${HOME}/bin"
    
    # 确定下载 URL
    local download_url
    if [ "$arch" = "amd64" ]; then
        download_url="https://github.com/${GITHUB_REPO}/releases/${VERSION}/download/claude-code-windows-amd64.exe"
    else
        download_url="https://github.com/${GITHUB_REPO}/releases/${VERSION}/download/claude-code-windows-arm64.exe"
    fi
    
    # 下载
    print_info "Downloading from ${download_url}"
    if command_exists curl; then
        curl -L -o "${CLAUDE_CODE_DIR}/claude-code.exe" "$download_url"
    elif command_exists wget; then
        wget -O "${CLAUDE_CODE_DIR}/claude-code.exe" "$download_url"
    else
        print_error "Neither curl nor wget found"
        exit 1
    fi
    
    # 创建批处理包装器
    cat > "${CLAUDE_CODE_BIN_WIN}" << EOF
@echo off
"${CLAUDE_CODE_DIR//\//\\}\\claude-code.exe" %*
EOF
    
    chmod +x "${CLAUDE_CODE_BIN_WIN}"
    
    # 添加到 PATH（Git Bash 环境）
    ln -sf "${CLAUDE_CODE_DIR}/claude-code.exe" "${CLAUDE_CODE_SYMLINK_WIN}" 2>/dev/null || {
        print_warning "Add ${HOME}/bin to your PATH to use 'claude-code' command"
    }
    
    print_success "Claude Code installed successfully!"
    print_info "Run 'claude-code' from Git Bash or PowerShell"
}

# 主安装函数
install() {
    local os=$(detect_os)
    local arch=$(detect_arch)
    
    print_info "Starting Claude Code installation..."
    print_info "OS: ${os}, Architecture: ${arch}"
    
    # 检查是否已安装
    if command_exists claude-code; then
        print_warning "Claude Code is already installed"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled"
            exit 0
        fi
        print_info "Reinstalling Claude Code..."
        uninstall
    fi
    
    # 根据操作系统安装
    case "$os" in
        macos)
            install_macos "$arch"
            ;;
        linux)
            install_linux "$arch"
            ;;
        windows)
            install_windows "$arch"
            ;;
        *)
            print_error "Unsupported operating system: $os"
            exit 1
            ;;
    esac
    
    # 验证安装
    if command_exists claude-code; then
        print_success "Installation verified!"
        claude-code --version 2>/dev/null || true
    else
        print_warning "Installation completed but 'claude-code' command not found in PATH"
        print_info "You may need to restart your terminal or add ${HOME}/.local/bin to PATH"
    fi
}

# 主函数
main() {
    if [ "$ACTION" = "uninstall" ]; then
        uninstall
    else
        install
    fi
}

# 执行主函数
main