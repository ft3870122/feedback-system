#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
批量标签匹配模块
"""

import numpy as np
from typing import List, Tuple, Dict, Any
from sentence_transformers import SentenceTransformer
from config import MYSQL_CONFIG, PGVECTOR_CONFIG, VECTOR_CONFIG, BATCH_CONFIG
from utils import setup_logger, get_mysql_connection, get_postgres_connection, format_time, print_progress
from concurrent.futures import ThreadPoolExecutor, as_completed

logger = setup_logger("batch_match_tag")

def get_all_feedback_from_mysql(batch_size: int = 1000) -> List[Tuple[int, str]]:
    """
    从MySQL获取所有反馈数据
    
    Args:
        batch_size: 批处理大小
    
    Returns:
        反馈ID和内容的列表
    """
    conn = None
    try:
        conn = get_mysql_connection(MYSQL_CONFIG)
        cursor = conn.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM raw_feedback;")
        total = cursor.fetchone()[0]
        logger.info(f"总反馈数据量: {total}")
        
        all_feedback = []
        offset = 0
        
        while offset < total:
            cursor.execute(f"""
                SELECT id, content FROM raw_feedback 
                ORDER BY id 
                LIMIT {batch_size} OFFSET {offset};
            """)
            batch_data = cursor.fetchall()
            all_feedback.extend(batch_data)
            
            offset += len(batch_data)
            print_progress(offset, total, "加载反馈数据:")
            
            if len(batch_data) < batch_size:
                break
        
        logger.info(f"成功加载 {len(all_feedback)} 条反馈数据")
        return all_feedback
        
    except Exception as e:
        logger.error(f"获取反馈数据失败: {str(e)}")
        raise
    finally:
        if conn:
            conn.close()

def save_feedback_vectors_to_pg(feedback_data: List[Tuple[int, str, str]]):
    """
    保存反馈向量到PostgreSQL
    
    Args:
        feedback_data: (feedback_id, content_clean, vector_json) 元组列表
    """
    if not feedback_data:
        return
    
    pg_conn = None
    try:
        pg_conn = get_postgres_connection(PGVECTOR_CONFIG)
        pg_cursor = pg_conn.cursor()
        
        pg_cursor.executemany("""
            INSERT INTO feedback_vector (feedback_id, content_clean, text_vector)
            VALUES (%s, %s, %s)
            ON CONFLICT (feedback_id) DO UPDATE
            SET content_clean = EXCLUDED.content_clean,
                text_vector = EXCLUDED.text_vector;
        """, feedback_data)
        
        pg_conn.commit()
        logger.info(f"成功保存 {len(feedback_data)} 条反馈向量到PostgreSQL")
        
    except Exception as e:
        if pg_conn:
            pg_conn.rollback()
        logger.error(f"保存反馈向量失败: {str(e)}")
        raise
    finally:
        if pg_conn:
            pg_conn.close()

def generate_feedback_vectors(feedback_list: List[Tuple[int, str]], batch_size: int = 500):
    """
    生成反馈向量
    
    Args:
        feedback_list: 反馈ID和内容列表
        batch_size: 批处理大小
    
    Returns:
        包含向量的反馈数据列表
    """
    if not feedback_list:
        return []
    
    logger.info(f"开始生成反馈向量，共 {len(feedback_list)} 条数据")
    
    # 加载向量模型
    embed_model = SentenceTransformer(VECTOR_CONFIG["model_name"])
    logger.info(f"成功加载向量模型: {VECTOR_CONFIG['model_name']}")
    
    result_data = []
    total = len(feedback_list)
    
    for i in range(0, total, batch_size):
        batch = feedback_list[i:i + batch_size]
        contents = [content for _, content in batch]
        
        # 生成向量
        vectors = embed_model.encode(contents)
        
        for (feedback_id, content), vector in zip(batch, vectors):
            # 清洗内容
            content_clean = content.strip().replace("\n", "").replace("\r", "")
            result_data.append((feedback_id, content_clean, vector.tolist()))
        
        print_progress(i + len(batch), total, "生成向量:")
    
    logger.info(f"向量生成完成，共 {len(result_data)} 条")
    return result_data

def get_tag_vectors_from_pg() -> Tuple[List[int], List[str], np.ndarray]:
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
            WHERE tag_type IN ('initial', 'iter') 
            ORDER BY id;
        """)
        tag_data = pg_cursor.fetchall()
        
        if not tag_data:
            logger.warning("没有找到标签向量数据")
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

def match_feedback_to_tags(feedback_vectors: List[Tuple[int, str, np.ndarray]], 
                          tag_vectors: np.ndarray, 
                          tag_ids: List[int], 
                          tags: List[str],
                          threshold: float = 0.6) -> Tuple[List[Tuple[int, int, float]], List[int]]:
    """
    匹配反馈到标签
    
    Args:
        feedback_vectors: 反馈向量列表
        tag_vectors: 标签向量数组
        tag_ids: 标签ID列表
        tags: 标签列表
        threshold: 相似度阈值
    
    Returns:
        (匹配结果, 边缘样本ID列表) 元组
    """
    if not feedback_vectors or len(tag_vectors) == 0:
        return [], []
    
    logger.info(f"开始匹配反馈到标签，共 {len(feedback_vectors)} 条反馈")
    
    # 归一化标签向量
    tag_vectors_norm = tag_vectors / np.linalg.norm(tag_vectors, axis=1)[:, np.newaxis]
    
    match_results = []
    edge_samples = []
    total = len(feedback_vectors)
    
    for i, (feedback_id, content_clean, text_vector) in enumerate(feedback_vectors):
        # 归一化文本向量
        text_vector_norm = text_vector / np.linalg.norm(text_vector)
        
        # 计算相似度
        similarities = np.dot(text_vector_norm, tag_vectors_norm.T)
        max_similarity = np.max(similarities)
        max_tag_idx = np.argmax(similarities)
        
        if max_similarity >= threshold:
            match_results.append((feedback_id, tag_ids[max_tag_idx], float(max_similarity)))
        else:
            edge_samples.append(feedback_id)
        
        print_progress(i + 1, total, "匹配进度:")
    
    logger.info(f"匹配完成，成功匹配 {len(match_results)} 条，边缘样本 {len(edge_samples)} 条")
    return match_results, edge_samples

def update_match_results(match_results: List[Tuple[int, int, float]], tags: List[str], tag_ids: List[int]):
    """
    更新匹配结果到数据库
    
    Args:
        match_results: 匹配结果列表
        tags: 标签列表
        tag_ids: 标签ID列表
    """
    if not match_results:
        return
    
    # 创建标签ID到标签的映射
    tag_map = dict(zip(tag_ids, tags))
    
    pg_conn = None
    mysql_conn = None
    
    try:
        # 更新PostgreSQL
        pg_conn = get_postgres_connection(PGVECTOR_CONFIG)
        pg_cursor = pg_conn.cursor()
        
        pg_update_data = [(tag_id, similarity, feedback_id) 
                         for feedback_id, tag_id, similarity in match_results]
        
        pg_cursor.executemany("""
            UPDATE feedback_vector 
            SET match_tag_id = %s, similarity = %s 
            WHERE feedback_id = %s;
        """, pg_update_data)
        
        pg_conn.commit()
        
        # 更新MySQL
        mysql_conn = get_mysql_connection(MYSQL_CONFIG)
        mysql_cursor = mysql_conn.cursor()
        
        mysql_update_data = []
        for feedback_id, tag_id, similarity in match_results:
            tag = tag_map.get(tag_id, "未知-未知-未知")
            mysql_update_data.append((tag, 1, feedback_id))  # 1表示匹配成功
        
        mysql_cursor.executemany("""
            UPDATE raw_feedback 
            SET tag = %s, match_status = %s 
            WHERE id = %s;
        """, mysql_update_data)
        
        mysql_conn.commit()
        
        logger.info(f"成功更新 {len(match_results)} 条匹配结果")
        
    except Exception as e:
        if pg_conn:
            pg_conn.rollback()
        if mysql_conn:
            mysql_conn.rollback()
        logger.error(f"更新匹配结果失败: {str(e)}")
        raise
    finally:
        if pg_conn:
            pg_conn.close()
        if mysql_conn:
            mysql_conn.close()

def save_edge_samples(edge_sample_ids: List[int]):
    """
    保存边缘样本
    
    Args:
        edge_sample_ids: 边缘样本ID列表
    """
    if not edge_sample_ids:
        return
    
    mysql_conn = None
    try:
        mysql_conn = get_mysql_connection(MYSQL_CONFIG)
        mysql_cursor = mysql_conn.cursor()
        
        # 更新匹配状态为边缘样本
        edge_update_data = [(2, feedback_id) for feedback_id in edge_sample_ids]  # 2表示边缘样本
        mysql_cursor.executemany("""
            UPDATE raw_feedback 
            SET match_status = %s 
            WHERE id = %s;
        """, edge_update_data)
        
        # 插入边缘样本表
        edge_insert_data = []
        for feedback_id in edge_sample_ids:
            mysql_cursor.execute("""
                SELECT content FROM raw_feedback WHERE id = %s;
            """, (feedback_id,))
            result = mysql_cursor.fetchone()
            if result:
                content = result[0]
                content_clean = content.strip().replace("\n", "").replace("\r", "")
                edge_insert_data.append((feedback_id, content_clean))
        
        if edge_insert_data:
            mysql_cursor.executemany("""
                INSERT INTO edge_feedback (feedback_id, content_clean)
                VALUES (%s, %s)
                ON DUPLICATE KEY UPDATE content_clean = VALUES(content_clean);
            """, edge_insert_data)
        
        mysql_conn.commit()
        logger.info(f"成功保存 {len(edge_sample_ids)} 条边缘样本")
        
    except Exception as e:
        if mysql_conn:
            mysql_conn.rollback()
        logger.error(f"保存边缘样本失败: {str(e)}")
        raise
    finally:
        if mysql_conn:
            mysql_conn.close()

def batch_match_tag():
    """
    批量匹配标签主函数
    """
    logger.info("=== 开始批量标签匹配流程 ===")
    
    try:
        # 步骤1: 获取所有反馈数据
        feedback_list = get_all_feedback_from_mysql(batch_size=BATCH_CONFIG["batch_size"])
        
        if not feedback_list:
            logger.warning("没有反馈数据，跳过匹配")
            return
        
        # 步骤2: 生成反馈向量并保存到PostgreSQL
        feedback_vectors_data = generate_feedback_vectors(
            feedback_list, 
            batch_size=BATCH_CONFIG["batch_size"]
        )
        save_feedback_vectors_to_pg(feedback_vectors_data)
        
        # 步骤3: 获取标签向量
        tag_ids, tags, tag_vectors = get_tag_vectors_from_pg()
        
        if len(tag_vectors) == 0:
            logger.error("没有标签向量，无法进行匹配")
            return
        
        # 步骤4: 匹配反馈到标签
        feedback_vectors_for_match = [
            (feedback_id, content_clean, np.array(vector))
            for feedback_id, content_clean, vector in feedback_vectors_data
        ]
        
        match_results, edge_samples = match_feedback_to_tags(
            feedback_vectors_for_match,
            tag_vectors,
            tag_ids,
            tags,
            threshold=VECTOR_CONFIG["similarity_threshold"]
        )
        
        # 步骤5: 更新匹配结果
        update_match_results(match_results, tags, tag_ids)
        
        # 步骤6: 保存边缘样本
        save_edge_samples(edge_samples)
        
        logger.info("=== 批量标签匹配流程完成 ===")
        
    except Exception as e:
        logger.error(f"批量标签匹配流程失败: {str(e)}")
        raise

if __name__ == "__main__":
    try:
        batch_match_tag()
    except Exception as e:
        logger.error(f"执行失败: {str(e)}")
        exit(1)