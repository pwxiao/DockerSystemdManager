#!/bin/bash

# Docker 容器自启动服务创建工具
# 基于 Systemd 的 Docker 容器自启动方案
# 作者: AI Assistant
# 版本: 1.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 显示帮助信息
show_help() {
    cat << EOF
Docker 容器自启动服务创建工具

用法: $0 [选项] <服务名称> <镜像名称>

选项:
    -p, --port <端口映射>      容器端口映射 (格式: 主机端口:容器端口)
    -e, --env <环境变量>       环境变量 (格式: KEY=VALUE)
    -v, --volume <卷映射>      卷映射 (格式: 主机路径:容器路径)
    -n, --network <网络>       指定网络
    -m, --memory <内存限制>    内存限制 (如: 512m, 1g)
    -c, --cpu <CPU限制>        CPU限制 (如: 0.5, 1.0)
    --gpus <GPU配置>           GPU配置 (如: all, device=0,1)
    --runtime <运行时>         容器运行时 (如: nvidia)
    -d, --description <描述>   服务描述
    -f, --force                强制覆盖已存在的服务
    -h, --help                 显示此帮助信息

示例:
    $0 myapp nginx:latest -p 8080:80 -d "Nginx Web Server"
    $0 myredis redis:7 -p 6379:6379 -m 256m -d "Redis Cache Server"
    $0 myapp myapp:latest -p 3000:3000 -e "NODE_ENV=production" -v "/data:/app/data"
    $0 comfyui comfyui:latest -p 8188:8188 --gpus all --runtime nvidia -d "ComfyUI AI服务"

EOF
}

# 验证参数
validate_params() {
    if [[ $# -lt 2 ]]; then
        log_error "参数不足"
        show_help
        exit 1
    fi
    
    SERVICE_NAME="$1"
    IMAGE_NAME="$2"
    
    # 验证服务名称格式
    if [[ ! $SERVICE_NAME =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "服务名称只能包含字母、数字、下划线和连字符"
        exit 1
    fi
    
    # 检查服务是否已存在
    if systemctl list-unit-files | grep -q "^${SERVICE_NAME}.service" && [[ "$FORCE" != "true" ]]; then
        log_error "服务 ${SERVICE_NAME} 已存在，使用 -f 参数强制覆盖"
        exit 1
    fi
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! systemctl is-active --quiet docker; then
        log_warning "Docker 服务未运行，正在启动..."
        systemctl start docker
    fi
}

# 生成 Docker 运行命令
generate_docker_run_cmd() {
    local cmd="/usr/bin/docker run --log-driver=journald --name ${SERVICE_NAME}"
    
    # 添加端口映射
    if [[ -n "$PORT_MAPPING" ]]; then
        cmd="$cmd -p $PORT_MAPPING"
    fi
    
    # 添加环境变量
    if [[ -n "$ENV_VARS" ]]; then
        for env in "${ENV_VARS[@]}"; do
            cmd="$cmd -e \"$env\""
        done
    fi
    
    # 添加卷映射
    if [[ -n "$VOLUME_MAPPINGS" ]]; then
        for vol in "${VOLUME_MAPPINGS[@]}"; do
            cmd="$cmd -v \"$vol\""
        done
    fi
    
    # 添加网络
    if [[ -n "$NETWORK" ]]; then
        cmd="$cmd --network $NETWORK"
    fi
    
    # 添加内存限制
    if [[ -n "$MEMORY_LIMIT" ]]; then
        cmd="$cmd --memory $MEMORY_LIMIT"
    fi
    
    # 添加CPU限制
    if [[ -n "$CPU_LIMIT" ]]; then
        cmd="$cmd --cpus $CPU_LIMIT"
    fi
    
    # 添加GPU支持
    if [[ -n "$GPUS" ]]; then
        cmd="$cmd --gpus $GPUS"
    fi
    
    # 添加运行时
    if [[ -n "$RUNTIME" ]]; then
        cmd="$cmd --runtime $RUNTIME"
    fi
    
    # 添加镜像名称
    cmd="$cmd $IMAGE_NAME"
    
    echo "$cmd"
}

# 创建 systemd service 文件
create_service_file() {
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    local docker_run_cmd=$(generate_docker_run_cmd)
    local description="${SERVICE_DESCRIPTION:-"Docker Container ${SERVICE_NAME}"}"
    
    log_info "创建服务文件: $service_file"
    
    cat > "$service_file" << EOF
[Unit]
Description=${description}
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStartPre=-/usr/bin/docker rm -f ${SERVICE_NAME}
ExecStart=${docker_run_cmd}
ExecStop=/usr/bin/docker stop ${SERVICE_NAME}
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    log_success "服务文件创建成功"
}

# 启用并启动服务
enable_and_start_service() {
    log_info "重新加载 systemd 配置..."
    systemctl daemon-reload
    
    log_info "启用服务开机自启动..."
    systemctl enable "${SERVICE_NAME}.service"
    
    log_info "启动服务..."
    if systemctl start "${SERVICE_NAME}.service"; then
        log_success "服务启动成功"
    else
        log_error "服务启动失败"
        systemctl status "${SERVICE_NAME}.service" --no-pager
        exit 1
    fi
}

# 显示服务信息
show_service_info() {
    log_info "服务创建完成！"
    echo
    echo "服务信息:"
    echo "  名称: ${SERVICE_NAME}"
    echo "  镜像: ${IMAGE_NAME}"
    echo "  描述: ${SERVICE_DESCRIPTION:-"Docker Container ${SERVICE_NAME}"}"
    
    if [[ -n "$PORT_MAPPING" ]]; then
        echo "  端口映射: $PORT_MAPPING"
    fi
    
    if [[ -n "$ENV_VARS" ]]; then
        echo "  环境变量:"
        for env in "${ENV_VARS[@]}"; do
            echo "    $env"
        done
    fi
    
    if [[ -n "$VOLUME_MAPPINGS" ]]; then
        echo "  卷映射:"
        for vol in "${VOLUME_MAPPINGS[@]}"; do
            echo "    $vol"
        done
    fi
    
    echo
    echo "管理命令:"
    echo "  查看状态: systemctl status ${SERVICE_NAME}"
    echo "  启动服务: systemctl start ${SERVICE_NAME}"
    echo "  停止服务: systemctl stop ${SERVICE_NAME}"
    echo "  重启服务: systemctl restart ${SERVICE_NAME}"
    echo "  查看日志: journalctl -u ${SERVICE_NAME} -f"
    echo "  查看容器: docker logs ${SERVICE_NAME}"
}

# 主函数
main() {
    # 解析命令行参数
    local args=()
    local ENV_VARS=()
    local VOLUME_MAPPINGS=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--port)
                PORT_MAPPING="$2"
                shift 2
                ;;
            -e|--env)
                ENV_VARS+=("$2")
                shift 2
                ;;
            -v|--volume)
                VOLUME_MAPPINGS+=("$2")
                shift 2
                ;;
            -n|--network)
                NETWORK="$2"
                shift 2
                ;;
            -m|--memory)
                MEMORY_LIMIT="$2"
                shift 2
                ;;
            -c|--cpu)
                CPU_LIMIT="$2"
                shift 2
                ;;
            --gpus)
                GPUS="$2"
                shift 2
                ;;
            --runtime)
                RUNTIME="$2"
                shift 2
                ;;
            -d|--description)
                SERVICE_DESCRIPTION="$2"
                shift 2
                ;;
            -f|--force)
                FORCE="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    
    # 验证参数
    validate_params "${args[@]}"
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
    
    # 检查 Docker
    check_docker
    
    # 创建服务
    create_service_file
    enable_and_start_service
    show_service_info
}

# 运行主函数
main "$@"
