#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
环境配置文件
"""

import os
from typing import Dict, Any

# MySQL配置
MYSQL_CONFIG: Dict[str, Any] = {
    "host": os.getenv("MYSQL_HOST", "mysql"),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", ""),
    "database": os.getenv("MYSQL_DATABASE", "feedback_db"),
    "charset": "utf8mb4",
    "port": int(os.getenv("MYSQL_PORT", "3306"))
}

# PostgreSQL配置
PGVECTOR_CONFIG: Dict[str, Any] = {
    "host": os.getenv("PG_HOST", "postgres"),
    "user": os.getenv("PG_USER", "postgres"),
    "password": os.getenv("PG_PASSWORD", ""),
    "database": os.getenv("PG_DATABASE", "feedback_vector"),
    "port": int(os.getenv("PG_PORT", "5432"))
}

# Coze配置
COZE_CONFIG: Dict[str, Any] = {
    "api_key": os.getenv("COZE_API_KEY", ""),
    "app_id": os.getenv("COZE_APP_ID", ""),
    "url": "https://api.coze.com/open_api/v2/chat/completions"
}

# 向量模型配置
VECTOR_CONFIG: Dict[str, Any] = {
    "model_name": "m3e-base",
    "vector_dim": 768,
    "similarity_threshold": 0.6
}

# 抽样配置
SAMPLE_CONFIG: Dict[str, Any] = {
    "sample_rate": 0.01,  # 1%
    "edge_sample_rate": 0.1  # 10%
}

# 批处理配置
BATCH_CONFIG: Dict[str, Any] = {
    "batch_size": 1000,
    "max_workers": 4
}

# 日志配置
LOG_CONFIG: Dict[str, Any] = {
    "log_dir": "/app/logs",
    "log_level": "INFO"
}