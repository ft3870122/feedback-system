#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MySQL分层抽样脚本
"""

import random
import pymysql
from typing import List
from config import MYSQL_CONFIG, SAMPLE_CONFIG
from utils import setup_logger, clean_content, get_mysql_connection, format_time

logger = setup_logger("mysql_sample")

def stratified_sample(sample_rate: float = None) -> List[int]:
    """
    分层抽样
    
    Args:
        sample_rate: 抽样比例，默认使用配置文件中的值
    
    Returns:
        抽样的反馈ID列表
    """
    if sample_rate is None:
        sample_rate = SAMPLE_CONFIG["sample_rate"]
    
    logger.info(f"开始分层抽样，抽样比例: {sample_rate:.2%}")
    
    conn = None
    try:
        conn = get_mysql_connection(MYSQL_CONFIG)
        cursor = conn.cursor()
        
        # 清空样本表
        cursor.execute("TRUNCATE TABLE sample_feedback;")
        logger.info("已清空样本表")
        
        # 获取所有产品和渠道的组合
        cursor.execute("SELECT DISTINCT product, channel FROM raw_feedback;")
        layers = cursor.fetchall()
        logger.info(f"发现 {len(layers)} 个分层组合")
        
        sample_ids = []
        
        for product, channel in layers:
            # 获取该分层的总数量
            cursor.execute("""
                SELECT COUNT(*) FROM raw_feedback 
                WHERE product = %s AND channel = %s;
            """, (product, channel))
            total = cursor.fetchone()[0]
            
            if total == 0:
                continue
            
            # 计算抽样数量
            sample_num = max(1, int(total * sample_rate))
            logger.info(f"分层 [{product}-{channel}]: 总数 {total}, 抽样 {sample_num}")
            
            # 分层抽样
            cursor.execute("""
                SELECT id FROM raw_feedback 
                WHERE product = %s AND channel = %s 
                ORDER BY RAND() LIMIT %s;
            """, (product, channel, sample_num))
            
            layer_ids = [item[0] for item in cursor.fetchall()]
            sample_ids.extend(layer_ids)
        
        logger.info(f"分层抽样完成，共抽取 {len(sample_ids)} 条样本")
        
        if sample_ids:
            # 插入样本表
            sample_ids_str = ",".join(map(str, sample_ids))
            cursor.execute(f"""
                INSERT INTO sample_feedback (feedback_id, content_clean)
                SELECT id, content FROM raw_feedback WHERE id IN ({sample_ids_str});
            """)
            
            # 清洗文本
            cursor.execute("SELECT id, content_clean FROM sample_feedback;")
            samples = cursor.fetchall()
            
            clean_data = []
            for sid, content in samples:
                clean_content_str = clean_content(content)
                clean_data.append((clean_content_str, sid))
            
            cursor.executemany("""
                UPDATE sample_feedback SET content_clean = %s WHERE id = %s;
            """, clean_data)
            
            logger.info(f"已更新 {len(clean_data)} 条清洗后的样本文本")
        
        conn.commit()
        logger.info(f"分层抽样完成，总样本数: {len(sample_ids)}")
        
        return sample_ids
        
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f"分层抽样失败: {str(e)}")
        raise
    finally:
        if conn:
            conn.close()

def random_sample(sample_size: int = 100) -> List[int]:
    """
    简单随机抽样
    
    Args:
        sample_size: 抽样数量
    
    Returns:
        抽样的反馈ID列表
    """
    logger.info(f"开始简单随机抽样，抽样数量: {sample_size}")
    
    conn = None
    try:
        conn = get_mysql_connection(MYSQL_CONFIG)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT id FROM raw_feedback 
            ORDER BY RAND() LIMIT %s;
        """, (sample_size,))
        
        sample_ids = [item[0] for item in cursor.fetchall()]
        logger.info(f"随机抽样完成，共抽取 {len(sample_ids)} 条样本")
        
        return sample_ids
        
    except Exception as e:
        logger.error(f"随机抽样失败: {str(e)}")
        raise
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    try:
        sample_ids = stratified_sample()
        logger.info(f"抽样完成，样本ID列表: {sample_ids[:10]}...")
    except Exception as e:
        logger.error(f"抽样执行失败: {str(e)}")
        exit(1)