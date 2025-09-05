
### 示例一: 基于 Base 镜像构建新的镜像

目标：以 `nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04` 为 Base，安装所需依赖，并打包为 `my-custom-image:v1`。

1) 查看现有镜像
```bash
docker images

REPOSITORY    TAG                                 IMAGE ID       CREATED         SIZE
nvidia/cuda   12.1.1-cudnn8-runtime-ubuntu22.04   02f0c5f1a54b   22 months ago   3.38GB
```

2) 创建临时构建容器
创建容器
```bash
docker run -d --gpus all --name custom-build nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04 tail -f /dev/null
```
进入容器

命令
```bash
docker exec -it <容器名> bash
```
示例
```bash
docker exec -it custom-build bash
```

3) 在容器内安装所需软件（示例：StableDiffusion WebUI）
- 根据需要自行安装软件

4) 退出容器
```bash
exit
```

5) 将已配置好的容器打包为新镜像

命令
```bash
docker commit <你的容器名> <镜像名>:<标签>
```
示例
```bash
docker commit custom-build my-sd-webui:1.0
```
6) 可选：清理临时容器
命令
```bash
docker rm -f <容器名>
```
示例
```bash
docker rm -f custom-build
```


至此，新镜像已构建完成。

# 使用das命令启动镜像

命令

```bash
das <服务名> <镜像名>:<标签> --gpus all -d "容器描述" 
```

示例
```bash
das my-custom-container-service my-custom-image:v1 --gpus all -d "My custom image service" 
```
# 查看状态

命令
```bash
dsm status <服务名>
```

示例
```bash
dsm status my-custom-container-service
```