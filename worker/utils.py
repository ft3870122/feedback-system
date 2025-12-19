#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
通用工具函数
"""

import os
import sys
import logging
import re
import json
from datetime import datetime
from typing import List, Dict, Any, Optional
import pymysql
import psycopg2
import numpy as np

from config import LOG_CONFIG

def setup_logger(logger_name: str) -> logging.Logger:
    """设置日志配置"""
    logger = logging.getLogger(logger_name)
    logger.setLevel(getattr(logging, LOG_CONFIG["log_level"]))
    
    # 创建日志目录
    os.makedirs(LOG_CONFIG["log_dir"], exist_ok=True)
    
    # 创建文件处理器
    log_file = os.path.join(
        LOG_CONFIG["log_dir"], 
        f"{logger_name}_{datetime.now().strftime('%Y%m%d')}.log"
    )
    file_handler = logging.FileHandler(log_file)
    file_handler.setLevel(getattr(logging, LOG_CONFIG["log_level"]))
    
    # 创建控制台处理器
    console_handler = logging.StreamHandler()
    console_handler.setLevel(getattr(logging, LOG_CONFIG["log_level"]))
    
    # 设置日志格式
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    file_handler.setFormatter(formatter)
    console_handler.setFormatter(formatter)
    
    # 添加处理器
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    return logger

def clean_content(content: str) -> str:
    """清洗反馈文本"""
    if not content:
        return ""
    content = content.strip().replace("\n", "").replace("\r", "")
    content = re.sub(r"1[3-9]\d{9}", "1**********", content)
    return content

def get_mysql_connection(mysql_config: Dict[str, Any]):
    """获取MySQL连接"""
    try:
        conn = pymysql.connect(**mysql_config)
        return conn
    except Exception as e:
        raise Exception(f"MySQL连接失败: {str(e)}")

def get_postgres_connection(pg_config: Dict[str, Any]):
    """获取PostgreSQL连接"""
    try:
        conn = psycopg2.connect(**pg_config)
        return conn
    except Exception as e:
        raise Exception(f"PostgreSQL连接失败: {str(e)}")

def batch_execute_sql(cursor, sql: str, data: List[tuple], batch_size: int = 1000):
    """批量执行SQL"""
    for i in range(0, len(data), batch_size):
        batch = data[i:i + batch_size]
        cursor.executemany(sql, batch)

def save_json_file(data: Any, file_path: str):
    """保存JSON文件"""
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def load_json_file(file_path: str) -> Any:
    """加载JSON文件"""
    if not os.path.exists(file_path):
        return None
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def calculate_similarity(vec1: np.ndarray, vec2: np.ndarray) -> float:
    """计算向量相似度"""
    if len(vec1) != len(vec2):
        raise ValueError("向量维度不匹配")
    
    # 归一化
    vec1_norm = vec1 / np.linalg.norm(vec1)
    vec2_norm = vec2 / np.linalg.norm(vec2)
    
    # 计算余弦相似度
    return np.dot(vec1_norm, vec2_norm)

def get_optimal_clusters(vectors: np.ndarray, max_clusters: int = 20) -> int:
    """获取最优聚类数量"""
    if len(vectors) < 10:
        return min(2, len(vectors))
    
    from sklearn.cluster import KMeans
    from sklearn.metrics import silhouette_score
    
    max_k = min(max_clusters, len(vectors) // 5 + 1)
    if max_k <= 2:
        return 2
    
    k_candidates = range(2, max_k)
    sil_scores = []
    
    for k in k_candidates:
        try:
            kmeans = KMeans(n_clusters=k, random_state=42, n_init=10)
            labels = kmeans.fit_predict(vectors)
            score = silhouette_score(vectors, labels)
            sil_scores.append(score)
        except Exception as e:
            sil_scores.append(-1)
    
    if not sil_scores:
        return 2
    
    return k_candidates[np.argmax(sil_scores)]

def format_time(dt: datetime = None) -> str:
    """格式化时间"""
    if dt is None:
        dt = datetime.now()
    return dt.strftime("%Y-%m-%d %H:%M:%S")

def print_progress(current: int, total: int, prefix: str = ""):
    """打印进度条"""
    progress = (current / total) * 100
    sys.stdout.write(f"\r{prefix} {current}/{total} ({progress:.1f}%)")
    sys.stdout.flush()
    if current >= total:
        sys.stdout.write("\n")