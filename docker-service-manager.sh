#!/bin/bash

# Docker 服务管理工具
# 用于管理基于 Systemd 的 Docker 容器自启动服务
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

# 显示帮助信息
show_help() {
    cat << EOF
Docker 服务管理工具

用法: $0 <命令> [选项]

命令:
    add <服务名>           添加新的 Docker 服务
    list                   列出所有 Docker 服务
    status <服务名>        查看服务状态
    start <服务名>         启动服务
    stop <服务名>          停止服务
    restart <服务名>       重启服务
    logs <服务名>          查看服务日志
    remove <服务名>        删除服务
    info <服务名>          显示服务详细信息
    backup <服务名>        备份服务配置
    restore <服务名> <文件> 恢复服务配置
    monitor                监控所有服务状态
    cleanup                清理已停止的容器

选项:
    -f, --image <镜像>     指定 Docker 镜像 (add 命令)
    -p, --port <端口映射>  指定端口映射 (add 命令，格式: 主机端口:容器端口)
    -d, --description <描述> 指定服务描述 (add 命令)
    -f, --follow           实时跟踪日志
    -n, --lines <行数>     显示日志行数 (默认: 50)
    -h, --help             显示此帮助信息

示例:
    $0 add myapp -f nginx:latest -p 8080:80 -d "Web Server"
    $0 list
    $0 status myapp
    $0 logs myapp -f
    $0 restart myapp
    $0 remove myapp
    $0 monitor

EOF
}

# 检查服务是否存在
check_service_exists() {
    local service_name="$1"
    if ! systemctl list-unit-files | grep -q "^${service_name}.service"; then
        log_error "服务 ${service_name} 不存在"
        exit 1
    fi
}

# 从服务文件中获取容器名称
get_container_name() {
    local service_name="$1"
    local service_file="/etc/systemd/system/${service_name}.service"
    local container_name="$service_name"  # 默认使用服务名称
    
    # 尝试从 ExecStart 行中提取容器名称
    if [[ -f "$service_file" ]] && grep -q "ExecStart" "$service_file"; then
        local exec_start_line=$(grep "ExecStart" "$service_file")
        # 使用 sed 提取 --name 参数后的容器名称
        local extracted_name=$(echo "$exec_start_line" | sed -n 's/.*--name \([^[:space:]]*\).*/\1/p')
        if [[ -n "$extracted_name" ]]; then
            container_name="$extracted_name"
        fi
    fi
    
    echo "$container_name"
}

# 列出所有 Docker 服务
list_services() {
    log_header "Docker 服务列表"
    echo
    
    # 查找所有包含 docker 命令的服务文件
    local services=""
    for service_file in /etc/systemd/system/*.service; do
        if [[ -f "$service_file" ]] && grep -q "docker" "$service_file"; then
            local service_name=$(basename "$service_file" .service)
            services="$services $service_name"
        fi
    done
    
    if [[ -z "$services" ]]; then
        log_warning "未找到 Docker 服务"
        return
    fi
    
    printf "%-20s %-15s %-15s %-20s\n" "服务名称" "状态" "容器状态" "端口映射"
    echo "--------------------------------------------------------------------------------"
    
    for service in $services; do
        local service_status=$(systemctl is-active "${service}.service" 2>/dev/null | tr -d '\n' || echo "inactive")
        local container_status="未运行"
        local port_mapping="无"
        
        # 从服务文件中获取容器名称
        local container_name=$(get_container_name "$service")
        
        if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
            container_status="运行中"
            # 获取端口映射
            local ports=$(docker port "$container_name" 2>/dev/null | head -1 | cut -d' ' -f3 | tr -d '\n')
            if [[ -n "$ports" ]]; then
                port_mapping="$ports"
            fi
        elif docker ps -a --format "table {{.Names}}" | grep -q "^${container_name}$"; then
            container_status="已停止"
        fi
        
        printf "%-20s %-15s %-15s %-20s\n" "$service" "$service_status" "$container_status" "$port_mapping"
    done
}

# 查看服务状态
show_service_status() {
    local service_name="$1"
    check_service_exists "$service_name"
    
    log_header "服务状态: $service_name"
    echo
    
    # Systemd 服务状态
    log_info "Systemd 服务状态:"
    systemctl status "${service_name}.service" --no-pager
    echo
    
    # 从服务文件中获取容器名称
    local container_name=$(get_container_name "$service_name")
    
    # 容器状态
    log_info "Docker 容器状态:"
    if docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -q "^${container_name}"; then
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | head -1
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep "^${container_name}"
    else
        if docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep -q "^${container_name}"; then
            log_warning "容器已停止"
            docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep "^${container_name}"
        else
            log_warning "容器不存在"
        fi
    fi
}

# 启动服务
start_service() {
    local service_name="$1"
    check_service_exists "$service_name"
    
    log_info "启动服务: $service_name"
    if systemctl start "${service_name}.service"; then
        log_success "服务启动成功"
        sleep 2
        show_service_status "$service_name"
    else
        log_error "服务启动失败"
        systemctl status "${service_name}.service" --no-pager
        exit 1
    fi
}

# 停止服务
stop_service() {
    local service_name="$1"
    check_service_exists "$service_name"
    
    log_info "停止服务: $service_name"
    if systemctl stop "${service_name}.service"; then
        log_success "服务停止成功"
    else
        log_error "服务停止失败"
        systemctl status "${service_name}.service" --no-pager
        exit 1
    fi
}

# 重启服务
restart_service() {
    local service_name="$1"
    check_service_exists "$service_name"
    
    log_info "重启服务: $service_name"
    if systemctl restart "${service_name}.service"; then
        log_success "服务重启成功"
        sleep 2
        show_service_status "$service_name"
    else
        log_error "服务重启失败"
        systemctl status "${service_name}.service" --no-pager
        exit 1
    fi
}

# 查看服务日志
show_service_logs() {
    local service_name="$1"
    local follow="$2"
    local lines="${3:-50}"
    
    check_service_exists "$service_name"
    
    log_header "服务日志: $service_name"
    echo
    
    # Systemd 日志
    log_info "Systemd 服务日志:"
    if [[ "$follow" == "true" ]]; then
        journalctl -u "${service_name}.service" -f
    else
        journalctl -u "${service_name}.service" -n "$lines" --no-pager
    fi
    
    echo
    log_info "Docker 容器日志:"
    # 从服务文件中获取容器名称
    local container_name=$(get_container_name "$service_name")
    
    if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        if [[ "$follow" == "true" ]]; then
            docker logs "$container_name" -f
        else
            docker logs "$container_name" --tail "$lines"
        fi
    else
        log_warning "容器未运行，无法查看容器日志"
    fi
}

# 删除服务
remove_service() {
    local service_name="$1"
    local force="$2"
    
    if [[ -f "/etc/systemd/system/${service_name}.service" ]]; then
        if [[ "$force" != "true" ]]; then
            log_warning "即将删除服务: $service_name"
            read -p "确认删除? (y/N): " -n 1 -r
            echo
            
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "取消删除"
                return
            fi
        fi
        
        log_info "停止服务..."
        systemctl stop "${service_name}.service" 2>/dev/null || true
        
        log_info "禁用服务..."
        systemctl disable "${service_name}.service" 2>/dev/null || true
        
        log_info "删除服务文件..."
        rm -f "/etc/systemd/system/${service_name}.service"
        
        log_info "重新加载 systemd 配置..."
        systemctl daemon-reload
        
        log_info "删除容器..."
        docker rm -f "$service_name" 2>/dev/null || true
        
        log_success "服务删除成功"
    else
        log_warning "服务 $service_name 不存在"
    fi
}

# 显示服务详细信息
show_service_info() {
    local service_name="$1"
    check_service_exists "$service_name"
    
    log_header "服务详细信息: $service_name"
    echo
    
    # 服务文件内容
    log_info "服务配置文件:"
    cat "/etc/systemd/system/${service_name}.service"
    echo
    
    # 容器详细信息
    # 从服务文件中获取容器名称
    local container_name=$(get_container_name "$service_name")
    
    if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        log_info "容器详细信息:"
        docker inspect "$container_name" | jq '.[0] | {Name: .Name, Image: .Config.Image, State: .State.Status, Created: .Created, Ports: .NetworkSettings.Ports, Env: .Config.Env, Volumes: .Mounts}' 2>/dev/null || docker inspect "$container_name"
    fi
}

# 备份服务配置
backup_service() {
    local service_name="$1"
    check_service_exists "$service_name"
    
    local backup_file="/tmp/${service_name}_service_backup_$(date +%Y%m%d_%H%M%S).service"
    
    log_info "备份服务配置到: $backup_file"
    cp "/etc/systemd/system/${service_name}.service" "$backup_file"
    log_success "备份完成"
}

# 恢复服务配置
restore_service() {
    local service_name="$1"
    local backup_file="$2"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "备份文件不存在: $backup_file"
        exit 1
    fi
    
    log_info "从备份文件恢复服务配置: $backup_file"
    cp "$backup_file" "/etc/systemd/system/${service_name}.service"
    systemctl daemon-reload
    log_success "恢复完成"
}

# 监控所有服务
monitor_services() {
    log_header "服务监控"
    echo
    
    while true; do
        clear
        log_header "Docker 服务监控 - $(date)"
        echo
        
        # 查找所有包含 docker 命令的服务文件
        local services=""
        for service_file in /etc/systemd/system/*.service; do
            if [[ -f "$service_file" ]] && grep -q "docker" "$service_file"; then
                local service_name=$(basename "$service_file" .service)
                services="$services $service_name"
            fi
        done
        
        if [[ -n "$services" ]]; then
            printf "%-20s %-15s %-15s %-10s\n" "服务名称" "Systemd状态" "容器状态" "CPU%"
            echo "--------------------------------------------------------------------------------"
            
            for service in $services; do
                local service_status=$(systemctl is-active "${service}.service" 2>/dev/null | tr -d '\n' || echo "inactive")
                local container_status="未运行"
                local cpu_usage="N/A"
                
                # 从服务文件中获取容器名称
                local container_name=$(get_container_name "$service")
                
                if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
                    container_status="运行中"
                    # 获取特定容器的CPU使用率
                    cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" "$container_name" 2>/dev/null | tail -1 | tr -d '\n')
                    if [[ -z "$cpu_usage" ]]; then
                        cpu_usage="N/A"
                    fi
                fi
                
                printf "%-20s %-15s %-15s %-10s\n" "$service" "$service_status" "$container_status" "$cpu_usage"
            done
        else
            log_warning "未找到 Docker 服务"
        fi
        
        echo
        echo "按 Ctrl+C 退出监控"
        sleep 5
    done
}

# 创建服务文件
create_service_file() {
    local service_name="$1"
    local image="$2"
    local port_mapping="$3"
    local description="$4"
    local env_vars="$5"
    local volumes="$6"
    local networks="$7"
    local memory="$8"
    local cpu="$9"
    local gpus="${10}"
    local service_file="/etc/systemd/system/${service_name}.service"
    
    log_info "创建服务文件: $service_file"
    
    # 构建 docker run 命令
    local docker_cmd="/usr/bin/docker run --log-driver=journald --name ${service_name}"
    
    # 添加端口映射
    if [[ -n "$port_mapping" ]]; then
        docker_cmd="$docker_cmd -p $port_mapping"
    fi
    
    # 添加环境变量
    if [[ -n "$env_vars" ]]; then
        for env_var in $env_vars; do
            docker_cmd="$docker_cmd -e \"$env_var\""
        done
    fi
    
    # 添加卷映射
    if [[ -n "$volumes" ]]; then
        for volume in $volumes; do
            docker_cmd="$docker_cmd -v \"$volume\""
        done
    fi
    
    # 添加网络
    if [[ -n "$networks" ]]; then
        docker_cmd="$docker_cmd --network $networks"
    fi
    
    # 添加内存限制
    if [[ -n "$memory" ]]; then
        docker_cmd="$docker_cmd --memory $memory"
    fi
    
    # 添加CPU限制
    if [[ -n "$cpu" ]]; then
        docker_cmd="$docker_cmd --cpus $cpu"
    fi
    
    # 添加GPU支持
    if [[ -n "$gpus" ]]; then
        docker_cmd="$docker_cmd --gpus $gpus"
    fi
    
    # 添加镜像
    docker_cmd="$docker_cmd $image"
    
    # 创建服务文件
    cat > "$service_file" << EOF
[Unit]
Description=${description}
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStartPre=/usr/bin/docker rm -f ${service_name}
ExecStart=${docker_cmd}
ExecStop=/usr/bin/docker stop ${service_name}
ExecStopPost=/usr/bin/docker rm -f ${service_name}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    if [[ $? -eq 0 ]]; then
        log_success "服务文件创建成功"
    else
        log_error "服务文件创建失败"
        exit 1
    fi
}

# 添加新服务
add_service() {
    local service_name="$1"
    local image="$2"
    local port_mapping="$3"
    local description="$4"
    local env_vars="$5"
    local volumes="$6"
    local networks="$7"
    local memory="$8"
    local cpu="$9"
    local gpus="${10}"
    local force="${11}"
    
    # 检查参数
    if [[ -z "$service_name" || -z "$image" ]]; then
        log_error "用法: $0 <服务名称> <镜像> [选项]"
        exit 1
    fi
    
    # 检查服务是否已存在
    if [[ -f "/etc/systemd/system/${service_name}.service" ]]; then
        if [[ "$force" == "true" ]]; then
            log_warning "服务 $service_name 已存在，将覆盖"
            remove_service "$service_name" "true"
        else
            log_error "服务 $service_name 已存在，使用 -f 参数强制覆盖"
            exit 1
        fi
    fi
    
    # 检查端口映射格式（如果提供）
    if [[ -n "$port_mapping" && ! "$port_mapping" =~ ^[0-9]+:[0-9]+$ ]]; then
        log_error "端口映射格式错误，应为 '主机端口:容器端口'"
        exit 1
    fi
    
    # 检查主机端口是否被占用（如果提供端口映射）
    if [[ -n "$port_mapping" ]]; then
        local host_port="${port_mapping%:*}"
        if netstat -tuln | grep -q ":$host_port "; then
            log_warning "主机端口 $host_port 已被占用"
            read -p "是否继续? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
    
    # 创建服务文件
    create_service_file "$service_name" "$image" "$port_mapping" "$description" "$env_vars" "$volumes" "$networks" "$memory" "$cpu" "$gpus"
    
    # 重新加载 systemd 配置
    log_info "重新加载 systemd 配置..."
    systemctl daemon-reload
    
    # 启用服务开机自启动
    log_info "启用服务开机自启动..."
    systemctl enable "${service_name}.service"
    
    # 启动服务
    log_info "启动服务..."
    if systemctl start "${service_name}.service"; then
        log_success "服务创建并启动成功"
        sleep 2
        show_service_status "$service_name"
    else
        log_error "服务启动失败"
        systemctl status "${service_name}.service" --no-pager
        exit 1
    fi
}

# 清理已停止的容器
cleanup_containers() {
    log_info "清理已停止的容器..."
    
    local stopped_containers=$(docker ps -a --filter "status=exited" --format "{{.Names}}")
    
    if [[ -n "$stopped_containers" ]]; then
        log_info "找到以下已停止的容器:"
        echo "$stopped_containers"
        echo
        
        read -p "确认删除这些容器? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker container prune -f
            log_success "清理完成"
        else
            log_info "取消清理"
        fi
    else
        log_info "没有找到已停止的容器"
    fi
}

# 主函数
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi
    
    local command="$1"
    shift
    
    # 检查是否是简化的语法（直接提供服务名称和镜像）
    if [[ "$command" != "add" && "$command" != "list" && "$command" != "status" && "$command" != "start" && "$command" != "stop" && "$command" != "restart" && "$command" != "logs" && "$command" != "remove" && "$command" != "info" && "$command" != "backup" && "$command" != "restore" && "$command" != "monitor" && "$command" != "cleanup" && "$command" != "-h" && "$command" != "--help" ]]; then
        # 这是简化的语法，自动转换为 add 命令
        local service_name="$command"
        local image="$1"
        local port_mapping=""
        local description="Docker Container $service_name"
        local env_vars=""
        local volumes=""
        local networks=""
        local memory=""
        local cpu=""
        local gpus=""
        local force="false"
        shift
        
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -p|--port)
                    if [[ $# -lt 2 ]]; then
                        log_error "请为 -p 参数指定端口映射"
                        exit 1
                    fi
                    port_mapping="$2"
                    shift 2
                    ;;
                -e|--env)
                    if [[ $# -lt 2 ]]; then
                        log_error "请为 -e 参数指定环境变量"
                        exit 1
                    fi
                    if [[ -n "$env_vars" ]]; then
                        env_vars="$env_vars $2"
                    else
                        env_vars="$2"
                    fi
                    shift 2
                    ;;
                -v|--volume)
                    if [[ $# -lt 2 ]]; then
                        log_error "请为 -v 参数指定卷映射"
                        exit 1
                    fi
                    if [[ -n "$volumes" ]]; then
                        volumes="$volumes $2"
                    else
                        volumes="$2"
                    fi
                    shift 2
                    ;;
                -n|--network)
                    if [[ $# -lt 2 ]]; then
                        log_error "请为 -n 参数指定网络"
                        exit 1
                    fi
                    networks="$2"
                    shift 2
                    ;;
                -m|--memory)
                    if [[ $# -lt 2 ]]; then
                        log_error "请为 -m 参数指定内存限制"
                        exit 1
                    fi
                    memory="$2"
                    shift 2
                    ;;
                -c|--cpu)
                    if [[ $# -lt 2 ]]; then
                        log_error "请为 -c 参数指定CPU限制"
                        exit 1
                    fi
                    cpu="$2"
                    shift 2
                    ;;
                -d|--description)
                    if [[ $# -lt 2 ]]; then
                        log_error "请为 -d 参数指定描述"
                        exit 1
                    fi
                    description="$2"
                    shift 2
                    ;;
                -g|--gpus)
                    if [[ $# -lt 2 ]]; then
                        log_error "请为 -g 参数指定GPU配置"
                        exit 1
                    fi
                    gpus="$2"
                    shift 2
                    ;;
                -f|--force)
                    force="true"
                    shift
                    ;;
                *)
                    log_error "未知参数: $1"
                    exit 1
                    ;;
            esac
        done
        
        # 调用 add_service 函数
        add_service "$service_name" "$image" "$port_mapping" "$description" "$env_vars" "$volumes" "$networks" "$memory" "$cpu" "$gpus" "$force"
        return
    fi
    
    case "$command" in
        add)
            if [[ $# -lt 3 ]]; then
                log_error "用法: $0 add <服务名称> -f <镜像> -p <端口映射> [-d <描述>]"
                exit 1
            fi
            local service_name="$1"
            local image=""
            local port_mapping=""
            local description="Docker Service"
            local env_vars=""
            local volumes=""
            local networks=""
            local memory=""
            local cpu=""
            local gpus=""
            local force="false"
            shift
            
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -f|--image)
                        if [[ $# -lt 2 ]]; then
                            log_error "请为 -f 参数指定镜像"
                            exit 1
                        fi
                        image="$2"
                        shift 2
                        ;;
                    -p|--port)
                        if [[ $# -lt 2 ]]; then
                            log_error "请为 -p 参数指定端口映射"
                            exit 1
                        fi
                        port_mapping="$2"
                        shift 2
                        ;;
                    -e|--env)
                        if [[ $# -lt 2 ]]; then
                            log_error "请为 -e 参数指定环境变量"
                            exit 1
                        fi
                        if [[ -n "$env_vars" ]]; then
                            env_vars="$env_vars $2"
                        else
                            env_vars="$2"
                        fi
                        shift 2
                        ;;
                    -v|--volume)
                        if [[ $# -lt 2 ]]; then
                            log_error "请为 -v 参数指定卷映射"
                            exit 1
                        fi
                        if [[ -n "$volumes" ]]; then
                            volumes="$volumes $2"
                        else
                            volumes="$2"
                        fi
                        shift 2
                        ;;
                    -n|--network)
                        if [[ $# -lt 2 ]]; then
                            log_error "请为 -n 参数指定网络"
                            exit 1
                        fi
                        networks="$2"
                        shift 2
                        ;;
                    -m|--memory)
                        if [[ $# -lt 2 ]]; then
                            log_error "请为 -m 参数指定内存限制"
                            exit 1
                        fi
                        memory="$2"
                        shift 2
                        ;;
                    -c|--cpu)
                        if [[ $# -lt 2 ]]; then
                            log_error "请为 -c 参数指定CPU限制"
                            exit 1
                        fi
                        cpu="$2"
                        shift 2
                        ;;
                    -g|--gpus)
                        if [[ $# -lt 2 ]]; then
                            log_error "请为 -g 参数指定GPU配置"
                            exit 1
                        fi
                        gpus="$2"
                        shift 2
                        ;;
                    -d|--description)
                        if [[ $# -lt 2 ]]; then
                            log_error "请为 -d 参数指定描述"
                            exit 1
                        fi
                        description="$2"
                        shift 2
                        ;;
                    --force)
                        force="true"
                        shift
                        ;;
                    *)
                        log_error "未知参数: $1"
                        exit 1
                        ;;
                esac
            done
            add_service "$service_name" "$image" "$port_mapping" "$description" "$env_vars" "$volumes" "$networks" "$memory" "$cpu" "$gpus" "$force"
            ;;
        list)
            list_services
            ;;
        status)
            if [[ $# -eq 0 ]]; then
                log_error "请指定服务名称"
                exit 1
            fi
            show_service_status "$1"
            ;;
        start)
            if [[ $# -eq 0 ]]; then
                log_error "请指定服务名称"
                exit 1
            fi
            start_service "$1"
            ;;
        stop)
            if [[ $# -eq 0 ]]; then
                log_error "请指定服务名称"
                exit 1
            fi
            stop_service "$1"
            ;;
        restart)
            if [[ $# -eq 0 ]]; then
                log_error "请指定服务名称"
                exit 1
            fi
            restart_service "$1"
            ;;
        logs)
            if [[ $# -eq 0 ]]; then
                log_error "请指定服务名称"
                exit 1
            fi
            local service_name="$1"
            local follow="false"
            local lines="50"
            shift
            
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -f|--follow)
                        follow="true"
                        shift
                        ;;
                    -n|--lines)
                        if [[ $# -lt 2 ]]; then
                            log_error "请为 -n 参数指定行数"
                            exit 1
                        fi
                        lines="$2"
                        shift 2
                        ;;
                    *)
                        log_error "未知参数: $1"
                        exit 1
                        ;;
                esac
            done
            show_service_logs "$service_name" "$follow" "$lines"
            ;;
        remove)
            if [[ $# -eq 0 ]]; then
                log_error "请指定服务名称"
                exit 1
            fi
            remove_service "$1"
            ;;
        info)
            if [[ $# -eq 0 ]]; then
                log_error "请指定服务名称"
                exit 1
            fi
            show_service_info "$1"
            ;;
        backup)
            if [[ $# -eq 0 ]]; then
                log_error "请指定服务名称"
                exit 1
            fi
            backup_service "$1"
            ;;
        restore)
            if [[ $# -lt 2 ]]; then
                log_error "请指定服务名称和备份文件"
                exit 1
            fi
            restore_service "$1" "$2"
            ;;
        monitor)
            monitor_services
            ;;
        cleanup)
            cleanup_containers
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
