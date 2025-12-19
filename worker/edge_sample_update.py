#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
边缘样本更新模块
"""

import random
import numpy as np
from typing import List
from sentence_transformers import SentenceTransformer
from config import MYSQL_CONFIG, PGVECTOR_CONFIG, VECTOR_CONFIG, SAMPLE_CONFIG
from utils import setup_logger, get_mysql_connection, get_postgres_connection, format_time
from coze_generate_tag import coze_generate_single_tag

logger = setup_logger("edge_sample_update")

def get_edge_samples(sample_rate: float = None) -> List[tuple]:
    """
    获取边缘样本
    
    Args:
        sample_rate: 抽样比例
    
    Returns:
        边缘样本列表
    """
    if sample_rate is None:
        sample_rate = SAMPLE_CONFIG["edge_sample_rate"]
    
    conn = None
    try:
        conn = get_mysql_connection(MYSQL_CONFIG)
        cursor = conn.cursor()
        
        cursor.execute("SELECT id, content_clean FROM edge_feedback WHERE new_tag IS NULL;")
        edge_samples = cursor.fetchall()
        
        if not edge_samples:
            logger.info("没有需要处理的边缘样本")
            return []
        
        logger.info(f"发现 {len(edge_samples)} 个未处理的边缘样本")
        
        # 抽样
        sample_num = max(1, int(len(edge_samples) * sample_rate))
        sample_indices = random.sample(range(len(edge_samples)), sample_num)
        sample_edge_samples = [edge_samples[i] for i in sample_indices]
        
        logger.info(f"抽取 {len(sample_edge_samples)} 个边缘样本进行处理")
        
        return sample_edge_samples
        
    except Exception as e:
        logger.error(f"获取边缘样本失败: {str(e)}")
        raise
    finally:
        if conn:
            conn.close()

def generate_edge_sample_tags(edge_samples: List[tuple]) -> List[str]:
    """
    为边缘样本生成标签
    
    Args:
        edge_samples: 边缘样本列表
    
    Returns:
        生成的标签列表
    """
    if not edge_samples:
        return []
    
    logger.info(f"开始为 {len(edge_samples)} 个边缘样本生成标签")
    
    update_data = []
    new_tags = []
    
    for eid, content_clean in edge_samples:
        logger.info(f"处理边缘样本ID: {eid}")
        tag = coze_generate_single_tag(content_clean)
        update_data.append((tag, eid))
        new_tags.append(tag)
        
        # 每5个样本打印一次进度
        if len(update_data) % 5 == 0:
            logger.info(f"已处理 {len(update_data)} 个边缘样本")
    
    # 更新MySQL
    conn = None
    try:
        conn = get_mysql_connection(MYSQL_CONFIG)
        cursor = conn.cursor()
        
        cursor.executemany("""
            UPDATE edge_feedback SET new_tag = %s WHERE id = %s;
        """, update_data)
        
        conn.commit()
        logger.info(f"成功更新 {len(update_data)} 个边缘样本的标签")
        
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f"更新边缘样本标签失败: {str(e)}")
        raise
    finally:
        if conn:
            conn.close()
    
    return new_tags

def update_tag_library(new_tags: List[str]):
    """
    更新标签库
    
    Args:
        new_tags: 新标签列表
    """
    if not new_tags:
        logger.info("没有新标签需要更新到标签库")
        return
    
    # 过滤重复标签
    unique_tags = list(set(new_tags))
    logger.info(f"去重后剩余 {len(unique_tags)} 个新标签")
    
    if not unique_tags:
        return
    
    # 加载向量模型
    embed_model = SentenceTransformer(VECTOR_CONFIG["model_name"])
    logger.info(f"成功加载向量模型: {VECTOR_CONFIG['model_name']}")
    
    # 生成向量
    tag_vectors = embed_model.encode(unique_tags)
    logger.info(f"成功生成 {len(tag_vectors)} 个标签向量")
    
    # 保存到PostgreSQL
    pg_conn = None
    try:
        pg_conn = get_postgres_connection(PGVECTOR_CONFIG)
        pg_cursor = pg_conn.cursor()
        
        # 检查是否已存在相同标签
        existing_tags = set()
        pg_cursor.execute("SELECT tag FROM tag_vector;")
        for (tag,) in pg_cursor.fetchall():
            existing_tags.add(tag)
        
        # 过滤已存在的标签
        new_unique_tags = []
        new_unique_vectors = []
        
        for tag, vec in zip(unique_tags, tag_vectors):
            if tag not in existing_tags:
                new_unique_tags.append(tag)
                new_unique_vectors.append(vec.tolist())
        
        logger.info(f"新增 {len(new_unique_tags)} 个标签到标签库")
        
        if new_unique_tags:
            batch_data = list(zip(new_unique_tags, new_unique_vectors))
            pg_cursor.executemany("""
                INSERT INTO tag_vector (tag, tag_vector, tag_type)
                VALUES (%s, %s, 'iter')
                ON CONFLICT (tag) DO NOTHING;
            """, batch_data)
            
            pg_conn.commit()
            logger.info(f"成功将 {len(batch_data)} 个新标签添加到向量数据库")
        
    except Exception as e:
        if pg_conn:
            pg_conn.rollback()
        logger.error(f"更新标签库失败: {str(e)}")
        raise
    finally:
        if pg_conn:
            pg_conn.close()

def edge_sample_update():
    """
    边缘样本更新主函数
    """
    logger.info("=== 开始边缘样本更新流程 ===")
    
    try:
        # 获取边缘样本
        edge_samples = get_edge_samples()
        
        if not edge_samples:
            logger.info("没有边缘样本需要处理")
            return
        
        # 生成标签
        new_tags = generate_edge_sample_tags(edge_samples)
        
        # 更新标签库
        if new_tags:
            update_tag_library(new_tags)
        else:
            logger.info("没有生成新标签，跳过标签库更新")
        
        logger.info("=== 边缘样本更新流程完成 ===")
        
    except Exception as e:
        logger.error(f"边缘样本更新流程失败: {str(e)}")
        raise

if __name__ == "__main__":
    try:
        edge_sample_update()
    except Exception as e:
        logger.error(f"执行失败: {str(e)}")
        exit(1)