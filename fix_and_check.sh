#!/bin/bash
# -*- coding: utf-8 -*-
"""
修复文件格式问题并验证部署环境
"""

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}修复文件格式并验证部署环境${NC}"
echo -e "${BLUE}========================================${NC}"

# 修复所有Shell脚本的换行符
fix_shell_scripts() {
    echo -e "${YELLOW}正在修复Shell脚本换行符...${NC}"
    
    find . -name "*.sh" -type f | while read -r file; do
        echo -e "  修复: $file"
        sed -i 's/\r$//' "$file"
        chmod +x "$file"
    done
    
    echo -e "${GREEN}Shell脚本修复完成!${NC}"
}

# 修复Dockerfile换行符
fix_dockerfiles() {
    echo -e "${YELLOW}正在修复Dockerfile换行符...${NC}"
    
    find . -name "Dockerfile*" -type f | while read -r file; do
        echo -e "  修复: $file"
        sed -i 's/\r$//' "$file"
    done
    
    echo -e "${GREEN}Dockerfile修复完成!${NC}"
}

# 修复crontab文件
fix_crontab() {
    echo -e "${YELLOW}正在修复crontab文件...${NC}"
    
    if [ -f "./worker/crontab" ]; then
        echo -e "  修复: ./worker/crontab"
        sed -i 's/\r$//' "./worker/crontab"
        echo -e "${GREEN}crontab文件修复完成!${NC}"
    else
        echo -e "${YELLOW}未找到crontab文件${NC}"
    fi
}

# 创建.env文件（如果不存在）
create_env_file() {
    echo -e "${YELLOW}正在检查环境变量文件...${NC}"
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            echo -e "${GREEN}已从 .env.example 创建 .env 文件${NC}"
            
            # 生成随机密码
            MYSQL_PASSWORD=$(openssl rand -base64 12)
            PG_PASSWORD=$(openssl rand -base64 12)
            API_KEY=$(openssl rand -base64 16)
            
            # 更新环境变量文件
            sed -i "s/your_secure_mysql_password/$MYSQL_PASSWORD/g" .env
            sed -i "s/your_secure_postgres_password/$PG_PASSWORD/g" .env
            sed -i "s/your_secure_api_key_for_fastapi/$API_KEY/g" .env
            
            echo -e "${GREEN}环境变量已自动配置${NC}"
        else
            echo -e "${RED}错误: 未找到 .env.example 文件${NC}"
        fi
    else
        echo -e "${GREEN}.env 文件已存在${NC}"
    fi
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
}

# 检查Docker是否安装
check_docker() {
    echo -e "${YELLOW}正在检查Docker环境...${NC}"
    
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}Docker 已安装${NC}"
        docker --version
        return 0
    else
        echo -e "${RED}错误: Docker 未安装${NC}"
        echo -e "${YELLOW}请运行 deploy.sh 脚本进行完整安装${NC}"
        return 1
    fi
}

# 检查Docker Compose是否安装
check_docker_compose() {
    echo -e "${YELLOW}正在检查Docker Compose环境...${NC}"
    
    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}Docker Compose 已安装${NC}"
        docker-compose --version
        return 0
    else
        echo -e "${RED}错误: Docker Compose 未安装${NC}"
        echo -e "${YELLOW}请运行 deploy.sh 脚本进行完整安装${NC}"
        return 1
    fi
}

# 验证配置文件
validate_config() {
    echo -e "${YELLOW}正在验证配置文件...${NC}"
    
    # 检查docker-compose.yml
    if [ -f "docker-compose.yml" ]; then
        echo -e "${GREEN}docker-compose.yml 存在${NC}"
    else
        echo -e "${RED}错误: docker-compose.yml 不存在${NC}"
        return 1
    fi
    
    # 检查API目录
    if [ -d "api" ] && [ -f "api/feedback_insert.py" ]; then
        echo -e "${GREEN}API服务配置完整${NC}"
    else
        echo -e "${RED}错误: API服务配置不完整${NC}"
        return 1
    fi
    
    # 检查worker目录
    if [ -d "worker" ] && [ -f "worker/run_all.py" ]; then
        echo -e "${GREEN}Worker服务配置完整${NC}"
    else
        echo -e "${RED}错误: Worker服务配置不完整${NC}"
        return 1
    fi
    
    echo -e "${GREEN}配置文件验证通过!${NC}"
    return 0
}

# 显示系统信息
show_system_info() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}系统信息${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # 操作系统信息
    if [ -f "/etc/os-release" ]; then
        . /etc/os-release
        echo -e "操作系统: $PRETTY_NAME"
    fi
    
    # 内存信息
    echo -e "内存信息:"
    free -h
    
    # 磁盘信息
    echo -e "磁盘信息:"
    df -h
    
    # CPU信息
    echo -e "CPU信息:"
    nproc
    
    echo -e "${BLUE}========================================${NC}"
}

# 主函数
main() {
    # 修复文件格式
    fix_shell_scripts
    fix_dockerfiles
    fix_crontab
    
    # 准备环境
    create_env_file
    create_data_dirs
    
    # 检查依赖
    check_docker
    check_docker_compose
    
    # 验证配置
    validate_config
    
    # 显示系统信息
    show_system_info
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}修复和验证完成!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e ""
    echo -e "${BLUE}下一步操作:${NC}"
    echo -e "  1. 配置Coze API信息:"
    echo -e "     ${YELLOW}vi .env${NC}"
    echo -e "     修改 COZE_API_KEY 和 COZE_APP_ID"
    echo -e ""
    echo -e "  2. 启动服务:"
    echo -e "     ${YELLOW}docker-compose up -d${NC}"
    echo -e ""
    echo -e "  3. 查看服务状态:"
    echo -e "     ${YELLOW}docker-compose ps${NC}"
    echo -e ""
    echo -e "  4. 查看日志:"
    echo -e "     ${YELLOW}docker-compose logs -f${NC}"
    echo -e ""
}

# 执行主函数
main

echo -e "${GREEN}修复脚本执行完成!${NC}"