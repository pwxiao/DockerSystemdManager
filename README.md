# Docker Systemd Manager工具使用手册（精简版）

涵盖两个工具：`docker-autostart-tool.sh`（创建）与 `docker-service-manager.sh`（管理）。

[查看实战手册](工具安装.md)

## 🛠️ 工具概述

### 工具架构

```
┌─────────────────────────────────────────────────────────────┐
│                Docker 自启动工具集                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────┐    ┌─────────────────────────────┐  │
│  │ docker-autostart    │    │ docker-service-manager      │  │
│  │ (创建工具)           │    │ (管理工具)                    │ │
│  │                     │    │                             │  │
│  │ • 创建服务文件        │    │ • 服务生命周期管理             │  │
│  │ • 配置 Docker 参数   │    │ • 日志查看                    │  │
│  │ • 启动服务           │    │ • 状态监控                    │  │
│  │ • 参数验证          │    │ • 配置备份恢复               │  │
│  └─────────────────────┘    └─────────────────────────────┘  │
│             │                           │                   │
│             └───────────┬───────────────┘                   │
│                         │                                   │
├─────────────────────────┼─────────────────────────────────────┤
│           Systemd Service Files                              │
│  /etc/systemd/system/*.service                               │
└─────────────────────────────────────────────────────────────┘
```


### 工具 安装

#### 快速安装

```bash
# 下载工具集
git clone <repository-url>
cd docker-autostart-tools

# 运行安装脚本
sudo ./install.sh
```

#### 手动安装

```bash
# 复制工具脚本到系统路径
sudo cp docker-autostart-tool.sh /usr/local/bin/docker-autostart
sudo cp docker-service-manager.sh /usr/local/bin/docker-service-manager

# 设置执行权限
sudo chmod +x /usr/local/bin/docker-autostart
sudo chmod +x /usr/local/bin/docker-service-manager

# 创建简写命令
sudo ln -sf /usr/local/bin/docker-autostart /usr/local/bin/das
sudo ln -sf /usr/local/bin/docker-service-manager /usr/local/bin/dsm
```
## docker-autostart（创建）

### 基本语法

```bash
docker-autostart [选项] <服务名称> <镜像名称>
# 或使用简写
das [选项] <服务名称> <镜像名称>
```

常用选项：`-p` 端口、`-e` 环境、`-v` 卷、`-n` 网络、`-m` 内存、`-c` CPU、`-d` 描述、`-f` 覆盖。

#### 高级选项详解

**1. 端口映射 (`-p`)**
```bash
# 单端口映射
das myapp nginx:latest -p 8080:80

# 多端口映射（多次使用 -p）
das myapp myapp:latest -p 8080:80 -p 8443:443

# 指定协议
das myapp myapp:latest -p 8080:80/tcp -p 9000:9000/udp

# 绑定特定IP
das myapp myapp:latest -p 127.0.0.1:8080:80
```

**2. 环境变量 (`-e`)**
```bash
# 单个环境变量
das myapp myapp:latest -e "NODE_ENV=production"

# 多个环境变量
das myapp myapp:latest \
    -e "NODE_ENV=production" \
    -e "DATABASE_URL=postgresql://localhost/myapp" \
    -e "PORT=3000"

# 包含空格的值
das myapp myapp:latest -e "APP_NAME=My Application"
```

**3. 卷映射 (`-v`)**
```bash
# 目录映射
das myapp nginx:latest -v "/var/www/html:/usr/share/nginx/html"

# 只读映射
das myapp nginx:latest -v "/etc/config:/app/config:ro"

# 命名卷
das myapp mysql:8.0 -v "mysql-data:/var/lib/mysql"

# 多个卷映射
das myapp myapp:latest \
    -v "/app/data:/data" \
    -v "/app/logs:/var/log" \
    -v "/app/config:/etc/myapp:ro"
```

**4. 资源限制**
```bash
# 内存限制
das myapp myapp:latest -m "512m"    # 512MB
das myapp myapp:latest -m "1g"      # 1GB
das myapp myapp:latest -m "2048m"   # 2048MB

# CPU限制
das myapp myapp:latest -c "0.5"     # 0.5个CPU核心
das myapp myapp:latest -c "2.0"     # 2个CPU核心

# 组合使用
das myapp myapp:latest -m "1g" -c "1.0"
```

流程：参数校验 → 生成 Systemd 服务 → 部署并启动。

### 生成的服务文件

```ini
[Unit]
Description=<服务描述>
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStartPre=-/usr/bin/docker rm -f <服务名称>
ExecStart=/usr/bin/docker run --log-driver=journald --name <服务名称> [选项] <镜像名称>
ExecStop=/usr/bin/docker stop <服务名称>
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 示例

#### 等价转换：docker run → das

```bash
# Docker 命令（后台运行 + 使用全部 GPU + 指定容器名）
docker run -d --gpus all --name my-custom-container my-custom-image:v1

# 等价的 das 命令（由 systemd 托管与守护）
das my-custom-container my-custom-image:v1 --gpus all -d "My custom image service"
```

#### 基础 Web 服务

```bash
# 创建简单的 Nginx 服务
das webserver nginx:latest -p 8080:80 -d "Web Server"

# 创建带自定义配置的 Nginx
das nginx-custom nginx:latest \
    -p 80:80 \
    -p 443:443 \
    -v "/etc/nginx/sites:/etc/nginx/conf.d:ro" \
    -v "/var/log/nginx:/var/log/nginx" \
    -d "Custom Nginx Server"
```

#### 数据库服务

```bash
# MySQL 数据库
das mysql mysql:8.0 \
    -p 3306:3306 \
    -e "MYSQL_ROOT_PASSWORD=mypassword" \
    -e "MYSQL_DATABASE=myapp" \
    -e "MYSQL_USER=appuser" \
    -e "MYSQL_PASSWORD=apppass" \
    -v "mysql-data:/var/lib/mysql" \
    -m "1g" \
    -d "MySQL Database Server"

# Redis 缓存
das redis redis:7-alpine \
    -p 6379:6379 \
    -v "redis-data:/data" \
    -m "256m" \
    -d "Redis Cache Server"

# PostgreSQL 数据库
das postgres postgres:14 \
    -p 5432:5432 \
    -e "POSTGRES_DB=myapp" \
    -e "POSTGRES_USER=appuser" \
    -e "POSTGRES_PASSWORD=apppass" \
    -v "postgres-data:/var/lib/postgresql/data" \
    -m "1g" \
    -d "PostgreSQL Database"
```

## docker-service-manager（管理）

### 基本语法

```bash
docker-service-manager <命令> [选项]
# 或使用简写
dsm <命令> [选项]
```

常用命令：`list`、`status`、`start`、`stop`、`restart`、`logs`、`remove`。高级：`info`、`backup`、`restore`、`monitor`、`cleanup`。

#### 快捷创建命令

```bash
# 简化语法创建服务
dsm <服务名> <镜像> [选项]

# 等同于
dsm add <服务名> -f <镜像> [选项]
```

### 常见用法

#### 1. 服务列表 (`list`)

```bash
dsm list
```

输出格式：
```
服务名称              状态           容器状态         端口映射
--------------------------------------------------------------------------------
nginx-web            active         运行中           0.0.0.0:8080->80/tcp
mysql-db             active         运行中           0.0.0.0:3306->3306/tcp
redis-cache          inactive       已停止           无
```

#### 2. 服务状态 (`status`)

```bash
dsm status myapp
```

显示内容：
- Systemd 服务状态详情
- Docker 容器运行状态
- 端口映射信息
- 资源使用情况

#### 3. 日志查看 (`logs`)

```bash
# 查看最近 50 行日志
dsm logs myapp

# 查看最近 100 行日志
dsm logs myapp -n 100

# 实时跟踪日志
dsm logs myapp -f

# 实时跟踪最近 200 行
dsm logs myapp -f -n 200
```

**日志选项**：

| 选项 | 长选项 | 参数 | 描述 |
|------|--------|------|------|
| `-f` | `--follow` | 无 | 实时跟踪日志 |
| `-n` | `--lines` | `<行数>` | 显示行数（默认50） |

#### 4. 服务信息 (`info`)

```bash
dsm info myapp
```

显示内容：
- 完整的服务配置文件
- Docker 容器详细信息（JSON格式）
- 网络配置
- 卷映射信息
- 环境变量

#### 5. 配置管理

**备份配置**：
```bash
dsm backup myapp
# 创建文件：/tmp/myapp_service_backup_20250827_143022.service
```

**恢复配置**：
```bash
dsm restore myapp /tmp/myapp_service_backup_20250827_143022.service
```

#### 6. 实时监控 (`monitor`)

```bash
dsm monitor
```

监控界面显示：
```
Docker 服务监控 - Mon Aug 27 14:30:22 2025

服务名称              Systemd状态     容器状态         CPU%
--------------------------------------------------------------------------------
nginx-web            active         运行中           2.34%
mysql-db             active         运行中           5.67%
redis-cache          active         运行中           1.23%

按 Ctrl+C 退出监控
```

更新频率：每5秒自动刷新

#### 7. 容器清理 (`cleanup`)

```bash
dsm cleanup
```

功能：
- 查找所有已停止的容器
- 显示容器列表供确认
- 安全删除已停止的容器

### 高级功能

#### 1. 智能容器名称解析

工具会自动从服务文件中提取容器名称：

```bash
# 服务文件中的容器名称可能与服务名称不同
ExecStart=/usr/bin/docker run --name custom-container-name nginx:latest

# dsm 会自动识别并使用正确的容器名称
dsm status myservice  # 自动操作 custom-container-name 容器
```

#### 2. 多格式支持

**创建服务的两种方式**：

```bash
# 方式1：标准语法
dsm add myapp -f nginx:latest -p 8080:80 -d "Web Server"

# 方式2：简化语法
dsm myapp nginx:latest -p 8080:80 -d "Web Server"
```

#### 3. 错误处理和验证

- **端口冲突检测**：创建服务前检查端口是否被占用
- **参数验证**：验证端口映射格式、镜像名称等
- **权限检查**：确保有足够权限操作 systemd 和 Docker
- **依赖检查**：验证 Docker 服务是否运行

## 示例

### 完整部署流程

#### 1. 部署 Web 应用栈

```bash
# 1. 创建数据库服务
das mysql mysql:8.0 \
    -p 3306:3306 \
    -e "MYSQL_ROOT_PASSWORD=rootpass" \
    -e "MYSQL_DATABASE=webapp" \
    -e "MYSQL_USER=webuser" \
    -e "MYSQL_PASSWORD=webpass" \
    -v "mysql-data:/var/lib/mysql" \
    -m "1g" \
    -d "MySQL Database for Web App"

# 2. 创建缓存服务
das redis redis:7-alpine \
    -p 6379:6379 \
    -v "redis-data:/data" \
    -m "256m" \
    -d "Redis Cache for Web App"

# 3. 创建 Web 应用
das webapp mywebapp:latest \
    -p 8080:3000 \
    -e "NODE_ENV=production" \
    -e "DATABASE_URL=mysql://webuser:webpass@localhost:3306/webapp" \
    -e "REDIS_URL=redis://localhost:6379" \
    -v "/app/uploads:/var/www/uploads" \
    -v "/app/logs:/var/log/webapp" \
    -m "512m" \
    -c "1.0" \
    -d "Main Web Application"

# 4. 创建负载均衡器
das nginx nginx:latest \
    -p 80:80 \
    -p 443:443 \
    -v "/etc/nginx/conf.d:/etc/nginx/conf.d:ro" \
    -v "/var/log/nginx:/var/log/nginx" \
    -d "Nginx Load Balancer"
```

#### 2. 服务管理操作

```bash
# 查看所有服务状态
dsm list

# 检查特定服务
dsm status webapp
dsm status mysql

# 查看应用日志
dsm logs webapp -f

# 重启有问题的服务
dsm restart webapp

# 监控所有服务
dsm monitor
```

#### 3. 维护和备份

```bash
# 备份关键服务配置
dsm backup mysql
dsm backup webapp
dsm backup nginx

# 更新应用
dsm stop webapp
docker pull mywebapp:latest
dsm start webapp

# 清理停止的容器
dsm cleanup
```

### 开发环境部署

```bash
# 开发数据库
dsm dev-db postgres:14 \
    -p 5432:5432 \
    -e "POSTGRES_DB=devapp" \
    -e "POSTGRES_USER=dev" \
    -e "POSTGRES_PASSWORD=devpass" \
    -v "dev-postgres:/var/lib/postgresql/data" \
    -d "Development Database"

# 开发应用
dsm dev-app node:16-alpine \
    -p 3000:3000 \
    -e "NODE_ENV=development" \
    -e "DATABASE_URL=postgresql://dev:devpass@localhost:5432/devapp" \
    -v "/home/dev/myapp:/usr/src/app" \
    -v "/home/dev/node_modules:/usr/src/app/node_modules" \
    -d "Development Application"

# 开发代理
dsm dev-proxy nginx:alpine \
    -p 8080:80 \
    -v "/home/dev/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -d "Development Proxy"
```

## 最佳实践（要点）

### 1. 服务命名规范

```bash
# 推荐的命名规范
<环境>-<应用类型>-<实例名>

# 示例
prod-web-frontend    # 生产环境 Web 前端
prod-db-mysql        # 生产环境 MySQL 数据库
dev-api-backend      # 开发环境 API 后端
test-cache-redis     # 测试环境 Redis 缓存
```

### 2. 资源配置策略

```bash
# 小型应用
-m "256m" -c "0.5"

# 中型应用
-m "512m" -c "1.0"

# 大型应用
-m "1g" -c "2.0"

# 数据库服务
-m "2g" -c "2.0"
```

### 3. 网络配置

```bash
# 创建自定义网络
docker network create myapp-network

# 所有相关服务使用同一网络
das db mysql:8.0 -n myapp-network ...
das app myapp:latest -n myapp-network ...
das proxy nginx:latest -n myapp-network ...
```

### 4. 数据持久化

```bash
# 使用命名卷（推荐）
das db mysql:8.0 -v "mysql-data:/var/lib/mysql"

# 使用绑定挂载（开发环境）
das app node:16 -v "/home/user/app:/usr/src/app"

# 配置文件只读挂载
das proxy nginx:latest -v "/etc/nginx/sites:/etc/nginx/conf.d:ro"
```

### 5. 环境变量管理

```bash
# 创建环境变量文件
cat > /etc/myapp/prod.env << EOF
NODE_ENV=production
DATABASE_URL=postgresql://user:pass@localhost:5432/db
REDIS_URL=redis://localhost:6379
LOG_LEVEL=info
EOF

# 在容器中使用
das app myapp:latest --env-file /etc/myapp/prod.env
```

### 6. 日志管理策略

```bash
# 定期查看关键服务日志
dsm logs webapp -n 100 | grep ERROR
dsm logs db -n 50 | grep WARN

# 设置日志轮转（在宿主机上配置）
# /etc/logrotate.d/docker-services
/var/lib/docker/containers/*/*.log {
    daily
    rotate 7
    compress
    delaycompress
    copytruncate
}
```

## 故障排除（速查）

### 常见问题和解决方案

#### 1. 服务创建失败

**问题**：`docker-autostart` 报错服务已存在

```bash
# 解决方案1：使用强制覆盖
das myapp nginx:latest -p 8080:80 -f

# 解决方案2：先删除再创建
dsm remove myapp
das myapp nginx:latest -p 8080:80
```

#### 2. 容器启动失败

**问题**：服务显示 `failed`，容器无法启动

```bash
# 诊断步骤
dsm status myapp               # 查看详细状态
journalctl -u myapp.service    # 查看系统日志
docker logs myapp              # 查看容器日志

# 常见原因
1. 端口被占用：netstat -tulpn | grep :8080
2. 镜像不存在：docker images | grep myapp
3. 卷路径不存在：ls -la /host/path
4. 权限问题：chmod 755 /host/path
```

#### 3. 端口访问问题

**问题**：容器运行但无法访问端口

```bash
# 检查防火墙（CentOS/RHEL）
firewall-cmd --list-ports
firewall-cmd --add-port=8080/tcp --permanent
firewall-cmd --reload

# 检查端口映射
docker port myapp
netstat -tulpn | grep :8080

# 检查容器内部服务
docker exec myapp curl localhost:80
```

#### 4. 性能问题

**问题**：容器运行缓慢或频繁重启

```bash
# 检查资源使用
docker stats myapp
dsm monitor

# 调整资源限制
# 编辑服务文件添加更多资源
dsm backup myapp
# 手动编辑 /etc/systemd/system/myapp.service
systemctl daemon-reload
dsm restart myapp
```

#### 5. 数据丢失问题

**问题**：容器重启后数据丢失

```bash
# 检查卷映射
dsm info myapp | grep -A 10 "Mounts"

# 确保使用持久化卷
das myapp myapp:latest -v "myapp-data:/app/data"

# 检查卷是否存在
docker volume ls
docker volume inspect myapp-data
```

### 调试命令集合

```bash
# 系统级诊断
systemctl status docker
systemctl list-units --type=service --state=failed
docker system info
docker system df

# 服务级诊断
dsm list
dsm status <service>
systemctl status <service>.service
journalctl -u <service>.service --no-pager

# 容器级诊断
docker ps -a
docker logs <container>
docker inspect <container>
docker exec <container> <command>

# 网络诊断
docker network ls
docker port <container>
netstat -tulpn
ss -tulpn

# 存储诊断
docker volume ls
docker system df
df -h
```

### 恢复操作

```bash
# 服务恢复流程
1. 停止问题服务
   dsm stop myapp

2. 备份当前配置
   dsm backup myapp

3. 检查和修复配置
   vim /etc/systemd/system/myapp.service

4. 重新加载配置
   systemctl daemon-reload

5. 启动服务
   dsm start myapp

6. 验证服务状态
   dsm status myapp
```
