-- 创建向量扩展
CREATE EXTENSION IF NOT EXISTS vector;

-- 标签向量库表
CREATE TABLE IF NOT EXISTS tag_vector (
    id SERIAL PRIMARY KEY,
    tag VARCHAR(200) NOT NULL COMMENT '结构化标签',
    tag_vector vector(768) NOT NULL COMMENT '标签向量',
    cluster_id INT DEFAULT 0 COMMENT '聚类ID',
    tag_type VARCHAR(20) DEFAULT 'initial' COMMENT 'initial=初始标签，iter=迭代标签',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(tag),
    INDEX idx_tag_vector USING ivfflat (tag_vector vector_l2_ops) WITH (lists = 100),
    INDEX idx_cluster_id (cluster_id),
    INDEX idx_tag_type (tag_type)
);

-- 反馈文本向量表
CREATE TABLE IF NOT EXISTS feedback_vector (
    id SERIAL PRIMARY KEY,
    feedback_id BIGINT NOT NULL COMMENT '关联MySQL的raw_feedback.id',
    content_clean TEXT NOT NULL,
    text_vector vector(768) NOT NULL,
    match_tag_id INT DEFAULT NULL COMMENT '匹配的tag_vector.id',
    similarity FLOAT DEFAULT 0 COMMENT '匹配相似度',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE(feedback_id),
    INDEX idx_text_vector USING ivfflat (text_vector vector_l2_ops) WITH (lists = 1000),
    INDEX idx_match_tag_id (match_tag_id),
    INDEX idx_similarity (similarity)
);

-- 创建初始标签数据（可选）
INSERT INTO tag_vector (tag, tag_vector, tag_type) VALUES
('功能-连接-WiFi不稳定', '[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]', 'initial'),
('功能-语音识别-准确率低', '[0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]', 'initial'),
('外观-设计-美观', '[0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]', 'initial'),
('电池-续航-持久', '[0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1]', 'initial'),
('功能-运动记录-不准确', '[0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2]', 'initial'),
('屏幕-显示-清晰', '[0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3]', 'initial'),
('功能-亮度调节-方便', '[0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4]', 'initial'),
('功能-APP连接-不稳定', '[0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5]', 'initial'),
('功能-指纹识别-快速', '[0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6]', 'initial'),
('电池-更换-不便', '[1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7]', 'initial');

-- 创建用户并授权
CREATE USER IF NOT EXISTS feedback_user WITH PASSWORD 'feedback_password';
GRANT ALL PRIVILEGES ON DATABASE feedback_vector TO feedback_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO feedback_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO feedback_user;