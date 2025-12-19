#!/bin/bash
# Simple Docker deployment script for Ubuntu 22.04 LTS

echo "========================================="
echo "Simple Docker Deployment Script"
echo "Ubuntu 22.04 LTS (Jammy Jellyfish) 优化版"
echo "========================================="

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "Error: Please run this script as root"
   exit 1
fi

# Check Ubuntu version
UBUNTU_VERSION=$(lsb_release -r | awk '{print $2}')
if [[ "$UBUNTU_VERSION" != "22.04"* ]]; then
    echo "Warning: This script is optimized for Ubuntu 22.04 LTS"
    echo "You are running Ubuntu $UBUNTU_VERSION"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update system
echo "Updating system packages..."
apt-get update -o Acquire::http::Timeout=30 -o Acquire::Retries=3
apt-get upgrade -y -o Dpkg::Options::="--force-confold"

# Install basic tools
echo "Installing basic tools..."
apt-get install -y wget curl vim git unzip apt-transport-https ca-certificates gnupg lsb-release software-properties-common

# Disable IPv6 to avoid connection issues
echo "Disabling IPv6..."
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p 2>/dev/null || echo "IPv6 disable warning (non-critical)"

# Configure DNS
echo "Configuring DNS..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 114.114.114.114" >> /etc/resolv.conf

# 备份原有apt源
echo "Backing up original apt sources..."
cp /etc/apt/sources.list /etc/apt/sources.list.bak

# 配置Ubuntu 22.04专用阿里云源
echo "Configuring Alibaba Cloud mirrors for Ubuntu 22.04..."
cat > /etc/apt/sources.list << 'EOF'
deb [arch=amd64] http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb [arch=amd64] http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb [arch=amd64] http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb [arch=amd64] http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
EOF

# 更新apt缓存
apt-get clean
apt-get update -o Acquire::http::Timeout=30 -o Acquire::Retries=3

# 方法1: 尝试使用官方脚本安装Docker
echo "Installing Docker..."
DOCKER_INSTALL_SUCCESS=false

# 尝试多种安装方式
echo "Method 1: Using Docker official script with Aliyun mirror..."
if curl -fsSL https://get.docker.com -o get-docker.sh && chmod +x get-docker.sh; then
    if ./get-docker.sh --mirror Aliyun; then
        echo "Docker installed successfully via official script!"
        DOCKER_INSTALL_SUCCESS=true
    else
        echo "Official script failed, trying alternative methods..."
    fi
fi

# 方法2: 如果方法1失败，使用apt直接安装
if [ "$DOCKER_INSTALL_SUCCESS" = false ]; then
    echo "Method 2: Installing Docker via apt..."
    
    # 添加Docker GPG密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # 添加Docker源
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 安装Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    if command -v docker &> /dev/null; then
        echo "Docker installed successfully via apt!"
        DOCKER_INSTALL_SUCCESS=true
    fi
fi

# 方法3: 如果前两种方法都失败，使用docker.io包
if [ "$DOCKER_INSTALL_SUCCESS" = false ]; then
    echo "Method 3: Installing docker.io package..."
    apt-get install -y docker.io
    
    if command -v docker &> /dev/null; then
        echo "Docker installed successfully via docker.io package!"
        DOCKER_INSTALL_SUCCESS=true
    fi
fi

# 如果所有方法都失败
if [ "$DOCKER_INSTALL_SUCCESS" = false ]; then
    echo "Error: All Docker installation methods failed!"
    echo "Please check your network connection and try again."
    exit 1
fi

# 确保/etc/docker目录存在
if [ ! -d "/etc/docker" ]; then
    mkdir -p /etc/docker
fi

# 配置Docker daemon（Ubuntu 22.04优化）
cat > /etc/docker/daemon.json << 'EOF'
{
  "storage-driver": "overlay2",
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://mirror.ccs.tencentyun.com",
    "https://hub-mirror.c.163.com",
    "https://reg-mirror.qiniu.com",
    "https://registry.cn-hangzhou.aliyuncs.com"
  ],
  "dns": ["8.8.8.8", "114.114.114.114"],
  "ipv6": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  }
}
EOF

# 检查systemd是否可用（Ubuntu 22.04默认使用systemd）
if command -v systemctl &> /dev/null; then
    echo "Using systemd to manage Docker service..."
    systemctl daemon-reload
    systemctl restart docker
    systemctl enable docker
else
    echo "Using sysvinit to manage Docker service..."
    service docker restart 2>/dev/null || echo "Docker restart warning"
    update-rc.d docker defaults 2>/dev/null || echo "Docker autostart config warning"
fi

# 验证Docker安装
if command -v docker &> /dev/null; then
    echo "Docker installed successfully!"
    docker --version
    
    # 检查存储驱动
    STORAGE_DRIVER=$(docker info | grep "Storage Driver" | awk '{print $3}')
    echo "Storage Driver: $STORAGE_DRIVER"
    
    # 如果不是overlay2，显示警告
    if [ "$STORAGE_DRIVER" != "overlay2" ]; then
        echo "Warning: Current storage driver is $STORAGE_DRIVER, recommended is overlay2"
        echo "You may need to update your kernel or configure Docker properly."
    fi
else
    echo "Docker installation failed!"
    exit 1
fi

# 安装Docker Compose（Ubuntu 22.04优化版）
echo "Installing Docker Compose..."

# 方法1: 下载二进制文件
echo "Method 1: Downloading Docker Compose binary..."
DOCKER_COMPOSE_URLS=(
    "https://mirrors.aliyun.com/docker-toolbox/linux/compose/2.21.0/docker-compose-Linux-x86_64"
    "https://mirror.ghproxy.com/https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-Linux-x86_64"
    "https://gh-proxy.com/https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-Linux-x86_64"
    "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-Linux-x86_64"
)

COMPOSE_INSTALLED=false
for url in "${DOCKER_COMPOSE_URLS[@]}"; do
    echo "Trying to download from: $url"
    if curl -L --connect-timeout 30 --retry 3 "$url" -o /tmp/docker-compose; then
        echo "Download successful!"
        
        # 修复权限问题
        chmod 755 /tmp/docker-compose
        mv -f /tmp/docker-compose /usr/local/bin/docker-compose
        chmod 755 /usr/local/bin/docker-compose
        
        # 创建软链接
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
        
        # 验证安装
        if command -v docker-compose &> /dev/null; then
            echo "Docker Compose installed successfully!"
            docker-compose --version
            COMPOSE_INSTALLED=true
            break
        else
            echo "Cannot find docker-compose command, trying next source..."
            rm -f /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
        fi
    else
        echo "Download failed from $url"
    fi
    sleep 2
done

# 方法2: 如果二进制下载失败，使用pip安装
if [ "$COMPOSE_INSTALLED" = false ]; then
    echo "Method 2: Installing Docker Compose via pip..."
    
    # 安装pip（如果没有）
    if ! command -v pip3 &> /dev/null; then
        echo "Installing pip3..."
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
    
    if pip3 install docker-compose -i https://mirrors.aliyun.com/pypi/simple/; then
        echo "Docker Compose installed via pip successfully!"
        
        # 确保pip安装的可执行文件在PATH中
        PIP_BIN_PATH=$(pip3 show docker-compose | grep Location | awk '{print $2}')/bin
        if [ -f "$PIP_BIN_PATH/docker-compose" ]; then
            ln -sf "$PIP_BIN_PATH/docker-compose" /usr/bin/docker-compose 2>/dev/null || true
            chmod +x "$PIP_BIN_PATH/docker-compose"
        fi
        
        if command -v docker-compose &> /dev/null; then
            docker-compose --version
            COMPOSE_INSTALLED=true
        fi
    else
        echo "pip installation failed!"
    fi
fi

# 方法3: 如果都失败，安装docker-compose-plugin（Ubuntu 22.04官方推荐）
if [ "$COMPOSE_INSTALLED" = false ]; then
    echo "Method 3: Installing docker-compose-plugin..."
    if apt-get install -y docker-compose-plugin; then
        echo "docker-compose-plugin installed successfully!"
        
        # 创建软链接
        if [ -f "/usr/libexec/docker/cli-plugins/docker-compose" ]; then
            chmod 755 /usr/libexec/docker/cli-plugins/docker-compose
            ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose 2>/dev/null || true
        fi
        
        if docker compose version &> /dev/null; then
            echo "Docker Compose Plugin installed successfully!"
            docker compose version
            COMPOSE_INSTALLED=true
        fi
    fi
fi

if [ "$COMPOSE_INSTALLED" = false ]; then
    echo "Error: All Docker Compose installation methods failed!"
    echo "Please install Docker Compose manually:"
    echo "1. Download: wget https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-Linux-x86_64"
    echo "2. Install: mv docker-compose-Linux-x86_64 /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose"
    exit 1
fi

# 创建数据目录（Ubuntu 22.04权限优化）
echo "Creating data directories..."
mkdir -p /data/mysql /data/postgresql /data/logs

# 设置合适的权限
chmod -R 777 /data
chown -R root:root /data

# 显示系统信息
echo "========================================="
echo "System Information:"
echo "Ubuntu Version: $(lsb_release -d | awk -F'\t' '{print $2}')"
echo "Kernel Version: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Docker Version: $(docker --version)"
echo "Docker Compose Version: $(docker-compose --version)"
echo "Storage Driver: $(docker info | grep "Storage Driver" | awk '{print $3}')"
echo "========================================="
echo "Docker environment setup completed!"
echo "========================================="
echo "Next steps:"
echo "1. Create .env file from .env.example"
echo "2. Run: docker-compose -f docker-compose.aliyun.yml up -d"
echo "3. Check services: docker-compose -f docker-compose.aliyun.yml ps"
echo ""
echo "Data directories created:"
echo "- MySQL: /data/mysql"
echo "- PostgreSQL: /data/postgresql"
echo "- Logs: /data/logs"
echo ""
echo "For Ubuntu 22.04 specific issues, check:"
echo "- Storage driver should be 'overlay2'"
echo "- Docker service managed by systemd"
echo "- All required ports are open (8001, 3306, 5432)"
echo "========================================="