#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
云环境 FastAPI 反馈数据插入接口
"""

from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
import pymysql
import pymysql.cursors
from datetime import datetime
import re
import os
import logging
from typing import List, Dict, Any

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("/app/logs/feedback_api.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("feedback-api")

app = FastAPI(
    title="Cloud Feedback API",
    description="标签闭环系统 - 云环境反馈数据接口",
    version="1.0.0"
)

# 配置CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 从环境变量获取数据库配置
MYSQL_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "mysql"),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", ""),
    "database": os.getenv("MYSQL_DATABASE", "feedback_db"),
    "charset": "utf8mb4",
    "port": int(os.getenv("MYSQL_PORT", "3306")),
    "cursorclass": pymysql.cursors.DictCursor
}

API_KEY = os.getenv("API_KEY", "your-secure-api-key")

def clean_content(content: str) -> str:
    """清洗反馈文本"""
    if not content:
        return ""
    content = content.strip().replace("\n", "").replace("\r", "")
    content = re.sub(r"1[3-9]\d{9}", "1**********", content)
    return content

def get_mysql_connection():
    """获取MySQL连接"""
    try:
        conn = pymysql.connect(**MYSQL_CONFIG)
        logger.info(f"成功连接到MySQL数据库: {MYSQL_CONFIG['host']}:{MYSQL_CONFIG['port']}")
        return conn
    except Exception as e:
        logger.error(f"MySQL连接失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"数据库连接失败: {str(e)}")

def batch_insert_mysql(feedback_list: List[Dict[str, Any]]) -> Dict[str, Any]:
    """批量插入MySQL"""
    conn = None
    try:
        conn = get_mysql_connection()
        cursor = conn.cursor()
        
        clean_data = []
        for item in feedback_list:
            product = item.get("product", "未知")
            content = clean_content(item.get("content", ""))
            create_time_str = item.get("create_time", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
            channel = item.get("channel", "未知")
            
            if not product or not content:
                continue
            
            try:
                create_time_dt = datetime.strptime(create_time_str, "%Y-%m-%d %H:%M:%S")
            except ValueError:
                create_time_dt = datetime.now()
            
            clean_data.append((product, content, create_time_dt, channel))
        
        if not clean_data:
            logger.warning("有效数据为空")
            raise HTTPException(status_code=400, detail="有效数据为空")
        
        sql = """
            INSERT INTO raw_feedback (product, content, create_time, channel, tag, match_status)
            VALUES (%s, %s, %s, %s, NULL, 0);
        """
        
        cursor.executemany(sql, clean_data)
        conn.commit()
        
        logger.info(f"成功插入{cursor.rowcount}条数据到MySQL")
        return {
            "success": True,
            "insert_count": cursor.rowcount,
            "msg": f"成功插入{cursor.rowcount}条数据到云MySQL"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f"数据插入失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"入库失败: {str(e)}")
    finally:
        if conn:
            conn.close()

@app.get("/health")
def health_check():
    """健康检查接口"""
    try:
        conn = get_mysql_connection()
        conn.close()
        return {"status": "healthy", "service": "feedback-api", "timestamp": datetime.now().isoformat()}
    except Exception as e:
        logger.error(f"健康检查失败: {str(e)}")
        raise HTTPException(status_code=503, detail=f"服务不可用: {str(e)}")

@app.post("/insert_feedback")
def insert_feedback(
    feedback_list: List[Dict[str, Any]],
    x_api_key: str = Header(None)
):
    """
    批量插入模拟反馈数据到云MySQL
    
    Args:
        feedback_list: 反馈数据列表
        x_api_key: API密钥
    
    Returns:
        插入结果
    """
    # API密钥验证
    if x_api_key != API_KEY:
        logger.warning(f"API密钥验证失败: {x_api_key}")
        raise HTTPException(status_code=401, detail="API密钥错误")
    
    if not feedback_list:
        raise HTTPException(status_code=400, detail="请求数据为空")
    
    if len(feedback_list) > 1000:
        raise HTTPException(status_code=400, detail="单批数据不超过1000条")
    
    logger.info(f"接收到{len(feedback_list)}条数据插入请求")
    return batch_insert_mysql(feedback_list)

@app.get("/stats")
def get_statistics():
    """获取统计信息"""
    conn = None
    try:
        conn = get_mysql_connection()
        cursor = conn.cursor()
        
        # 获取总数据量
        cursor.execute("SELECT COUNT(*) as total FROM raw_feedback;")
        total = cursor.fetchone()['total']
        
        # 获取今日新增
        cursor.execute("SELECT COUNT(*) as today FROM raw_feedback WHERE DATE(create_time) = DATE(NOW());")
        today = cursor.fetchone()['today']
        
        # 获取各状态数量
        cursor.execute("""
            SELECT match_status, COUNT(*) as count 
            FROM raw_feedback 
            GROUP BY match_status;
        """)
        status_counts = cursor.fetchall()
        
        return {
            "total_records": total,
            "today_records": today,
            "status_distribution": {
                str(row['match_status']): row['count'] for row in status_counts
            },
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"获取统计信息失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"统计失败: {str(e)}")
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)