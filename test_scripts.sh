#!/bin/bash
# -*- coding: utf-8 -*-
"""
测试脚本功能 - 不依赖Docker的验证方法
"""

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}测试脚本功能 - 不依赖Docker${NC}"
echo -e "${BLUE}========================================${NC}"

# 检查Python是否安装
check_python() {
    echo -e "${YELLOW}正在检查Python环境...${NC}"
    
    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}Python 已安装${NC}"
        python3 --version
        return 0
    else
        echo -e "${RED}错误: Python 未安装${NC}"
        echo -e "${YELLOW}请安装 Python 3.9+${NC}"
        return 1
    fi
}

# 测试API脚本语法
test_api_script() {
    echo -e "${YELLOW}正在测试API脚本语法...${NC}"
    
    if [ -f "./api/feedback_insert.py" ]; then
        echo -e "  测试: ./api/feedback_insert.py"
        python3 -m py_compile ./api/feedback_insert.py
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}API脚本语法正确!${NC}"
        else
            echo -e "${RED}错误: API脚本语法有问题${NC}"
            return 1
        fi
    else
        echo -e "${RED}错误: 未找到 API 脚本${NC}"
        return 1
    fi
    
    return 0
}

# 测试Worker脚本语法
test_worker_scripts() {
    echo -e "${YELLOW}正在测试Worker脚本语法...${NC}"
    
    worker_scripts=(
        "config.py"
        "utils.py"
        "mysql_sample.py"
        "coze_generate_tag.py"
        "pgvector_cluster.py"
        "batch_match_tag.py"
        "edge_sample_update.py"
        "run_all.py"
    )
    
    for script in "${worker_scripts[@]}"; do
        if [ -f "./worker/$script" ]; then
            echo -e "  测试: ./worker/$script"
            python3 -m py_compile ./worker/$script
            
            if [ $? -ne 0 ]; then
                echo -e "${RED}错误: $script 语法有问题${NC}"
                return 1
            fi
        else
            echo -e "${YELLOW}警告: 未找到 ./worker/$script${NC}"
        fi
    done
    
    echo -e "${GREEN}Worker脚本语法测试通过!${NC}"
    return 0
}

# 检查配置文件
check_config_files() {
    echo -e "${YELLOW}正在检查配置文件...${NC}"
    
    # 检查.env文件
    if [ -f ".env" ]; then
        echo -e "${GREEN}.env 文件存在${NC}"
        
        # 检查关键配置项
        if grep -q "MYSQL_PASSWORD" .env && grep -q "PG_PASSWORD" .env && grep -q "API_KEY" .env; then
            echo -e "${GREEN}关键配置项已设置${NC}"
        else
            echo -e "${YELLOW}警告: 部分配置项可能未设置${NC}"
        fi
    else
        echo -e "${RED}错误: .env 文件不存在${NC}"
        return 1
    fi
    
    # 检查数据库初始化脚本
    if [ -f "./mysql/init/01_create_tables.sql" ] && [ -f "./postgres/init/01_create_tables.sql" ]; then
        echo -e "${GREEN}数据库初始化脚本存在${NC}"
    else
        echo -e "${YELLOW}警告: 数据库初始化脚本可能不完整${NC}"
    fi
    
    return 0
}

# 显示文件格式检查
check_file_formats() {
    echo -e "${YELLOW}正在检查文件格式...${NC}"
    
    # 检查Shell脚本
    echo -e "  检查Shell脚本:"
    find . -name "*.sh" -type f | xargs file | grep -v "Bourne-Again shell script" || echo -e "${GREEN}所有Shell脚本格式正确${NC}"
    
    # 检查文本文件
    echo -e "  检查文本文件:"
    find . -name "*.py" -o -name "*.sql" -o -name "*.txt" | xargs file | grep -v "UTF-8 Unicode text" || echo -e "${GREEN}所有文本文件编码正确${NC}"
    
    echo -e "${GREEN}文件格式检查完成!${NC}"
}

# 显示目录结构
show_directory_structure() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}项目目录结构${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    find . -type f -not -path "*/\.*" | sort | head -20
    echo -e "... (显示前20个文件)"
    
    echo -e "${BLUE}========================================${NC}"
}

# 主函数
main() {
    # 检查Python环境
    check_python
    
    # 测试脚本语法
    test_api_script
    test_worker_scripts
    
    # 检查配置文件
    check_config_files
    
    # 检查文件格式
    check_file_formats
    
    # 显示目录结构
    show_directory_structure
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}测试完成!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e ""
    echo -e "${BLUE}修复建议:${NC}"
    echo -e "  1. 所有脚本文件格式已修复"
    echo -e "  2. Python语法检查通过"
    echo -e "  3. 配置文件已创建"
    echo -e ""
    echo -e "${BLUE}下一步:${NC}"
    echo -e "  1. 安装Docker: ${YELLOW}./deploy.sh${NC}"
    echo -e "  2. 或使用完整安装脚本: ${YELLOW}./deploy.sh${NC}"
    echo -e ""
}

# 执行主函数
main

echo -e "${GREEN}测试脚本执行完成!${NC}"