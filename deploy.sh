#!/bin/bash
# -*- coding: utf-8 -*-
"""
Ubuntu Docker 部署脚本
"""

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}标签闭环系统 - Ubuntu Docker 部署脚本${NC}"
echo -e "${BLUE}========================================${NC}"

# 检查是否以root用户运行
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}错误: 请以root用户运行此脚本${NC}"
   exit 1
fi

# 安装Docker（支持国内网络）
install_docker() {
    echo -e "${YELLOW}正在安装 Docker...${NC}"
    
    # 卸载旧版本
    apt-get remove -y docker docker.io containerd runc
    
    # 更新apt包索引
    apt-get update
    
    # 安装依赖
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common
    
    # 优先使用阿里云安装脚本（国内网络优化）
    echo -e "${BLUE}使用阿里云Docker安装脚本...${NC}"
    if curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun; then
        echo -e "${GREEN}Docker安装成功!${NC}"
    else
        echo -e "${YELLOW}阿里云脚本失败，尝试官方安装方式...${NC}"
        
        # 添加Docker官方GPG密钥
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        
        # 设置稳定版仓库
        add-apt-repository \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) \
            stable"
        
        # 安装Docker Engine
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
    fi
    
    # 配置阿里云Docker镜像加速
    echo -e "${BLUE}配置阿里云Docker镜像加速...${NC}"
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": [
    "https://registry.cn-hangzhou.aliyuncs.com",
    "https://registry.cn-shanghai.aliyuncs.com",
    "https://registry.cn-shenzhen.aliyuncs.com"
  ]
}
EOF
    
    # 启动Docker
    systemctl daemon-reload
    systemctl start docker
    systemctl enable docker
    
    echo -e "${GREEN}Docker 安装成功!${NC}"
    docker --version
    
    # 验证镜像加速配置
    echo -e "${BLUE}Docker镜像加速配置:${NC}"
    docker info | grep "Registry Mirrors" || echo -e "${YELLOW}镜像加速配置可能未生效${NC}"
}

# 安装Docker Compose（支持国内网络）
install_docker_compose() {
    echo -e "${YELLOW}正在安装 Docker Compose...${NC}"
    
    # 尝试从GitHub下载（备用）
    GITHUB_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)"
    
    # 优先从国内镜像下载
    echo -e "${BLUE}尝试从国内镜像下载Docker Compose...${NC}"
    if curl -L "https://mirrors.aliyun.com/docker-toolbox/linux/compose/$(curl -s https://mirrors.aliyun.com/docker-toolbox/linux/compose/LATEST)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose; then
        echo -e "${GREEN}从阿里云镜像下载成功!${NC}"
    else
        echo -e "${YELLOW}国内镜像下载失败，尝试GitHub下载...${NC}"
        if curl -L "$GITHUB_URL" -o /usr/local/bin/docker-compose; then
            echo -e "${GREEN}从GitHub下载成功!${NC}"
        else
            echo -e "${RED}Docker Compose下载失败!${NC}"
            echo -e "${YELLOW}尝试使用pip安装...${NC}"
            pip3 install docker-compose || {
                echo -e "${RED}所有安装方式都失败了!${NC}"
                exit 1
            }
        fi
    fi
    
    # 添加执行权限
    chmod +x /usr/local/bin/docker-compose
    
    # 创建软链接
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
    
    echo -e "${GREEN}Docker Compose 安装成功!${NC}"
    docker-compose --version
}

# 创建数据目录
create_data_dirs() {
    echo -e "${YELLOW}正在创建数据目录...${NC}"
    
    # 创建主数据目录
    mkdir -p /data/mysql
    mkdir -p /data/postgresql
    mkdir -p /data/logs
    
    # 设置权限
    chmod -R 777 /data
    
    echo -e "${GREEN}数据目录创建成功!${NC}"
    echo -e "${BLUE}数据目录:${NC}"
    echo -e "  - MySQL: /data/mysql"
    echo -e "  - PostgreSQL: /data/postgresql"
    echo -e "  - 日志: /data/logs"
}

# 配置环境变量
configure_env() {
    echo -e "${YELLOW}正在配置环境变量...${NC}"
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            echo -e "${GREEN}已从 .env.example 创建 .env 文件${NC}"
        else
            echo -e "${RED}错误: 未找到 .env.example 文件${NC}"
            exit 1
        fi
    fi
    
    # 生成随机密码
    MYSQL_PASSWORD=$(openssl rand -base64 12)
    PG_PASSWORD=$(openssl rand -base64 12)
    API_KEY=$(openssl rand -base64 16)
    
    # 更新环境变量文件
    sed -i "s/your_secure_mysql_password/$MYSQL_PASSWORD/g" .env
    sed -i "s/your_secure_postgres_password/$PG_PASSWORD/g" .env
    sed -i "s/your_secure_api_key_for_fastapi/$API_KEY/g" .env
    
    echo -e "${GREEN}环境变量配置成功!${NC}"
    echo -e "${YELLOW}请编辑 .env 文件配置 Coze API 信息:${NC}"
    echo -e "  COZE_API_KEY=your_coze_api_key"
    echo -e "  COZE_APP_ID=your_coze_app_id"
}

# 构建并启动服务（支持国内网络）
start_services() {
    echo -e "${YELLOW}正在构建并启动服务...${NC}"
    
    # 检查是否存在国内镜像版本的配置文件
    if [ -f "docker-compose.aliyun.yml" ]; then
        echo -e "${BLUE}检测到国内镜像版本配置文件，优先使用...${NC}"
        COMPOSE_FILE="docker-compose.aliyun.yml"
    else
        echo -e "${BLUE}使用默认配置文件...${NC}"
        COMPOSE_FILE="docker-compose.yml"
    fi
    
    # 预拉取基础镜像（国内优化）
    echo -e "${BLUE}预拉取基础Docker镜像...${NC}"
    if [ "$COMPOSE_FILE" = "docker-compose.aliyun.yml" ]; then
        # 从阿里云拉取镜像
        docker pull registry.cn-hangzhou.aliyuncs.com/library/mysql:8.0 2>/dev/null || echo -e "${YELLOW}MySQL镜像拉取失败，将在构建时拉取${NC}"
        docker pull registry.cn-hangzhou.aliyuncs.com/library/postgres:15 2>/dev/null || echo -e "${YELLOW}PostgreSQL镜像拉取失败，将在构建时拉取${NC}"
        docker pull registry.cn-hangzhou.aliyuncs.com/library/python:3.8-slim 2>/dev/null || echo -e "${YELLOW}Python镜像拉取失败，将在构建时拉取${NC}"
    else
        # 拉取默认镜像
        docker pull mysql:8.0 2>/dev/null || echo -e "${YELLOW}MySQL镜像拉取失败，将在构建时拉取${NC}"
        docker pull postgres:15 2>/dev/null || echo -e "${YELLOW}PostgreSQL镜像拉取失败，将在构建时拉取${NC}"
        docker pull python:3.8-slim 2>/dev/null || echo -e "${YELLOW}Python镜像拉取失败，将在构建时拉取${NC}"
    fi
    
    # 构建镜像
    echo -e "${BLUE}正在构建 Docker 镜像...${NC}"
    echo -e "${YELLOW}注意：首次构建可能需要较长时间，请耐心等待...${NC}"
    docker-compose -f "$COMPOSE_FILE" build
    
    # 启动服务
    echo -e "${BLUE}正在启动服务...${NC}"
    docker-compose -f "$COMPOSE_FILE" up -d
    
    echo -e "${GREEN}服务启动成功!${NC}"
    
    # 显示服务状态
    echo -e "${BLUE}服务状态:${NC}"
    docker-compose -f "$COMPOSE_FILE" ps
    
    # 保存使用的配置文件信息
    echo "$COMPOSE_FILE" > .compose_file_used
    echo -e "${YELLOW}已使用配置文件: $COMPOSE_FILE${NC}"
}

# 显示访问信息
show_access_info() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}部署完成!${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # 获取服务器IP
    SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
    
    echo -e "${BLUE}访问信息:${NC}"
    echo -e "  - API地址: http://$SERVER_IP:8001"
    echo -e "  - API健康检查: http://$SERVER_IP:8001/health"
    echo -e "  - API统计: http://$SERVER_IP:8001/stats"
    echo -e "  - MySQL端口: 3306"
    echo -e "  - PostgreSQL端口: 5432"
    
    echo -e ""
    echo -e "${YELLOW}重要提示:${NC}"
    echo -e "  1. 请确保阿里云安全组已开放相关端口"
    echo -e "  2. 请配置 Coze Agent 调用 http://$SERVER_IP:8001/insert_feedback"
    echo -e "  3. API密钥已自动生成，查看 .env 文件中的 API_KEY"
    echo -e ""
    echo -e "${BLUE}查看日志:${NC}"
    echo -e "  - docker-compose logs -f feedback-api"
    echo -e "  - docker-compose logs -f feedback-worker"
    echo -e ""
    echo -e "${BLUE}重启服务:${NC}"
    echo -e "  - docker-compose restart"
    echo -e ""
}

# 主菜单
main_menu() {
    echo -e ""
    echo -e "${BLUE}请选择操作:${NC}"
    echo -e "  1) 完整安装 (推荐)"
    echo -e "  2) 仅安装 Docker 和 Docker Compose"
    echo -e "  3) 仅配置环境和启动服务"
    echo -e "  4) 退出"
    echo -e ""
    
    read -p "请输入选择 [1-4]: " choice
    
    case $choice in
        1)
            install_docker
            install_docker_compose
            create_data_dirs
            configure_env
            start_services
            show_access_info
            ;;
        2)
            install_docker
            install_docker_compose
            ;;
        3)
            create_data_dirs
            configure_env
            start_services
            show_access_info
            ;;
        4)
            echo -e "${BLUE}退出脚本${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            main_menu
            ;;
    esac
}

# 检查Docker是否已安装
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}未检测到 Docker，需要安装${NC}"
    INSTALL_DOCKER=true
else
    echo -e "${GREEN}Docker 已安装${NC}"
    docker --version
    INSTALL_DOCKER=false
fi

# 检查Docker Compose是否已安装
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}未检测到 Docker Compose，需要安装${NC}"
    INSTALL_DOCKER_COMPOSE=true
else
    echo -e "${GREEN}Docker Compose 已安装${NC}"
    docker-compose --version
    INSTALL_DOCKER_COMPOSE=false
fi

# 启动主菜单
main_menu

echo -e "${GREEN}脚本执行完成!${NC}"