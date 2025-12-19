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

# 安装Docker（增强版，支持多种安装方式）
install_docker() {
    echo -e "${YELLOW}正在安装 Docker...${NC}"
    
    # 网络诊断
    echo -e "${BLUE}正在进行网络诊断...${NC}"
    ping -c 2 www.baidu.com > /dev/null 2>&1 || echo -e "${YELLOW}警告: 无法访问百度，可能存在网络问题${NC}"
    ping -c 2 mirrors.aliyun.com > /dev/null 2>&1 || echo -e "${YELLOW}警告: 无法访问阿里云镜像，将使用备用源${NC}"
    
    # 卸载旧版本
    apt-get remove -y docker docker.io containerd runc 2>/dev/null || true
    
    # 安装依赖
    echo -e "${BLUE}安装必要依赖...${NC}"
    apt-get update -o Acquire::http::Timeout=30 -o Acquire::Retries=3
    apt-get install -y -o Dpkg::Options::="--force-confold" \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common \
        wget \
        net-tools \
        iputils-ping
    
    # 方法1: 尝试使用官方脚本（带多个镜像源）
    echo -e "${BLUE}尝试使用官方安装脚本...${NC}"
    DOCKER_INSTALL_SUCCESS=false
    
    # 尝试多个镜像源
    for mirror in "Aliyun" "AzureChinaCloud" "TencentCloud"; do
        echo -e "${BLUE}尝试 $mirror 镜像源...${NC}"
        if curl -fsSL https://get.docker.com | bash -s docker --mirror $mirror; then
            echo -e "${GREEN}Docker安装成功!${NC}"
            DOCKER_INSTALL_SUCCESS=true
            break
        else
            echo -e "${YELLOW}$mirror 镜像源失败，尝试下一个...${NC}"
            sleep 2
        fi
    done
    
    # 方法2: 如果方法1失败，使用apt直接安装
    if [ "$DOCKER_INSTALL_SUCCESS" = false ]; then
        echo -e "${YELLOW}所有脚本安装方式失败，尝试apt直接安装...${NC}"
        
        # 添加Docker GPG密钥
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - 2>/dev/null || {
            echo -e "${YELLOW}无法获取官方GPG密钥，使用备用方式...${NC}"
            apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7EA0A9C3F273FCD8 2>/dev/null || true
        }
        
        # 添加Docker仓库（使用IPv4）
        add-apt-repository -y \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) \
            stable"
        
        # 安装Docker
        apt-get update -o Acquire::http::Timeout=30 -o Acquire::Retries=3
        apt-get install -y -o Dpkg::Options::="--force-confold" docker-ce docker-ce-cli containerd.io
        
        if command -v docker &> /dev/null; then
            DOCKER_INSTALL_SUCCESS=true
            echo -e "${GREEN}Docker apt安装成功!${NC}"
        fi
    fi
    
    # 方法3: 如果所有在线安装都失败，提示离线安装
    if [ "$DOCKER_INSTALL_SUCCESS" = false ]; then
        echo -e "${RED}所有在线安装方式都失败了!${NC}"
        echo -e "${YELLOW}建议使用离线安装方式:${NC}"
        echo -e "1. 在有网络的机器上下载Docker安装包"
        echo -e "2. 传输到当前服务器并手动安装"
        echo -e "3. 或使用Docker官方离线安装包"
        echo -e ""
        echo -e "${BLUE}继续尝试配置环境...${NC}"
    fi
    
    # 配置Docker镜像加速（使用多个镜像源）
    echo -e "${BLUE}配置Docker镜像加速...${NC}"
    mkdir -p /etc/docker
    
    # 配置多个镜像源以提高成功率
    cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://mirror.ccs.tencentyun.com",
    "https://hub-mirror.c.163.com",
    "https://reg-mirror.qiniu.com",
    "https://registry.cn-hangzhou.aliyuncs.com",
    "https://registry.cn-shanghai.aliyuncs.com",
    "https://registry.cn-shenzhen.aliyuncs.com"
  ],
  "dns": ["8.8.8.8", "114.114.114.114"],
  "ipv6": false
}
EOF
    
    # 启动Docker服务
    echo -e "${BLUE}启动Docker服务...${NC}"
    systemctl daemon-reload
    systemctl start docker || echo -e "${YELLOW}Docker启动失败，尝试修复...${NC}"
    systemctl enable docker || echo -e "${YELLOW}Docker自启动配置失败${NC}"
    
    # 验证安装
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}Docker 安装成功!${NC}"
        docker --version
    else
        echo -e "${RED}Docker安装失败!${NC}"
        echo -e "${YELLOW}请检查网络连接或手动安装Docker${NC}"
        return 1
    fi
    
    # 验证镜像加速配置
    echo -e "${BLUE}Docker镜像加速配置:${NC}"
    docker info | grep "Registry Mirrors" || echo -e "${YELLOW}镜像加速配置可能未生效${NC}"
}

# 安装Docker Compose（增强版，修复权限问题）
install_docker_compose() {
    echo -e "${YELLOW}正在安装 Docker Compose...${NC}"
    
    # 清理可能存在的损坏文件
    echo -e "${BLUE}清理可能存在的损坏文件...${NC}"
    rm -f /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
    
    # 安装pip（如果没有）
    if ! command -v pip3 &> /dev/null; then
        echo -e "${BLUE}安装pip3...${NC}"
        apt-get install -y python3-pip python3-setuptools python3-wheel
    fi
    
    # 配置pip国内源
    mkdir -p ~/.pip
    cat > ~/.pip/pip.conf << 'EOF'
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
[install]
trusted-host=mirrors.aliyun.com
EOF
    
    # 方法1: pip安装（最可靠的方式）
    echo -e "${BLUE}方法1: 使用pip安装Docker Compose...${NC}"
    if pip3 install docker-compose -i https://mirrors.aliyun.com/pypi/simple/; then
        echo -e "${GREEN}pip安装Docker Compose成功!${NC}"
        
        # 确保pip安装的可执行文件在PATH中
        PIP_BIN_PATH=$(pip3 show docker-compose | grep Location | awk '{print $2}')/bin
        if [ -f "$PIP_BIN_PATH/docker-compose" ]; then
            ln -sf "$PIP_BIN_PATH/docker-compose" /usr/bin/docker-compose 2>/dev/null || true
            chmod +x "$PIP_BIN_PATH/docker-compose"
        fi
        
        if command -v docker-compose &> /dev/null; then
            docker-compose --version
            return 0
        fi
    else
        echo -e "${YELLOW}pip安装失败，尝试其他方法...${NC}"
    fi
    
    # 方法2: 下载二进制文件（修复权限问题）
    echo -e "${BLUE}方法2: 下载Docker Compose二进制文件...${NC}"
    
    # 定义下载URL列表
    declare -a DOWNLOAD_URLS=(
        "https://mirrors.aliyun.com/docker-toolbox/linux/compose/2.21.0/docker-compose-Linux-x86_64"
        "https://mirror.ghproxy.com/https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-Linux-x86_64"
        "https://gh-proxy.com/https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-Linux-x86_64"
        "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-Linux-x86_64"
    )
    
    # 尝试从多个源下载
    for url in "${DOWNLOAD_URLS[@]}"; do
        echo -e "${BLUE}尝试从 $url 下载...${NC}"
        
        # 先下载到临时目录，避免权限问题
        if curl -L --connect-timeout 30 --retry 3 "$url" -o /tmp/docker-compose; then
            echo -e "${GREEN}下载成功!${NC}"
            
            # 修复权限并移动文件
            chmod 755 /tmp/docker-compose
            mv -f /tmp/docker-compose /usr/local/bin/docker-compose
            
            # 确保权限正确
            chmod 755 /usr/local/bin/docker-compose
            
            # 创建软链接
            ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
            
            # 验证安装
            if command -v docker-compose &> /dev/null; then
                echo -e "${GREEN}Docker Compose 安装成功!${NC}"
                docker-compose --version
                return 0
            else
                echo -e "${YELLOW}无法找到docker-compose命令，尝试下一个源...${NC}"
                rm -f /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
            fi
        else
            echo -e "${YELLOW}从 $url 下载失败${NC}"
        fi
        sleep 2
    done
    
    # 方法3: 安装docker-compose-plugin（Docker官方推荐的新方式）
    echo -e "${BLUE}方法3: 尝试安装docker-compose-plugin...${NC}"
    if apt-get install -y docker-compose-plugin; then
        echo -e "${GREEN}docker-compose-plugin 安装成功!${NC}"
        
        # 创建软链接（修复权限）
        if [ -f "/usr/libexec/docker/cli-plugins/docker-compose" ]; then
            chmod 755 /usr/libexec/docker/cli-plugins/docker-compose
            ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose 2>/dev/null || true
            chmod 755 /usr/bin/docker-compose 2>/dev/null || true
        fi
        
        if docker compose version &> /dev/null; then
            echo -e "${GREEN}Docker Compose Plugin 安装成功!${NC}"
            return 0
        fi
    fi
    
    # 方法4: 直接复制内置的docker-compose文件（离线备用）
    echo -e "${BLUE}方法4: 检查是否有内置的docker-compose文件...${NC}"
    if [ -f "./docker-compose-linux-x86_64" ]; then
        echo -e "${GREEN}找到内置的docker-compose文件!${NC}"
        cp -f ./docker-compose-linux-x86_64 /usr/local/bin/docker-compose
        chmod 755 /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
        
        if command -v docker-compose &> /dev/null; then
            echo -e "${GREEN}Docker Compose 安装成功!${NC}"
            docker-compose --version
            return 0
        fi
    fi
    
    # 如果所有方法都失败
    echo -e "${RED}Docker Compose 安装失败!${NC}"
    echo -e "${YELLOW}错误分析:${NC}"
    echo -e "1. 权限问题: 请检查/usr/local/bin目录权限"
    echo -e "2. 网络问题: 请检查网络连接和代理设置"
    echo -e "3. 磁盘空间: 请检查磁盘空间是否充足"
    echo -e ""
    echo -e "${YELLOW}建议手动安装:${NC}"
    echo -e "1. 下载文件: wget https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-Linux-x86_64"
    echo -e "2. 移动文件: mv docker-compose-Linux-x86_64 /usr/local/bin/docker-compose"
    echo -e "3. 添加权限: chmod +x /usr/local/bin/docker-compose"
    echo -e "4. 创建链接: ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose"
    echo -e ""
    echo -e "${BLUE}继续执行脚本...${NC}"
    
    return 1
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