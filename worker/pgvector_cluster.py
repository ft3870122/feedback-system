#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PostgreSQL向量聚类模块
"""

import numpy as np
from typing import List, Tuple
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score
from config import PGVECTOR_CONFIG, VECTOR_CONFIG
from utils import setup_logger, get_postgres_connection, get_optimal_clusters, format_time

logger = setup_logger("pgvector_cluster")

def get_tag_vectors() -> Tuple[List[int], List[str], np.ndarray]:
    """
    从PostgreSQL获取标签向量
    
    Returns:
        (tag_ids, tags, vectors) 元组
    """
    pg_conn = None
    try:
        pg_conn = get_postgres_connection(PGVECTOR_CONFIG)
        pg_cursor = pg_conn.cursor()
        
        pg_cursor.execute("""
            SELECT id, tag, tag_vector 
            FROM tag_vector 
            WHERE tag_type = 'initial' 
            ORDER BY id;
        """)
        tag_data = pg_cursor.fetchall()
        
        if not tag_data:
            logger.warning("没有找到初始标签数据")
            return [], [], np.array([])
        
        tag_ids = [item[0] for item in tag_data]
        tags = [item[1] for item in tag_data]
        vectors = np.array([item[2] for item in tag_data])
        
        logger.info(f"成功加载 {len(tags)} 个标签向量")
        
        return tag_ids, tags, vectors
        
    except Exception as e:
        logger.error(f"获取标签向量失败: {str(e)}")
        raise
    finally:
        if pg_conn:
            pg_conn.close()

def cluster_tags(vectors: np.ndarray, max_clusters: int = 20) -> np.ndarray:
    """
    对标签向量进行聚类
    
    Args:
        vectors: 标签向量数组
        max_clusters: 最大聚类数量
    
    Returns:
        聚类ID数组
    """
    if len(vectors) == 0:
        logger.warning("没有向量需要聚类")
        return np.array([])
    
    if len(vectors) == 1:
        logger.info("只有一个向量，无需聚类")
        return np.array([0])
    
    # 获取最优聚类数量
    optimal_k = get_optimal_clusters(vectors, max_clusters)
    logger.info(f"最优聚类数量: {optimal_k}")
    
    # 执行K-means聚类
    kmeans = KMeans(
        n_clusters=optimal_k,
        random_state=42,
        n_init=10,
        max_iter=300
    )
    
    cluster_labels = kmeans.fit_predict(vectors)
    
    # 计算轮廓系数
    if len(vectors) > optimal_k:
        silhouette_avg = silhouette_score(vectors, cluster_labels)
        logger.info(f"聚类轮廓系数: {silhouette_avg:.4f}")
    
    return cluster_labels

def update_cluster_ids(tag_ids: List[int], cluster_labels: np.ndarray):
    """
    更新标签的聚类ID
    
    Args:
        tag_ids: 标签ID列表
        cluster_labels: 聚类标签数组
    """
    if not tag_ids or len(tag_ids) != len(cluster_labels):
        logger.error("标签ID和聚类标签数量不匹配")
        return
    
    pg_conn = None
    try:
        pg_conn = get_postgres_connection(PGVECTOR_CONFIG)
        pg_cursor = pg_conn.cursor()
        
        update_data = list(zip(cluster_labels, tag_ids))
        
        pg_cursor.executemany("""
            UPDATE tag_vector 
            SET cluster_id = %s 
            WHERE id = %s;
        """, update_data)
        
        pg_conn.commit()
        logger.info(f"成功更新 {len(update_data)} 个标签的聚类ID")
        
    except Exception as e:
        if pg_conn:
            pg_conn.rollback()
        logger.error(f"更新聚类ID失败: {str(e)}")
        raise
    finally:
        if pg_conn:
            pg_conn.close()

def analyze_clusters(tag_ids: List[int], tags: List[str], cluster_labels: np.ndarray):
    """
    分析聚类结果
    
    Args:
        tag_ids: 标签ID列表
        tags: 标签列表
        cluster_labels: 聚类标签数组
    """
    if not tags or len(tags) != len(cluster_labels):
        return
    
    cluster_info = {}
    for tag_id, tag, cluster_id in zip(tag_ids, tags, cluster_labels):
        if cluster_id not in cluster_info:
            cluster_info[cluster_id] = []
        cluster_info[cluster_id].append((tag_id, tag))
    
    logger.info(f"聚类分析结果:")
    for cluster_id, cluster_tags in cluster_info.items():
        logger.info(f"  聚类 {cluster_id}: {len(cluster_tags)} 个标签")
        for tag_id, tag in cluster_tags[:3]:  # 只显示前3个标签
            logger.info(f"    - {tag} (ID: {tag_id})")
        if len(cluster_tags) > 3:
            logger.info(f"    ... 还有 {len(cluster_tags) - 3} 个标签")

def tag_cluster():
    """
    标签聚类主函数
    """
    logger.info("=== 开始标签聚类流程 ===")
    
    try:
        # 获取标签向量
        tag_ids, tags, vectors = get_tag_vectors()
        
        if len(vectors) == 0:
            logger.warning("没有标签向量，跳过聚类")
            return
        
        # 执行聚类
        cluster_labels = cluster_tags(vectors)
        
        if len(cluster_labels) == 0:
            logger.warning("聚类失败，没有生成聚类标签")
            return
        
        # 更新聚类ID
        update_cluster_ids(tag_ids, cluster_labels)
        
        # 分析聚类结果
        analyze_clusters(tag_ids, tags, cluster_labels)
        
        logger.info("=== 标签聚类流程完成 ===")
        
    except Exception as e:
        logger.error(f"标签聚类流程失败: {str(e)}")
        raise

if __name__ == "__main__":
    try:
        tag_cluster()
    except Exception as e:
        logger.error(f"执行失败: {str(e)}")
        exit(1)