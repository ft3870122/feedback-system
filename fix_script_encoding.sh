#!/bin/bash
# -*- coding: utf-8 -*-
"""
脚本编码修复工具
修复deploy.sh文件的编码问题
"""

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}脚本编码修复工具${NC}"
echo -e "${BLUE}========================================${NC}"

# 检查root权限
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}错误: 请以root用户运行此脚本${NC}"
   exit 1
fi

# 备份原文件
echo -e "${BLUE}备份原文件...${NC}"
cp deploy.sh deploy.sh.bak
echo -e "${GREEN}✓ 已备份为 deploy.sh.bak${NC}"

# 检查文件编码
echo -e "${BLUE}检查文件编码...${NC}"
file deploy.sh

# 修复文件编码问题
echo -e "${BLUE}修复文件编码...${NC}"

# 创建一个新的干净的脚本文件
cat > deploy.sh.fixed << 'EOF'
#!/bin/bash
# Ubuntu Docker Deployment Script

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Tag Closed Loop System - Ubuntu Docker Deploy Script${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}Error: Please run this script as root${NC}"
   exit 1
fi

# Install Docker (Enhanced version with multiple installation methods)
install_docker() {
    echo -e "${YELLOW}Installing Docker...${NC}"
    
    # Network diagnostics
    echo -e "${BLUE}Running network diagnostics...${NC}"
    ping -c 2 www.baidu.com > /dev/null 2>&1 || echo -e "${YELLOW}Warning: Cannot access Baidu, network may have issues${NC}"
    ping -c 2 mirrors.aliyun.com > /dev/null 2>&1 || echo -e "${YELLOW}Warning: Cannot access Alibaba Cloud mirror, will use backup sources${NC}"
    
    # Remove old versions
    apt-get remove -y docker docker.io containerd runc 2>/dev/null || true
    
    # Install dependencies
    echo -e "${BLUE}Installing necessary dependencies...${NC}"
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
    
    # Method 1: Try using official script (with multiple mirror sources)
    echo -e "${BLUE}Trying to use official installation script...${NC}"
    DOCKER_INSTALL_SUCCESS=false
    
    # Try multiple mirror sources
    for mirror in "Aliyun" "AzureChinaCloud" "TencentCloud"; do
        echo -e "${BLUE}Trying $mirror mirror source...${NC}"
        if curl -fsSL https://get.docker.com | bash -s docker --mirror $mirror; then
            echo -e "${GREEN}Docker installed successfully!${NC}"
            DOCKER_INSTALL_SUCCESS=true
            break
        else
            echo -e "${YELLOW}$mirror mirror source failed, trying next...${NC}"
            sleep 2
        fi
    done
    
    # Method 2: If method 1 fails, use apt direct installation
    if [ "$DOCKER_INSTALL_SUCCESS" = false ]; then
        echo -e "${YELLOW}All script installation methods failed, trying apt direct installation...${NC}"
        
        # Add Docker GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - 2>/dev/null || {
            echo -e "${YELLOW}Cannot get official GPG key, using alternative method...${NC}"
            apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7EA0A9C3F273FCD8 2>/dev/null || true
        }
        
        # Add Docker repository (using IPv4)
        add-apt-repository -y \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) \
            stable"
        
        # Install Docker
        apt-get update -o Acquire::http::Timeout=30 -o Acquire::Retries=3
        apt-get install -y -o Dpkg::Options::="--force-confold" docker-ce docker-ce-cli containerd.io
        
        if command -v docker &> /dev/null; then
            DOCKER_INSTALL_SUCCESS=true
            echo -e "${GREEN}Docker apt installation successful!${NC}"
        fi
    fi
    
    # Method 3: If all online installations fail, suggest offline installation
    if [ "$DOCKER_INSTALL_SUCCESS" = false ]; then
        echo -e "${RED}All online installation methods failed!${NC}"
        echo -e "${YELLOW}Suggest using offline installation method:${NC}"
        echo -e "1. Download Docker installation package on a machine with internet"
        echo -e "2. Transfer to current server and install manually"
        echo -e "3. Or use Docker official offline installation package"
        echo -e ""
        echo -e "${BLUE}Continuing to try configuring environment...${NC}"
    fi
    
    # Configure Docker image acceleration (using multiple mirror sources)
    echo -e "${BLUE}Configuring Docker image acceleration...${NC}"
    mkdir -p /etc/docker
    
    # Configure multiple mirror sources to improve success rate
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
    
    # Start Docker service
    echo -e "${BLUE}Starting Docker service...${NC}"
    systemctl daemon-reload
    systemctl start docker || echo -e "${YELLOW}Docker start failed, trying to fix...${NC}"
    systemctl enable docker || echo -e "${YELLOW}Docker autostart configuration failed${NC}"
    
    # Verify installation
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}Docker installed successfully!${NC}"
        docker --version
    else
        echo -e "${RED}Docker installation failed!${NC}"
        echo -e "${YELLOW}Please check network connection or install Docker manually${NC}"
        return 1
    fi
    
    # Verify image acceleration configuration
    echo -e "${BLUE}Docker image acceleration configuration:${NC}"
    docker info | grep "Registry Mirrors" || echo -e "${YELLOW}Image acceleration configuration may not be effective${NC}"
}

# Install Docker Compose (Enhanced version, fixing permission issues)
install_docker_compose() {
    echo -e "${YELLOW}Installing Docker Compose...${NC}"
    
    # Clean up potentially corrupted files
    echo -e "${BLUE}Cleaning up potentially corrupted files...${NC}"
    rm -f /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
    
    # Install pip if not available
    if ! command -v pip3 &> /dev/null; then
        echo -e "${BLUE}Installing pip3...${NC}"
        apt-get install -y python3-pip python3-setuptools python3-wheel
    fi
    
    # Configure pip domestic source
    mkdir -p ~/.pip
    cat > ~/.pip/pip.conf << 'EOF'
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
[install]
trusted-host=mirrors.aliyun.com
EOF
    
    # Method 1: pip installation (most reliable way)
    echo -e "${BLUE}Method 1: Installing Docker Compose using pip...${NC}"
    if pip3 install docker-compose -i https://mirrors.aliyun.com/pypi/simple/; then
        echo -e "${GREEN}pip installation of Docker Compose successful!${NC}"
        
        # Ensure pip installed executable is in PATH
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
        echo -e "${YELLOW}pip installation failed, trying other methods...${NC}"
    fi
    
    # Method 2: Download binary file (fixing permission issues)
    echo -e "${BLUE}Method 2: Downloading Docker Compose binary file...${NC}"
    
    # Define download URL list
    declare -a DOWNLOAD_URLS=(
        "https://mirrors.aliyun.com/docker-toolbox/linux/compose/2.21.0/docker-compose-Linux-x86_64"
        "https://mirror.ghproxy.com/https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-Linux-x86_64"
        "https://gh-proxy.com/https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-Linux-x86_64"
        "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-Linux-x86_64"
    )
    
    # Try downloading from multiple sources
    for url in "${DOWNLOAD_URLS[@]}"; do
        echo -e "${BLUE}Trying to download from $url...${NC}"
        
        # First download to temporary directory to avoid permission issues
        if curl -L --connect-timeout 30 --retry 3 "$url" -o /tmp/docker-compose; then
            echo -e "${GREEN}Download successful!${NC}"
            
            # Fix permissions and move file
            chmod 755 /tmp/docker-compose
            mv -f /tmp/docker-compose /usr/local/bin/docker-compose
            
            # Ensure permissions are correct
            chmod 755 /usr/local/bin/docker-compose
            
            # Create symbolic link
            ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
            
            # Verify installation
            if command -v docker-compose &> /dev/null; then
                echo -e "${GREEN}Docker Compose installed successfully!${NC}"
                docker-compose --version
                return 0
            else
                echo -e "${YELLOW}Cannot find docker-compose command, trying next source...${NC}"
                rm -f /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
            fi
        else
            echo -e "${YELLOW}Download failed from $url${NC}"
        fi
        sleep 2
    done
    
    # Method 3: Install docker-compose-plugin (Docker official recommended new way)
    echo -e "${BLUE}Method 3: Trying to install docker-compose-plugin...${NC}"
    if apt-get install -y docker-compose-plugin; then
        echo -e "${GREEN}docker-compose-plugin installed successfully!${NC}"
        
        # Create symbolic link (fixing permissions)
        if [ -f "/usr/libexec/docker/cli-plugins/docker-compose" ]; then
            chmod 755 /usr/libexec/docker/cli-plugins/docker-compose
            ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose 2>/dev/null || true
            chmod 755 /usr/bin/docker-compose 2>/dev/null || true
        fi
        
        if docker compose version &> /dev/null; then
            echo -e "${GREEN}Docker Compose Plugin installed successfully!${NC}"
            return 0
        fi
    fi
    
    # Method 4: Directly copy built-in docker-compose file (offline backup)
    echo -e "${BLUE}Method 4: Checking for built-in docker-compose file...${NC}"
    if [ -f "./docker-compose-linux-x86_64" ]; then
        echo -e "${GREEN}Found built-in docker-compose file!${NC}"
        cp -f ./docker-compose-linux-x86_64 /usr/local/bin/docker-compose
        chmod 755 /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
        
        if command -v docker-compose &> /dev/null; then
            echo -e "${GREEN}Docker Compose installed successfully!${NC}"
            docker-compose --version
            return 0
        fi
    fi
    
    # If all methods fail
    echo -e "${RED}Docker Compose installation failed!${NC}"
    echo -e "${YELLOW}Error analysis:${NC}"
    echo -e "1. Permission issue: Please check /usr/local/bin directory permissions"
    echo -e "2. Network issue: Please check network connection and proxy settings"
    echo -e "3. Disk space: Please check if disk space is sufficient"
    echo -e ""
    echo -e "${YELLOW}Suggest manual installation:${NC}"
    echo -e "1. Download file: wget https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-Linux-x86_64"
    echo -e "2. Move file: mv docker-compose-Linux-x86_64 /usr/local/bin/docker-compose"
    echo -e "3. Add permission: chmod +x /usr/local/bin/docker-compose"
    echo -e "4. Create link: ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose"
    echo -e ""
    echo -e "${BLUE}Continuing to execute script...${NC}"
    
    return 1
}

# Create data directories
create_data_dirs() {
    echo -e "${YELLOW}Creating data directories...${NC}"
    
    # Create main data directories
    mkdir -p /data/mysql
    mkdir -p /data/postgresql
    mkdir -p /data/logs
    
    # Set permissions
    chmod -R 777 /data
    
    echo -e "${GREEN}Data directories created successfully!${NC}"
    echo -e "${BLUE}Data directories:${NC}"
    echo -e "  - MySQL: /data/mysql"
    echo -e "  - PostgreSQL: /data/postgresql"
    echo -e "  - Logs: /data/logs"
}

# Configure environment variables
configure_env() {
    echo -e "${YELLOW}Configuring environment variables...${NC}"
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            echo -e "${GREEN}Created .env file from .env.example${NC}"
        else
            echo -e "${RED}Error: .env.example file not found${NC}"
            exit 1
        fi
    fi
    
    # Generate random passwords
    MYSQL_PASSWORD=$(openssl rand -base64 12)
    PG_PASSWORD=$(openssl rand -base64 12)
    API_KEY=$(openssl rand -base64 16)
    
    # Update environment variable file
    sed -i "s/your_secure_mysql_password/$MYSQL_PASSWORD/g" .env
    sed -i "s/your_secure_postgres_password/$PG_PASSWORD/g" .env
    sed -i "s/your_secure_api_key_for_fastapi/$API_KEY/g" .env
    
    echo -e "${GREEN}Environment variables configured successfully!${NC}"
    echo -e "${YELLOW}Please edit .env file to configure Coze API information:${NC}"
    echo -e "  COZE_API_KEY=your_coze_api_key"
    echo -e "  COZE_APP_ID=your_coze_app_id"
}

# Build and start services (supporting domestic network)
start_services() {
    echo -e "${YELLOW}Building and starting services...${NC}"
    
    # Check if domestic mirror version configuration file exists
    if [ -f "docker-compose.aliyun.yml" ]; then
        echo -e "${BLUE}Detected domestic mirror version configuration file, using it preferentially...${NC}"
        COMPOSE_FILE="docker-compose.aliyun.yml"
    else
        echo -e "${BLUE}Using default configuration file...${NC}"
        COMPOSE_FILE="docker-compose.yml"
    fi
    
    # Pre-pull base images (domestic optimization)
    echo -e "${BLUE}Pre-pulling base Docker images...${NC}"
    if [ "$COMPOSE_FILE" = "docker-compose.aliyun.yml" ]; then
        # Pull images from Alibaba Cloud
        docker pull registry.cn-hangzhou.aliyuncs.com/library/mysql:8.0 2>/dev/null || echo -e "${YELLOW}MySQL image pull failed, will pull during build${NC}"
        docker pull registry.cn-hangzhou.aliyuncs.com/library/postgres:15 2>/dev/null || echo -e "${YELLOW}PostgreSQL image pull failed, will pull during build${NC}"
        docker pull registry.cn-hangzhou.aliyuncs.com/library/python:3.8-slim 2>/dev/null || echo -e "${YELLOW}Python image pull failed, will pull during build${NC}"
    else
        # Pull default images
        docker pull mysql:8.0 2>/dev/null || echo -e "${YELLOW}MySQL image pull failed, will pull during build${NC}"
        docker pull postgres:15 2>/dev/null || echo -e "${YELLOW}PostgreSQL image pull failed, will pull during build${NC}"
        docker pull python:3.8-slim 2>/dev/null || echo -e "${YELLOW}Python image pull failed, will pull during build${NC}"
    fi
    
    # Build images
    echo -e "${BLUE}Building Docker images...${NC}"
    echo -e "${YELLOW}Note: First build may take a long time, please be patient...${NC}"
    docker-compose -f "$COMPOSE_FILE" build
    
    # Start services
    echo -e "${BLUE}Starting services...${NC}"
    docker-compose -f "$COMPOSE_FILE" up -d
    
    echo -e "${GREEN}Services started successfully!${NC}"
    
    # Show service status
    echo -e "${BLUE}Service status:${NC}"
    docker-compose -f "$COMPOSE_FILE" ps
    
    # Save used configuration file information
    echo "$COMPOSE_FILE" > .compose_file_used
    echo -e "${YELLOW}Used configuration file: $COMPOSE_FILE${NC}"
}

# Show access information
show_access_info() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment completed!${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
    
    echo -e "${BLUE}Access information:${NC}"
    echo -e "  - API address: http://$SERVER_IP:8001"
    echo -e "  - API health check: http://$SERVER_IP:8001/health"
    echo -e "  - API statistics: http://$SERVER_IP:8001/stats"
    echo -e "  - MySQL port: 3306"
    echo -e "  - PostgreSQL port: 5432"
    
    echo -e ""
    echo -e "${YELLOW}Important notes:${NC}"
    echo -e "  1. Please ensure Alibaba Cloud security group has opened relevant ports"
    echo -e "  2. Please configure Coze Agent to call http://$SERVER_IP:8001/insert_feedback"
    echo -e "  3. API key has been automatically generated, check API_KEY in .env file"
    echo -e ""
    echo -e "${BLUE}View logs:${NC}"
    echo -e "  - docker-compose logs -f feedback-api"
    echo -e "  - docker-compose logs -f feedback-worker"
    echo -e ""
    echo -e "${BLUE}Restart services:${NC}"
    echo -e "  - docker-compose restart"
    echo -e ""
}

# Main menu
main_menu() {
    echo -e ""
    echo -e "${BLUE}Please select an operation:${NC}"
    echo -e "  1) Complete installation (recommended)"
    echo -e "  2) Only install Docker and Docker Compose"
    echo -e "  3) Only configure environment and start services"
    echo -e "  4) Exit"
    echo -e ""
    
    read -p "Please enter your choice [1-4]: " choice
    
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
            echo -e "${BLUE}Exiting script${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            main_menu
            ;;
    esac
}

# Check if Docker is already installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker not detected, need to install${NC}"
    INSTALL_DOCKER=true
else
    echo -e "${GREEN}Docker already installed${NC}"
    docker --version
    INSTALL_DOCKER=false
fi

# Check if Docker Compose is already installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}Docker Compose not detected, need to install${NC}"
    INSTALL_DOCKER_COMPOSE=true
else
    echo -e "${GREEN}Docker Compose already installed${NC}"
    docker-compose --version
    INSTALL_DOCKER_COMPOSE=false
fi

# Start main menu
main_menu

echo -e "${GREEN}Script execution completed!${NC}"
EOF

# Replace the original file with the fixed version
mv -f deploy.sh.fixed deploy.sh
chmod +x deploy.sh

echo -e "${GREEN}✓ File encoding fixed successfully${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Fix completed!${NC}"
echo -e "${BLUE}You can now run the deploy.sh script${NC}"
echo -e "${BLUE}========================================${NC}"