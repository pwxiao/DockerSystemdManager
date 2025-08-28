#!/bin/bash

# Docker 自启动工具集安装脚本
# 作者: AI Assistant
# 版本: 1.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}[HEADER]${NC} $1"
}

# 显示欢迎信息
show_welcome() {
    cat << EOF
╔══════════════════════════════════════════════════════════════╗
║                    Docker 自启动工具集                        ║
║                                                              ║
║  基于 Systemd 的 Docker 容器自启动管理解决方案                ║
║                                                              ║
║  功能特性:                                                   ║
║  • 一键创建 Docker 容器自启动服务                            ║
║  • 完整的服务生命周期管理                                    ║
║  • 实时监控和日志查看                                        ║
║  • 服务配置备份和恢复                                        ║
║  • 自动重启和故障恢复                                        ║
║                                                              ║
║  作者: AI Assistant                                          ║
║  版本: 1.0                                                   ║
╚══════════════════════════════════════════════════════════════╝

EOF
}

# 检查系统要求
check_system_requirements() {
    log_header "检查系统要求"
    
    # 检查操作系统
    if [[ -f /etc/redhat-release ]]; then
        log_info "检测到 Red Hat 系列系统"
    elif [[ -f /etc/debian_version ]]; then
        log_info "检测到 Debian 系列系统"
    else
        log_warning "未知操作系统，可能不完全兼容"
    fi
    
    # 检查是否为 root 用户
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
    
    # 检查 systemd
    if ! command -v systemctl &> /dev/null; then
        log_error "systemd 未安装，此工具需要 systemd 支持"
        exit 1
    fi
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log_warning "Docker 未安装，将尝试自动安装"
        install_docker
    else
        log_success "Docker 已安装"
        docker --version
    fi
    
    # 检查 jq (可选)
    if ! command -v jq &> /dev/null; then
        log_warning "jq 未安装，某些功能可能受限"
        log_info "建议安装 jq: yum install -y jq 或 apt-get install -y jq"
    fi
}

# 安装 Docker
install_docker() {
    log_header "安装 Docker"
    
    if [[ -f /etc/redhat-release ]]; then
        log_info "在 Red Hat 系列系统上安装 Docker"
        
        # 更新系统包
        log_info "更新系统包..."
        yum update -y
        
        # 安装必需依赖
        log_info "安装必需依赖..."
        yum install -y yum-utils device-mapper-persistent-data lvm2
        
        # 添加 Docker 官方仓库
        log_info "添加 Docker 官方仓库..."
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        
        # 安装 Docker
        log_info "安装 Docker CE..."
        yum install -y docker-ce docker-ce-cli containerd.io
        
        # 启动并启用 Docker 服务
        log_info "启动 Docker 服务..."
        systemctl start docker
        systemctl enable docker
        
    elif [[ -f /etc/debian_version ]]; then
        log_info "在 Debian 系列系统上安装 Docker"
        
        # 更新系统包
        log_info "更新系统包..."
        apt-get update
        
        # 安装必需依赖
        log_info "安装必需依赖..."
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        
        # 添加 Docker 官方 GPG 密钥
        log_info "添加 Docker 官方 GPG 密钥..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # 添加 Docker 官方仓库
        log_info "添加 Docker 官方仓库..."
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # 更新包索引
        apt-get update
        
        # 安装 Docker
        log_info "安装 Docker CE..."
        apt-get install -y docker-ce docker-ce-cli containerd.io
        
        # 启动并启用 Docker 服务
        log_info "启动 Docker 服务..."
        systemctl start docker
        systemctl enable docker
    else
        log_error "不支持的操作系统，请手动安装 Docker"
        exit 1
    fi
    
    # 验证安装
    if docker --version; then
        log_success "Docker 安装成功"
        docker run hello-world
    else
        log_error "Docker 安装失败"
        exit 1
    fi
}

# 安装工具集
install_tools() {
    log_header "安装 Docker 自启动工具集"
    
    # 创建安装目录
    local install_dir="/usr/local/bin"
    log_info "安装目录: $install_dir"
    
    # 复制脚本文件
    log_info "复制工具脚本..."
    
    if [[ -f "docker-autostart-tool.sh" ]]; then
        cp docker-autostart-tool.sh "$install_dir/docker-autostart"
        chmod +x "$install_dir/docker-autostart"
        log_success "docker-autostart 工具安装完成"
    else
        log_error "找不到 docker-autostart-tool.sh 文件"
        exit 1
    fi
    
    if [[ -f "docker-service-manager.sh" ]]; then
        cp docker-service-manager.sh "$install_dir/docker-service-manager"
        chmod +x "$install_dir/docker-service-manager"
        log_success "docker-service-manager 工具安装完成"
    else
        log_error "找不到 docker-service-manager.sh 文件"
        exit 1
    fi
    
    # 创建软链接
    log_info "创建命令别名..."
    ln -sf "$install_dir/docker-autostart" "$install_dir/das"
    ln -sf "$install_dir/docker-service-manager" "$install_dir/dsm"
    
    log_success "工具集安装完成"
}

# 创建配置文件
create_config() {
    log_header "创建配置文件"
    
    local config_dir="/etc/docker-autostart"
    mkdir -p "$config_dir"
    
    # 创建默认配置文件
    cat > "$config_dir/config.json" << EOF
{
    "default_options": {
        "log_driver": "journald",
        "restart_policy": "always",
        "auto_remove": false
    },
    "backup_dir": "/var/backups/docker-services",
    "log_retention_days": 30,
    "monitor_interval": 5
}
EOF
    
    log_success "配置文件创建完成: $config_dir/config.json"
}

# 创建示例服务
create_examples() {
    log_header "创建示例服务"
    
    log_info "创建 Nginx 示例服务..."
    if docker-autostart mynginx nginx:latest -p 8080:80 -d "Nginx Web Server Example" 2>/dev/null; then
        log_success "Nginx 示例服务创建成功"
    else
        log_warning "Nginx 示例服务创建失败（可能已存在）"
    fi
    
    log_info "创建 Redis 示例服务..."
    if docker-autostart myredis redis:7 -p 6379:6379 -m 256m -d "Redis Cache Server Example" 2>/dev/null; then
        log_success "Redis 示例服务创建成功"
    else
        log_warning "Redis 示例服务创建失败（可能已存在）"
    fi
}

# 显示使用说明
show_usage_guide() {
    log_header "使用说明"
    
    cat << EOF

🎉 安装完成！您现在可以使用以下命令：

📦 创建自启动服务:
   docker-autostart <服务名> <镜像名> [选项]
   或简写: das <服务名> <镜像名> [选项]

🔧 管理服务:
   docker-service-manager <命令> [选项]
   或简写: dsm <命令> [选项]

📋 常用命令示例:

1. 创建服务:
   das myapp nginx:latest -p 8080:80 -d "My Web App"
   das myapi myapi:v1.0 -p 3000:3000 -e "NODE_ENV=production"

2. 管理服务:
   dsm list                    # 列出所有服务
   dsm status myapp           # 查看服务状态
   dsm logs myapp -f          # 实时查看日志
   dsm restart myapp          # 重启服务
   dsm monitor                # 监控所有服务

3. 删除服务:
   dsm remove myapp           # 删除服务

📖 更多帮助:
   das --help                 # 查看创建工具帮助
   dsm --help                 # 查看管理工具帮助

🔍 示例服务:
   已为您创建了示例服务，可以使用以下命令查看：
   dsm list                   # 查看所有服务
   dsm status mynginx         # 查看 Nginx 服务状态
   dsm status myredis         # 查看 Redis 服务状态

EOF
}

# 验证安装
verify_installation() {
    log_header "验证安装"
    
    # 检查命令是否可用
    if command -v docker-autostart &> /dev/null; then
        log_success "docker-autostart 命令可用"
    else
        log_error "docker-autostart 命令不可用"
    fi
    
    if command -v docker-service-manager &> /dev/null; then
        log_success "docker-service-manager 命令可用"
    else
        log_error "docker-service-manager 命令不可用"
    fi
    
    if command -v das &> /dev/null; then
        log_success "das 简写命令可用"
    else
        log_error "das 简写命令不可用"
    fi
    
    if command -v dsm &> /dev/null; then
        log_success "dsm 简写命令可用"
    else
        log_error "dsm 简写命令不可用"
    fi
    
    # 检查 Docker 服务状态
    if systemctl is-active --quiet docker; then
        log_success "Docker 服务运行正常"
    else
        log_warning "Docker 服务未运行"
    fi
}

# 主函数
main() {
    show_welcome
    
    # 检查系统要求
    check_system_requirements
    
    # 安装工具集
    install_tools
    
    # 创建配置文件
    create_config
    
    # 创建示例服务
    create_examples
    
    # 验证安装
    verify_installation
    
    # 显示使用说明
    show_usage_guide
    
    log_success "🎉 Docker 自启动工具集安装完成！"
    log_info "请重新登录终端或运行 'source ~/.bashrc' 以确保命令可用"
}

# 运行主函数
main "$@"
