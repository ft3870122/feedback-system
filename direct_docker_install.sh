#!/bin/bash

set -e

echo "开始直接安装 Docker..."

# 下载 Docker 安装脚本
curl -fsSL https://get.docker.com -o get-docker.sh

# 执行安装脚本
sh get-docker.sh

# 启动 Docker 服务
systemctl start docker
systemctl enable docker

echo "Docker 安装完成！"
docker --version

echo "开始安装 Docker Compose..."

# 下载 Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 添加执行权限
chmod +x /usr/local/bin/docker-compose

# 创建软链接
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

echo "Docker Compose 安装完成！"
docker-compose --version

echo "Docker 环境安装完成！"
