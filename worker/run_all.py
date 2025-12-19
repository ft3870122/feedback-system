#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
标签闭环流程主执行脚本
"""

import time
import traceback
from datetime import datetime
from utils import setup_logger, format_time

# 导入各个模块
from mysql_sample import stratified_sample
from coze_generate_tag import generate_and_save_tags
from pgvector_cluster import tag_cluster
from batch_match_tag import batch_match_tag
from edge_sample_update import edge_sample_update

logger = setup_logger("run_all")

def run_full_pipeline():
    """
    运行完整的标签闭环流程
    """
    logger.info("=" * 60)
    logger.info(f"开始执行标签闭环流程 - {format_time()}")
    logger.info("=" * 60)
    
    start_time = time.time()
    
    try:
        # 步骤1: 分层抽样
        logger.info("\n" + "=" * 40)
        logger.info("步骤1: 开始分层抽样")
        logger.info("=" * 40)
        
        sample_ids = stratified_sample()
        logger.info(f"分层抽样完成，抽取样本数: {len(sample_ids)}")
        
        # 步骤2: Coze生成初始标签
        logger.info("\n" + "=" * 40)
        logger.info("步骤2: 开始生成初始标签")
        logger.info("=" * 40)
        
        generate_and_save_tags()
        logger.info("初始标签生成完成")
        
        # 步骤3: 标签聚类
        logger.info("\n" + "=" * 40)
        logger.info("步骤3: 开始标签聚类")
        logger.info("=" * 40)
        
        tag_cluster()
        logger.info("标签聚类完成")
        
        # 步骤4: 批量打标和边缘样本筛选
        logger.info("\n" + "=" * 40)
        logger.info("步骤4: 开始批量打标和边缘样本筛选")
        logger.info("=" * 40)
        
        batch_match_tag()
        logger.info("批量打标完成")
        
        # 步骤5: 边缘样本迭代更新
        logger.info("\n" + "=" * 40)
        logger.info("步骤5: 开始边缘样本迭代更新")
        logger.info("=" * 40)
        
        edge_sample_update()
        logger.info("边缘样本迭代更新完成")
        
        # 计算总耗时
        end_time = time.time()
        total_time = end_time - start_time
        
        logger.info("\n" + "=" * 60)
        logger.info(f"标签闭环流程执行完成！")
        logger.info(f"总耗时: {total_time:.2f} 秒")
        logger.info(f"完成时间: {format_time()}")
        logger.info("=" * 60)
        
        return True
        
    except Exception as e:
        logger.error(f"标签闭环流程执行失败: {str(e)}")
        logger.error(f"错误堆栈: {traceback.format_exc()}")
        
        logger.info("\n" + "=" * 60)
        logger.info(f"标签闭环流程执行失败！")
        logger.info(f"失败时间: {format_time()}")
        logger.info("=" * 60)
        
        return False

def run_step_by_step():
    """
    分步执行标签闭环流程（用于调试）
    """
    steps = {
        1: ("分层抽样", stratified_sample),
        2: ("生成初始标签", generate_and_save_tags),
        3: ("标签聚类", tag_cluster),
        4: ("批量打标", batch_match_tag),
        5: ("边缘样本更新", edge_sample_update)
    }
    
    logger.info("可用步骤:")
    for step_num, (step_name, _) in steps.items():
        logger.info(f"  {step_num}. {step_name}")
    
    while True:
        try:
            choice = input("\n请选择要执行的步骤 (1-5, 0退出): ")
            
            if choice == '0':
                logger.info("退出程序")
                break
                
            step_num = int(choice)
            
            if step_num not in steps:
                logger.warning("无效的选择")
                continue
                
            step_name, step_func = steps[step_num]
            
            logger.info(f"\n开始执行步骤 {step_num}: {step_name}")
            start_time = time.time()
            
            step_func()
            
            end_time = time.time()
            logger.info(f"步骤 {step_num} 执行完成，耗时: {end_time - start_time:.2f} 秒")
            
        except ValueError:
            logger.warning("请输入有效的数字")
        except KeyboardInterrupt:
            logger.info("\n用户中断")
            break
        except Exception as e:
            logger.error(f"步骤执行失败: {str(e)}")
            logger.error(f"错误堆栈: {traceback.format_exc()}")

if __name__ == "__main__":
    try:
        # 默认运行完整流程
        run_full_pipeline()
        
        # 如果需要分步执行，取消下面的注释
        # run_step_by_step()
        
    except KeyboardInterrupt:
        logger.info("\n程序被用户中断")
    except Exception as e:
        logger.error(f"程序执行失败: {str(e)}")
        exit(1)