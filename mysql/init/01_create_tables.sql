-- 创建数据库（如果不存在）
CREATE DATABASE IF NOT EXISTS `feedback_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE `feedback_db`;

-- 原始反馈数据表
CREATE TABLE IF NOT EXISTS `raw_feedback` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
  `product` VARCHAR(50) NOT NULL COMMENT '产品名',
  `content` TEXT NOT NULL COMMENT '原始反馈文本',
  `create_time` DATETIME NOT NULL COMMENT '反馈时间',
  `channel` VARCHAR(30) COMMENT '反馈渠道',
  `tag` VARCHAR(200) DEFAULT NULL COMMENT '最终打标结果',
  `match_status` TINYINT DEFAULT 0 COMMENT '0=未匹配，1=匹配成功，2=边缘样本',
  INDEX idx_product (`product`),
  INDEX idx_create_time (`create_time`),
  INDEX idx_match_status (`match_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='原始反馈数据表';

-- 抽样样本表
CREATE TABLE IF NOT EXISTS `sample_feedback` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `feedback_id` BIGINT NOT NULL COMMENT '关联raw_feedback.id',
  `content_clean` TEXT NOT NULL COMMENT '清洗后的文本',
  `gen_tag` VARCHAR(200) DEFAULT NULL COMMENT 'Coze生成的隐性标签',
  FOREIGN KEY (`feedback_id`) REFERENCES `raw_feedback`(`id`) ON DELETE CASCADE,
  INDEX idx_feedback_id (`feedback_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='抽样样本表';

-- 边缘样本表
CREATE TABLE IF NOT EXISTS `edge_feedback` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `feedback_id` BIGINT NOT NULL COMMENT '关联raw_feedback.id',
  `content_clean` TEXT NOT NULL COMMENT '清洗后的文本',
  `new_tag` VARCHAR(200) DEFAULT NULL COMMENT 'Coze补充的新标签',
  FOREIGN KEY (`feedback_id`) REFERENCES `raw_feedback`(`id`) ON DELETE CASCADE,
  INDEX idx_feedback_id (`feedback_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='边缘样本表';

-- 创建测试数据（可选）
INSERT INTO `raw_feedback` (`product`, `content`, `create_time`, `channel`) VALUES
('智能音箱', '音质很好，但是连接WiFi经常断', '2024-01-15 10:30:00', '官方论坛'),
('智能音箱', '语音识别准确率有待提高', '2024-01-15 11:15:00', '客服反馈'),
('智能音箱', '外观设计很漂亮，很喜欢', '2024-01-15 14:20:00', '电商评论'),
('智能手表', '电池续航能力不错，可以用3天', '2024-01-15 09:45:00', '社交媒体'),
('智能手表', '运动数据记录不准确', '2024-01-15 13:50:00', '官方论坛'),
('智能手表', '屏幕显示效果很好，很清晰', '2024-01-15 16:30:00', '电商评论'),
('智能台灯', '亮度调节很方便，护眼效果好', '2024-01-15 10:00:00', '客服反馈'),
('智能台灯', '连接APP偶尔会失败', '2024-01-15 15:10:00', '社交媒体'),
('智能门锁', '指纹识别速度快，安全性高', '2024-01-15 08:30:00', '电商评论'),
('智能门锁', '电池更换不太方便', '2024-01-15 12:45:00', '官方论坛');

-- 创建用户并授权
CREATE USER IF NOT EXISTS 'feedback_user'@'%' IDENTIFIED BY 'feedback_password';
GRANT ALL PRIVILEGES ON `feedback_db`.* TO 'feedback_user'@'%';
FLUSH PRIVILEGES;