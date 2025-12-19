#!/bin/bash
# -*- coding: utf-8 -*-
"""
Docker 安装测试脚本
用于验证Docker安装修复是否有效
"""

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Docker 安装测试脚本${NC}"
echo -e "${BLUE}========================================${NC}"

# 网络诊断函数
network_diagnostics() {
    echo -e "${BLUE}正在进行网络诊断...${NC}"
    
    # 测试基本网络连接
    echo -e "${BLUE}测试基本网络连接...${NC}"
    ping -c 2 www.baidu.com > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 基本网络连接正常${NC}"
    else
        echo -e "${RED}✗ 无法访问百度，网络可能有问题${NC}"
    fi
    
    # 测试DNS解析
    echo -e "${BLUE}测试DNS解析...${NC}"
    nslookup www.baidu.com > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ DNS解析正常${NC}"
    else
        echo -e "${RED}✗ DNS解析失败${NC}"
    fi
    
    # 测试常用镜像源
    echo -e "${BLUE}测试Docker镜像源连接...${NC}"
    mirror_sources=(
        "https://registry.cn-hangzhou.aliyuncs.com"
        "https://docker.mirrors.ustc.edu.cn"
        "https://mirror.ccs.tencentyun.com"
        "https://hub-mirror.c.163.com"
    )
    
    for mirror in "${mirror_sources[@]}"; do
        echo -e "${BLUE}测试 $mirror...${NC}"
        curl -s -o /dev/null -w "%{http_code}" -m 5 "$mirror"
        if [ $? -eq 0 ]; then
            echo -e " ${GREEN}✓ 连接成功${NC}"
        else
            echo -e " ${RED}✗ 连接失败${NC}"
        fi
    done
}

# Docker安装测试
test_docker_install() {
    echo -e "${BLUE}测试Docker安装...${NC}"
    
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓ Docker已安装${NC}"
        docker --version
        
        # 测试Docker服务状态
        echo -e "${BLUE}测试Docker服务状态...${NC}"
        if systemctl is-active docker &> /dev/null; then
            echo -e "${GREEN}✓ Docker服务正在运行${NC}"
        else
            echo -e "${YELLOW}⚠️ Docker服务未运行，尝试启动...${NC}"
            systemctl start docker || echo -e "${RED}✗ 无法启动Docker服务${NC}"
        fi
        
        # 测试Docker镜像加速配置
        echo -e "${BLUE}检查Docker镜像加速配置...${NC}"
        docker info | grep "Registry Mirrors" || echo -e "${YELLOW}⚠️ 未找到镜像加速配置${NC}"
        
        # 测试拉取镜像
        echo -e "${BLUE}测试拉取Docker镜像...${NC}"
        test_image="hello-world"
        
        if docker pull "$test_image"; then
            echo -e "${GREEN}✓ 成功拉取 $test_image 镜像${NC}"
            
            # 测试运行容器
            echo -e "${BLUE}测试运行容器...${NC}"
            if docker run --rm "$test_image"; then
                echo -e "${GREEN}✓ 成功运行容器${NC}"
            else
                echo -e "${RED}✗ 运行容器失败${NC}"
            fi
            
            # 清理测试镜像
            docker rmi "$test_image" > /dev/null 2>&1 || true
        else
            echo -e "${RED}✗ 拉取镜像失败${NC}"
        fi
    else
        echo -e "${RED}✗ Docker未安装${NC}"
        return 1
    fi
}

# Docker Compose安装测试
test_docker_compose() {
    echo -e "${BLUE}测试Docker Compose安装...${NC}"
    
    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}✓ Docker Compose已安装${NC}"
        docker-compose --version
    elif docker compose version &> /dev/null; then
        echo -e "${GREEN}✓ Docker Compose Plugin已安装${NC}"
        docker compose version
    else
        echo -e "${RED}✗ Docker Compose未安装${NC}"
        return 1
    fi
}

# 系统信息
show_system_info() {
    echo -e "${BLUE}系统信息:${NC}"
    echo -e "操作系统: $(lsb_release -d | cut -f2)"
    echo -e "内核版本: $(uname -r)"
    echo -e "架构: $(uname -m)"
    echo -e "内存: $(free -h | grep Mem | awk '{print $2}')"
    echo -e "CPU: $(nproc) 核心"
    echo ""
}

# 主函数
main() {
    # 检查root权限
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 请以root用户运行此脚本${NC}"
        exit 1
    fi
    
    # 显示系统信息
    show_system_info
    
    # 运行网络诊断
    network_diagnostics
    echo ""
    
    # 测试Docker安装
    echo -e "${BLUE}========================================${NC}"
    test_docker_install
    echo ""
    
    # 测试Docker Compose安装
    echo -e "${BLUE}========================================${NC}"
    test_docker_compose
    echo ""
    
    # 显示建议
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}测试完成!${NC}"
    echo ""
    
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓ Docker环境已准备就绪${NC}"
        echo -e "${BLUE}可以继续执行部署脚本:${NC}"
        echo -e "  ./deploy.sh"
    else
        echo -e "${RED}✗ Docker环境未就绪${NC}"
        echo -e "${YELLOW}建议:${NC}"
        echo -e "  1. 检查网络连接"
        echo -e "  2. 检查防火墙设置"
        echo -e "  3. 重新运行部署脚本: ./deploy.sh"
        echo -e "  4. 或尝试手动安装Docker"
    fi
}

# 执行主函数
main

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}测试脚本执行完成!${NC}"
echo -e "${BLUE}========================================${NC}"