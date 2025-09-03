### 示例二:自构建镜像-构建 ComfyUI 应用

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