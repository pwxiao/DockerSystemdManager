# Docker Systemd Manager 新手快速指南

## 📖 快速导航

1. [工具简介](#工具简介)
2. [环境准备](#环境准备)
3. [镜像构建](#镜像构建)
4. [工具安装](#工具安装)
5. [快速上手](#快速上手)

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
- **系统**: Linux (Ubuntu 22.04 推荐22.04)
---

## 🏗️ 镜像构建


### 示例一:自构建镜像-构建 ComfyUI 应用

**1. 创建项目目录**
```bash
mkdir comfyui-docker && cd comfyui-docker
```

**2. 创建 Dockerfile**
```bash
# 使用Python 3.12官方镜像
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


### 示例二: 基于 Base 镜像构建新的镜像

目标：以 `nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04` 为 Base，安装所需依赖（如 ComfyUI），并打包为 `my-custom-image:v1`。

1) 查看现有镜像
```bash
docker images

REPOSITORY    TAG                                 IMAGE ID       CREATED         SIZE

nvidia/cuda   12.1.1-cudnn8-runtime-ubuntu22.04   02f0c5f1a54b   22 months ago   3.38GB
```

2) 启动临时构建容器并进入
```bash
docker run -it --gpus all --name custom-build nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04 bash
```

3) 在容器内安装所需软件（示例：ComfyUI）
- 根据需要自行安装软件

4) 退出容器
```bash
exit
```

5) 将已配置好的容器打包为新镜像
```bash
docker commit custom-build my-custom-image:v1
```

6) 可选：清理临时容器
```bash
docker rm -f custom-build
```

至此，新镜像已构建完成。






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

