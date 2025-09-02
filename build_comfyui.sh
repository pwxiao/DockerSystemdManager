#!/bin/bash

# ComfyUI Docker 镜像构建脚本
# 作者: DockerSystemdManager
# 用途: 自动构建包含ComfyUI和基础模型的Docker镜像

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
ComfyUI Docker 镜像构建脚本

用法: $0 [选项]

选项:
    -n, --name <镜像名称>      指定镜像名称 (默认: comfyui)
    -t, --tag <标签>           指定镜像标签 (默认: latest)
    -g, --gpu                  构建GPU版本 (默认: CPU版本)
    -m, --models               下载基础模型
    -c, --clean                清理构建缓存
    -h, --help                 显示此帮助信息

示例:
    $0                         # 构建CPU版本
    $0 -g                      # 构建GPU版本
    $0 -n mycomfyui -t 1.0     # 指定名称和标签
    $0 -g -m                   # 构建GPU版本并下载模型

EOF
}

# 默认参数
IMAGE_NAME="comfyui"
IMAGE_TAG="latest"
GPU_SUPPORT=false
DOWNLOAD_MODELS=false
CLEAN_BUILD=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -g|--gpu)
            GPU_SUPPORT=true
            shift
            ;;
        -m|--models)
            DOWNLOAD_MODELS=true
            shift
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker 服务未运行，请启动 Docker 服务"
        exit 1
    fi
}

# 清理构建缓存
clean_build_cache() {
    if [[ "$CLEAN_BUILD" == "true" ]]; then
        log_info "清理Docker构建缓存..."
        docker builder prune -f
        log_success "构建缓存清理完成"
    fi
}

# 创建构建目录
create_build_dir() {
    BUILD_DIR="comfyui-docker-build"
    if [[ -d "$BUILD_DIR" ]]; then
        log_warning "构建目录已存在，正在清理..."
        rm -rf "$BUILD_DIR"
    fi
    
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    log_info "创建构建目录: $(pwd)"
}

# 生成Dockerfile
generate_dockerfile() {
    local dockerfile_content
    
    if [[ "$GPU_SUPPORT" == "true" ]]; then
        log_info "生成GPU版本Dockerfile..."
        dockerfile_content='# ComfyUI Docker镜像 - GPU版本
FROM nvidia/cuda:11.8-devel-ubuntu22.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    wget \
    curl \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 克隆ComfyUI源码
RUN git clone https://github.com/comfyanonymous/ComfyUI.git .

# 安装Python依赖
RUN pip3 install --no-cache-dir \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 \
    && pip3 install --no-cache-dir -r requirements.txt

# 创建模型目录
RUN mkdir -p /app/models/checkpoints \
    && mkdir -p /app/models/vae \
    && mkdir -p /app/models/loras \
    && mkdir -p /app/models/controlnet \
    && mkdir -p /app/models/embeddings \
    && mkdir -p /app/output

# 创建启动脚本
RUN echo "#!/bin/bash\n\
echo \"Starting ComfyUI with GPU support...\"\n\
cd /app\n\
python3 main.py --listen 0.0.0.0 --port 8188" > /app/start.sh && \
    chmod +x /app/start.sh

# 暴露端口
EXPOSE 8188

# 启动命令
CMD ["/app/start.sh"]'
    else
        log_info "生成CPU版本Dockerfile..."
        dockerfile_content='# ComfyUI Docker镜像 - CPU版本
FROM ubuntu:22.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    wget \
    curl \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 克隆ComfyUI源码
RUN git clone https://github.com/comfyanonymous/ComfyUI.git .

# 安装Python依赖（CPU版本）
RUN pip3 install --no-cache-dir \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu \
    && pip3 install --no-cache-dir -r requirements.txt

# 创建模型目录
RUN mkdir -p /app/models/checkpoints \
    && mkdir -p /app/models/vae \
    && mkdir -p /app/models/loras \
    && mkdir -p /app/models/controlnet \
    && mkdir -p /app/models/embeddings \
    && mkdir -p /app/output

# 创建启动脚本
RUN echo "#!/bin/bash\n\
echo \"Starting ComfyUI with CPU support...\"\n\
cd /app\n\
python3 main.py --listen 0.0.0.0 --port 8188 --cpu" > /app/start.sh && \
    chmod +x /app/start.sh

# 暴露端口
EXPOSE 8188

# 启动命令
CMD ["/app/start.sh"]'
    fi
    
    echo "$dockerfile_content" > Dockerfile
    log_success "Dockerfile生成完成"
}

# 下载基础模型
download_models() {
    if [[ "$DOWNLOAD_MODELS" == "true" ]]; then
        log_info "创建模型下载脚本..."
        
        cat > download_models.sh << 'EOF'
#!/bin/bash
# ComfyUI 基础模型下载脚本

MODELS_DIR="./models"
mkdir -p $MODELS_DIR/checkpoints
mkdir -p $MODELS_DIR/vae
mkdir -p $MODELS_DIR/loras

echo "下载 Stable Diffusion 基础模型..."

# 下载SD 1.5模型 (较小，适合测试)
echo "下载 SD 1.5 模型..."
wget -O $MODELS_DIR/checkpoints/sd-v1-5-inpainting.ckpt \
  "https://huggingface.co/runwayml/stable-diffusion-inpainting/resolve/main/sd-v1-5-inpainting.ckpt"

# 下载VAE
echo "下载 VAE 模型..."
wget -O $MODELS_DIR/vae/vae-ft-mse-840000-ema-pruned.safetensors \
  "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors"

echo "基础模型下载完成！"
echo "模型位置："
echo "- Checkpoints: $MODELS_DIR/checkpoints/"
echo "- VAE: $MODELS_DIR/vae/"
echo "- LoRAs: $MODELS_DIR/loras/"
EOF
        
        chmod +x download_models.sh
        log_success "模型下载脚本创建完成"
        
        # 提示用户
        log_info "注意: 由于模型文件较大，建议在镜像构建完成后手动下载模型"
        log_info "执行 ./download_models.sh 来下载基础模型"
    fi
}

# 构建Docker镜像
build_image() {
    local full_image_name="${IMAGE_NAME}:${IMAGE_TAG}"
    
    log_info "开始构建Docker镜像: $full_image_name"
    
    if [[ "$GPU_SUPPORT" == "true" ]]; then
        log_warning "构建GPU版本可能需要较长时间，请耐心等待..."
    else
        log_info "构建CPU版本，适合开发和测试环境"
    fi
    
    # 构建镜像
    if docker build -t "$full_image_name" .; then
        log_success "镜像构建成功: $full_image_name"
    else
        log_error "镜像构建失败"
        exit 1
    fi
}

# 测试镜像
test_image() {
    local full_image_name="${IMAGE_NAME}:${IMAGE_TAG}"
    local test_container_name="comfyui-test-$(date +%s)"
    
    log_info "测试镜像..."
    
    # 运行测试容器
    local docker_run_cmd="docker run -d --name $test_container_name -p 8188:8188"
    
    if [[ "$GPU_SUPPORT" == "true" ]]; then
        docker_run_cmd="$docker_run_cmd --gpus all"
    fi
    
    docker_run_cmd="$docker_run_cmd $full_image_name"
    
    if eval $docker_run_cmd; then
        log_success "测试容器启动成功"
        sleep 5
        
        # 检查容器状态
        if docker ps | grep -q "$test_container_name"; then
            log_success "ComfyUI 服务运行正常"
            log_info "访问 http://localhost:8188 来使用 ComfyUI"
        else
            log_error "容器启动失败"
            docker logs "$test_container_name"
        fi
        
        # 清理测试容器
        log_info "清理测试容器..."
        docker stop "$test_container_name" &> /dev/null
        docker rm "$test_container_name" &> /dev/null
    else
        log_error "测试容器启动失败"
        exit 1
    fi
}

# 显示使用说明
show_usage() {
    local full_image_name="${IMAGE_NAME}:${IMAGE_TAG}"
    
    echo
    log_success "ComfyUI Docker镜像构建完成！"
    echo
    echo "镜像信息:"
    echo "  名称: $full_image_name"
    echo "  类型: $([ "$GPU_SUPPORT" = true ] && echo "GPU版本" || echo "CPU版本")"
    echo
    echo "使用方法:"
    echo
    echo "1. 手动运行容器:"
    
    if [[ "$GPU_SUPPORT" == "true" ]]; then
        echo "   docker run -d --name comfyui --gpus all -p 8188:8188 \\"
        echo "     -v /data/comfyui/models:/app/models \\"
        echo "     -v /data/comfyui/output:/app/output \\"
        echo "     $full_image_name"
    else
        echo "   docker run -d --name comfyui -p 8188:8188 \\"
        echo "     -v /data/comfyui/models:/app/models \\"
        echo "     -v /data/comfyui/output:/app/output \\"
        echo "     $full_image_name"
    fi
    
    echo
    echo "2. 使用 DockerSystemdManager 创建自启动服务:"
    
    if [[ "$GPU_SUPPORT" == "true" ]]; then
        echo "   das comfyui-service $full_image_name \\"
        echo "     -p 8188:8188 \\"
        echo "     -v \"/data/comfyui/models:/app/models\" \\"
        echo "     -v \"/data/comfyui/output:/app/output\" \\"
        echo "     -e \"NVIDIA_VISIBLE_DEVICES=all\" \\"
        echo "     -m \"6g\" \\"
        echo "     --runtime=nvidia \\"
        echo "     -d \"ComfyUI AI图像生成服务 (GPU)\""
    else
        echo "   das comfyui-service $full_image_name \\"
        echo "     -p 8188:8188 \\"
        echo "     -v \"/data/comfyui/models:/app/models\" \\"
        echo "     -v \"/data/comfyui/output:/app/output\" \\"
        echo "     -m \"4g\" \\"
        echo "     -d \"ComfyUI AI图像生成服务\""
    fi
    
    echo
    echo "3. 访问 Web 界面:"
    echo "   http://localhost:8188"
    echo
    echo "注意事项:"
    echo "- 首次运行需要下载模型文件到 /data/comfyui/models/checkpoints/"
    echo "- 推荐使用至少4GB内存"
    if [[ "$GPU_SUPPORT" == "true" ]]; then
        echo "- GPU版本需要NVIDIA Docker支持"
        echo "- 确保已安装nvidia-docker2"
    fi
    echo
}

# 主程序
main() {
    log_info "ComfyUI Docker 镜像构建脚本启动"
    
    # 检查环境
    check_docker
    
    # 清理缓存
    clean_build_cache
    
    # 创建构建目录
    create_build_dir
    
    # 生成Dockerfile
    generate_dockerfile
    
    # 创建模型下载脚本
    download_models
    
    # 构建镜像
    build_image
    
    # 测试镜像
    test_image
    
    # 显示使用说明
    show_usage
    
    log_success "构建流程完成！"
}

# 运行主程序
main "$@"