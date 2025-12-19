#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Coze标签生成模块
"""

import requests
import json
from typing import Optional, List, Dict, Any
from config import COZE_CONFIG, MYSQL_CONFIG, PGVECTOR_CONFIG, VECTOR_CONFIG
from utils import setup_logger, get_mysql_connection, get_postgres_connection, format_time

logger = setup_logger("coze_generate_tag")

def coze_generate_single_tag(content: str) -> str:
    """
    调用Coze生成单个标签
    
    Args:
        content: 反馈内容
    
    Returns:
        生成的标签
    """
    if not content:
        logger.warning("内容为空，跳过标签生成")
        return "未知-未知-未知"
    
    if not COZE_CONFIG["api_key"] or not COZE_CONFIG["app_id"]:
        logger.error("Coze API配置不完整")
        return "未知-未知-未知"
    
    headers = {
        "Authorization": f"Bearer {COZE_CONFIG['api_key']}",
        "Content-Type": "application/json"
    }
    
    data = {
        "app_id": COZE_CONFIG["app_id"],
        "user_id": "cloud_tag_generator",
        "stream": False,
        "messages": [
            {
                "role": "user",
                "content": content
            }
        ]
    }
    
    try:
        response = requests.post(
            COZE_CONFIG["url"], 
            headers=headers, 
            json=data, 
            timeout=30
        )
        response.raise_for_status()
        
        result = response.json()
        
        if result.get("code") != 0:
            logger.error(f"Coze API返回错误: {result.get('msg')}")
            return "未知-未知-未知"
        
        tag = result["choices"][0]["message"]["content"].strip()
        
        # 验证标签格式
        if "-" not in tag:
            logger.warning(f"标签格式异常: {tag}")
            tag = f"未知-{tag}-未知"
        
        logger.info(f"成功生成标签: {tag}")
        return tag
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Coze API请求失败: {str(e)}")
        return "未知-未知-未知"
    except Exception as e:
        logger.error(f"标签生成失败: {str(e)}")
        return "未知-未知-未知"

def batch_generate_sample_tag() -> List[str]:
    """
    批量生成样本标签并更新MySQL
    
    Returns:
        生成的标签列表
    """
    logger.info("开始批量生成样本标签")
    
    # 从MySQL读取样本数据
    mysql_conn = None
    try:
        mysql_conn = get_mysql_connection(MYSQL_CONFIG)
        mysql_cursor = mysql_conn.cursor()
        
        mysql_cursor.execute("""
            SELECT id, content_clean FROM sample_feedback 
            WHERE gen_tag IS NULL OR gen_tag = '未知-未知-未知';
        """)
        samples = mysql_cursor.fetchall()
        
        if not samples:
            logger.info("没有需要生成标签的样本")
            return []
        
        logger.info(f"发现 {len(samples)} 个样本需要生成标签")
        
        update_data = []
        generated_tags = []
        
        for sid, content in samples:
            logger.info(f"处理样本ID: {sid}")
            tag = coze_generate_single_tag(content)
            update_data.append((tag, sid))
            generated_tags.append(tag)
            
            # 每10个样本提交一次事务
            if len(update_data) % 10 == 0:
                mysql_cursor.executemany("""
                    UPDATE sample_feedback SET gen_tag = %s WHERE id = %s;
                """, update_data)
                mysql_conn.commit()
                logger.info(f"已更新 {len(update_data)} 个样本标签")
                update_data = []
        
        # 处理剩余的更新
        if update_data:
            mysql_cursor.executemany("""
                UPDATE sample_feedback SET gen_tag = %s WHERE id = %s;
            """, update_data)
            mysql_conn.commit()
            logger.info(f"已更新 {len(update_data)} 个样本标签")
        
        logger.info(f"样本标签生成完成，共处理 {len(generated_tags)} 个样本")
        
        # 过滤无效标签
        valid_tags = [tag for tag in generated_tags if tag != "未知-未知-未知"]
        logger.info(f"有效标签数量: {len(valid_tags)}")
        
        return valid_tags
        
    except Exception as e:
        if mysql_conn:
            mysql_conn.rollback()
        logger.error(f"批量生成标签失败: {str(e)}")
        raise
    finally:
        if mysql_conn:
            mysql_conn.close()

def save_tags_to_pgvector(tags: List[str]):
    """
    将生成的标签保存到PostgreSQL向量数据库
    
    Args:
        tags: 标签列表
    """
    if not tags:
        logger.info("没有标签需要保存到向量数据库")
        return
    
    logger.info(f"准备将 {len(tags)} 个标签保存到PostgreSQL向量数据库")
    
    # 导入向量模型
    from sentence_transformers import SentenceTransformer
    
    try:
        # 加载向量模型
        embed_model = SentenceTransformer(VECTOR_CONFIG["model_name"])
        logger.info(f"成功加载向量模型: {VECTOR_CONFIG['model_name']}")
        
        # 生成向量
        tag_vectors = embed_model.encode(tags)
        logger.info(f"成功生成 {len(tag_vectors)} 个标签向量")
        
        # 保存到PostgreSQL
        pg_conn = get_postgres_connection(PGVECTOR_CONFIG)
        pg_cursor = pg_conn.cursor()
        
        # 清空初始标签
        pg_cursor.execute("DELETE FROM tag_vector WHERE tag_type = 'initial';")
        logger.info("已清空初始标签表")
        
        # 批量插入
        batch_data = []
        for tag, vec in zip(tags, tag_vectors):
            batch_data.append((tag, vec.tolist(), "initial"))
        
        pg_cursor.executemany("""
            INSERT INTO tag_vector (tag, tag_vector, tag_type)
            VALUES (%s, %s, %s);
        """, batch_data)
        
        pg_conn.commit()
        logger.info(f"成功将 {len(batch_data)} 个标签向量保存到PostgreSQL")
        
    except Exception as e:
        logger.error(f"保存标签向量失败: {str(e)}")
        if 'pg_conn' in locals():
            pg_conn.rollback()
        raise
    finally:
        if 'pg_conn' in locals():
            pg_cursor.close()
            pg_conn.close()

def generate_and_save_tags():
    """
    生成标签并保存到向量数据库的完整流程
    """
    logger.info("=== 开始标签生成和保存流程 ===")
    
    try:
        # 生成标签
        tags = batch_generate_sample_tag()
        
        # 保存到向量数据库
        if tags:
            save_tags_to_pgvector(tags)
        else:
            logger.info("没有生成有效标签，跳过保存步骤")
        
        logger.info("=== 标签生成和保存流程完成 ===")
        
    except Exception as e:
        logger.error(f"标签生成和保存流程失败: {str(e)}")
        raise

if __name__ == "__main__":
    try:
        generate_and_save_tags()
    except Exception as e:
        logger.error(f"执行失败: {str(e)}")
        exit(1)