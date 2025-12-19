#!/bin/bash
# -*- coding: utf-8 -*-
"""
Docker Compose 权限修复脚本
用于修复 "Permission denied" 错误
"""

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Docker Compose 权限修复脚本${NC}"
echo -e "${BLUE}========================================${NC}"

# 检查root权限
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}错误: 请以root用户运行此脚本${NC}"
   exit 1
fi

# 清理现有文件
echo -e "${BLUE}清理可能存在的损坏文件...${NC}"
rm -f /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true

# 检查目录权限
echo -e "${BLUE}检查目录权限...${NC}"
if [ ! -w "/usr/local/bin" ]; then
    echo -e "${RED}错误: /usr/local/bin 目录没有写权限${NC}"
    echo -e "${YELLOW}正在修复目录权限...${NC}"
    chmod 755 /usr/local/bin || {
        echo -e "${RED}无法修复 /usr/local/bin 目录权限${NC}"
        exit 1
    }
fi

if [ ! -w "/usr/bin" ]; then
    echo -e "${RED}错误: /usr/bin 目录没有写权限${NC}"
    echo -e "${YELLOW}正在修复目录权限...${NC}"
    chmod 755 /usr/bin || {
        echo -e "${RED}无法修复 /usr/bin 目录权限${NC}"
        exit 1
    }
fi

echo -e "${GREEN}✓ 目录权限正常${NC}"

# 下载并安装Docker Compose
echo -e "${BLUE}下载Docker Compose二进制文件...${NC}"

# 下载到临时目录避免权限问题
DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-Linux-x86_64"

if curl -L --connect-timeout 30 --retry 3 "$DOCKER_COMPOSE_URL" -o /tmp/docker-compose; then
    echo -e "${GREEN}✓ 下载成功${NC}"
    
    # 修复权限
    echo -e "${BLUE}修复文件权限...${NC}"
    chmod 755 /tmp/docker-compose
    
    # 移动文件
    echo -e "${BLUE}移动文件到目标位置...${NC}"
    mv -f /tmp/docker-compose /usr/local/bin/docker-compose
    
    # 再次确保权限正确
    chmod 755 /usr/local/bin/docker-compose
    
    # 创建软链接
    echo -e "${BLUE}创建软链接...${NC}"
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
    chmod 755 /usr/bin/docker-compose 2>/dev/null || true
    
    # 验证安装
    echo -e "${BLUE}验证安装...${NC}"
    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}✓ Docker Compose 安装成功!${NC}"
        docker-compose --version
        
        # 显示详细信息
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}安装信息:${NC}"
        echo -e "文件位置: $(which docker-compose)"
        echo -e "文件权限: $(ls -la $(which docker-compose))"
        echo -e "版本信息: $(docker-compose --version)"
        echo -e "${BLUE}========================================${NC}"
        
    else
        echo -e "${RED}✗ Docker Compose 安装失败${NC}"
        echo -e "${YELLOW}尝试直接运行...${NC}"
        if /usr/local/bin/docker-compose --version; then
            echo -e "${GREEN}✓ 直接运行成功，但命令不在PATH中${NC}"
            echo -e "${YELLOW}建议将 /usr/local/bin 添加到PATH中${NC}"
        else
            echo -e "${RED}✗ 直接运行也失败${NC}"
        fi
    fi
else
    echo -e "${RED}✗ 下载失败${NC}"
    echo -e "${YELLOW}建议手动下载:${NC}"
    echo -e "wget $DOCKER_COMPOSE_URL -O /tmp/docker-compose"
    echo -e "chmod +x /tmp/docker-compose"
    echo -e "mv /tmp/docker-compose /usr/local/bin/docker-compose"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}修复脚本执行完成!${NC}"
echo -e "${BLUE}========================================${NC}"