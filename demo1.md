
### 示例一: 基于 Base 镜像构建新的镜像

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

命令
```bash
docker commit <你构建的镜像名> my-custom-image:v1
```
示例
```bash
docker commit my-sd-webui:1.2 my-sd-webui:1.0
```
6) 可选：清理临时容器
```bash
docker rm -f <你构建的镜像名>
```

至此，新镜像已构建完成。

# 使用das命令启动镜像
```bash
das my-custom-container my-custom-image:v1 --gpus all -d "My custom image service" 
```
# 查看状态
```bash
dsm status my-custom-container
```

下一节 [示例二:自构建镜像-构建 ComfyUI 应用.md](demo2.md)