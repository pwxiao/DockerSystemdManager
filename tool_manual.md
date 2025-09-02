# Docker Systemd Manager 新手快速指南

## 📖 快速导航

1. [工具简介](#工具简介)
2. [环境准备](#环境准备)
3. [镜像构建](#镜像构建)
4. [工具安装](#工具安装)
5. [快速上手](#快速上手)
6. [常见问题](#常见问题)

---

## 🚀 工具简介

**DockerSystemdManager** 让您的 Docker 容器随系统自启动，轻松管理容器服务。

**核心功能：**
- 🔄 容器自启动
- 📊 服务生命周期管理  
- 📝 日志查看
- 🛡️ 自动故障重启

---

## ⚙️ 环境准备

### 系统要求
- **系统**: Linux (Ubuntu 16.04+/CentOS 7+)
- **Docker**: 1.13+
- **权限**: sudo 权限

### 快速检查
```bash
# 检查 Docker
docker --version

# 检查权限
sudo whoami
```

### 安装 Docker（Ubuntu）
```bash
# 快速安装
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 启动服务
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
sudo docker run hello-world
```

---

## 🏗️ 镜像构建

### 方法1：拉取现有镜像
```bash
# 常用镜像
docker pull nginx:latest
docker pull node:18-alpine
docker pull mysql:8.0
```

### 方法2：自构建镜像-构建  ComfyUI 应用

**1. 创建项目目录**
```bash
mkdir comfyui-docker && cd comfyui-docker
```

**2. 创建 Dockerfile**
```bash
# 使用Python 3.12官方镜像作为基础镜像
FROM python:3.12-slim

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV HF_HUB_DISABLE_TELEMETRY=1
ENV DO_NOT_TRACK=1

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    build-essential \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libgoogle-perftools4 \
    libtcmalloc-minimal4 \
    && rm -rf /var/lib/apt/lists/*

# 复制requirements.txt并安装Python依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 先复制模型文件（放在前面可以利用Docker缓存）
COPY models/ models/

# 复制项目文件
COPY . .

# 创建必要的目录
RUN mkdir -p models/checkpoints \
    models/vae \
    models/loras \
    models/embeddings \
    models/clip_vision \
    models/controlnet \
    models/upscale_models \
    output \
    input \
    temp \
    user

# 设置权限
RUN chmod +x main.py

# 暴露端口（ComfyUI默认使用8188端口）
EXPOSE 8188

# 运行命令
CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
EOF
```


**3. 构建镜像**
```bash
docker build -t comfyui:latest .
```

**5. 测试运行**
```bash
das comfyui comfyui:latest -p 8188:8188 --gpus all -m "6g" -d "ComfyUI AI图像生成服务(模型已内置)" 
```

---

## 📦 工具安装

### 快速安装
```bash
# 下载项目
git clone <repository-url>
cd DockerSystemdManager

# 自动安装
sudo ./install.sh
```

### 手动安装
```bash
# 复制工具
sudo cp docker-autostart-tool.sh /usr/local/bin/docker-autostart
sudo cp docker-service-manager.sh /usr/local/bin/docker-service-manager

# 设置权限
sudo chmod +x /usr/local/bin/docker-autostart
sudo chmod +x /usr/local/bin/docker-service-manager

# 创建简写（可选）
sudo ln -sf /usr/local/bin/docker-autostart /usr/local/bin/das
sudo ln -sf /usr/local/bin/docker-service-manager /usr/local/bin/dsm
```

### 验证安装
```bash
das --help
dsm --help
```

---

## 🎯 快速上手

### 基本语法
```bash
das [选项] <服务名> <镜像名>
```

### 常用选项
- `-p` 端口映射 (如: `-p 8080:80`)
- `-e` 环境变量 (如: `-e "NODE_ENV=production"`)
- `-v` 卷映射 (如: `-v "/data:/app/data"`)
- `-m` 内存限制 (如: `-m "512m"`)
- `-d` 服务描述
- `-f` 强制覆盖
### 服务管理

```bash
# 查看所有服务
dsm list

# 查看服务状态
dsm status my-app

# 查看日志
dsm logs my-app

# 重启服务
dsm restart my-app

# 停止服务
dsm stop my-app
```

---

## ❓ 常见问题

### Q1: 服务启动失败？
```bash
# 查看状态和日志
dsm status myapp
dsm logs myapp

# 检查镜像
docker images | grep myapp

# 手动测试
docker run --rm -it myapp:1.0 /bin/sh
```

### Q2: 端口被占用？
```bash
# 查看端口占用
sudo netstat -tulpn | grep :3000

# 更换端口
das myapp myapp:1.0 -p 3001:3000 -f
```

### Q3: 如何更新服务？
```bash
# 停止服务
dsm stop myapp

# 拉取新镜像
docker pull my-node-app:2.0

# 重新创建服务
das myapp my-node-app:2.0 -p 3000:3000 -f
```

### Q4: 进入容器调试
```bash
# 进入运行中的容器
docker exec -it myapp /bin/bash

# 查看容器进程
docker exec myapp ps aux
```

### Q5: ComfyUI 服务问题排查
```bash
# 检查 ComfyUI 服务状态
dsm status comfyui-service

# 查看 ComfyUI 日志
dsm logs comfyui-service

# 检查模型文件是否存在
docker exec comfyui-service ls -la /app/models/checkpoints

# 检查 GPU 支持（如果使用 GPU 版本）
docker exec comfyui-service nvidia-smi

# 重新下载模型
# 先停止服务，清空模型目录，然后重启
dsm stop comfyui-service
sudo rm -rf /data/comfyui/models/*
# 手动下载模型到 /data/comfyui/models/checkpoints/
dsm start comfyui-service
```

---

## 🎯 下一步

恭喜！您已经掌握了基本使用方法。

**进阶学习：**
- 多容器应用部署
- 服务监控和告警
- 自动化部署脚本

**获取帮助：**
- `das --help` - 查看创建工具帮助
- `dsm --help` - 查看管理工具帮助