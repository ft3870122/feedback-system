# 标签闭环系统 - Ubuntu Docker 部署方案

## 📋 项目概述

本项目将标签闭环系统从本地部署迁移到基于 **Ubuntu 22.04** 和 **Docker** 的云环境部署方案。系统使用 Coze 生成标签，结合云 MySQL 和带 PGVector 扩展的 PostgreSQL 实现自动化标签闭环。

### 核心功能
- ✅ **Coze 每日生成 1000 条模拟反馈数据**
- ✅ **1% 分层抽样 → Coze 生成初始隐性标签**
- ✅ **PGVector 向量聚类 → 构建初始标签库**
- ✅ **全量数据批量打标 + 边缘样本筛选**
- ✅ **边缘样本迭代 → 持续更新标签库**
- ✅ **Docker 容器化部署 + 自动化运维**

## 🚀 快速开始

### 1. 环境要求

#### 阿里云服务器配置
- **操作系统**: Ubuntu 22.04 LTS 64位
- **实例规格**: 2核4G (最低配置，推荐4核8G)
- **存储**: 40GB SSD云盘
- **带宽**: 2Mbps以上
- **安全组**: 开放端口 22(SSH)、8001(API)、3306(MySQL)、5432(PostgreSQL)

#### 依赖软件
- Docker 24.0.7+
- Docker Compose 2.21.0+

### 2. 详细执行步骤

#### 2.1 连接服务器
```bash
# 使用SSH连接服务器（请替换为实际IP）
ssh root@8.148.202.136
```

#### 2.2 系统环境准备
```bash
# 更新系统包
apt update && apt upgrade -y

# 安装必要工具
apt install -y wget curl vim git unzip
```

#### 2.3 国内网络环境优化（重要）

**步骤1: 配置Docker阿里云镜像加速**
```bash
# 创建Docker配置目录
mkdir -p /etc/docker

# 配置阿里云Docker镜像加速器
cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": [
    "https://registry.cn-hangzhou.aliyuncs.com",
    "https://registry.cn-shanghai.aliyuncs.com",
    "https://registry.cn-shenzhen.aliyuncs.com"
  ]
}
EOF

# 重启Docker服务
systemctl daemon-reload
systemctl restart docker
```

**步骤2: 配置pip阿里云源**
```bash
# 创建pip配置目录
mkdir -p ~/.pip

# 配置pip阿里云源
cat > ~/.pip/pip.conf << 'EOF'
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/

[install]
trusted-host=mirrors.aliyun.com
EOF
```

**步骤3: 配置apt阿里云源**
```bash
# 备份原有源文件
cp /etc/apt/sources.list /etc/apt/sources.list.bak

# 配置阿里云apt源
cat > /etc/apt/sources.list << 'EOF'
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
EOF

# 更新apt缓存
apt-get clean
apt-get update
```

#### 2.4 克隆项目代码
```bash
# 克隆项目代码
git clone https://github.com/your-repo/feedback-system.git
cd feedback-system
```

#### 2.5 一键部署Docker环境
```bash
# 给部署脚本添加执行权限
chmod +x deploy.sh

# 执行部署脚本（选择选项2仅安装Docker和Docker Compose）
# 优化后的脚本会自动配置阿里云镜像加速
echo "2" | ./deploy.sh
```

**等待Docker安装完成后，继续执行以下步骤**

**注意：优化后的deploy.sh脚本已经包含以下功能：**
- ✅ 自动配置阿里云Docker镜像加速
- ✅ 支持多种Docker Compose安装方式
- ✅ 自动检测并使用国内镜像配置文件
- ✅ 预拉取基础Docker镜像
- ✅ 更友好的错误处理和用户提示

#### 2.6 预拉取基础Docker镜像（国内优化）
```bash
# 拉取MySQL镜像
docker pull registry.cn-hangzhou.aliyuncs.com/library/mysql:8.0
docker tag registry.cn-hangzhou.aliyuncs.com/library/mysql:8.0 mysql:8.0

# 拉取PostgreSQL镜像
docker pull registry.cn-hangzhou.aliyuncs.com/library/postgres:15
docker tag registry.cn-hangzhou.aliyuncs.com/library/postgres:15 postgres:15

# 拉取Python镜像
docker pull registry.cn-hangzhou.aliyuncs.com/library/python:3.8-slim
docker tag registry.cn-hangzhou.aliyuncs.com/library/python:3.8-slim python:3.8-slim
```

#### 2.7 创建国内镜像版本的Docker Compose配置
```bash
# 创建国内镜像版本的docker-compose文件
cp docker-compose.offline.yml docker-compose.aliyun.yml

# 使用sed命令批量替换镜像源
sed -i 's|mysql:8.0|registry.cn-hangzhou.aliyuncs.com/library/mysql:8.0|g' docker-compose.aliyun.yml
sed -i 's|postgres:15|registry.cn-hangzhou.aliyuncs.com/library/postgres:15|g' docker-compose.aliyun.yml
sed -i 's|python:3.8-slim|registry.cn-hangzhou.aliyuncs.com/library/python:3.8-slim|g' docker-compose.aliyun.yml

# 查看修改后的配置文件
grep "image:" docker-compose.aliyun.yml
```

#### 2.8 配置环境变量
```bash
# 复制环境变量示例文件
cp .env.example .env

# 编辑环境变量文件
vim .env

# 需要配置的关键参数：
# MYSQL_PASSWORD=your_secure_password
# PG_PASSWORD=your_secure_password  
# COZE_API_KEY=your_coze_api_key
# COZE_APP_ID=your_coze_app_id
# API_KEY=your_secure_api_key
```

#### 2.9 阿里云安全组配置（重要）

**登录阿里云控制台，配置以下安全组规则：**

1. **公网访问规则（出行）**：
   - 协议类型：TCP
   - 端口范围：8001/8001
   - 授权对象：0.0.0.0/0（或Coze服务器IP段）
   - 描述：FastAPI API接口

2. **VPC内部访问规则（入行）**：
   - 协议类型：TCP
   - 端口范围：3306/3306
   - 授权对象：VPC网段（如172.16.0.0/12）
   - 描述：MySQL数据库

   - 协议类型：TCP
   - 端口范围：5432/5432
   - 授权对象：VPC网段（如172.16.0.0/12）
   - 描述：PostgreSQL数据库

#### 2.10 构建并启动服务
```bash
# 使用国内镜像版本构建服务
docker-compose -f docker-compose.aliyun.yml build

# 启动所有服务
docker-compose -f docker-compose.aliyun.yml up -d

# 查看服务启动状态
docker-compose -f docker-compose.aliyun.yml ps
```

#### 2.11 配置Coze API
```bash
# 编辑环境变量文件配置Coze API信息
vim .env

# 修改以下配置
COZE_API_KEY=你的Coze API Key
COZE_APP_ID=你的Coze应用ID

# 重启worker服务使配置生效
docker-compose -f docker-compose.aliyun.yml restart feedback-worker
```

#### 2.12 验证部署结果
```bash
# 检查服务状态
docker-compose -f docker-compose.aliyun.yml ps

# 查看API服务日志
docker-compose -f docker-compose.aliyun.yml logs -f feedback-api

# 测试API健康检查
curl http://8.148.202.136:8001/health

# 测试API统计接口
curl http://8.148.202.136:8001/stats
```

#### 2.13 执行初始标签闭环流程
```bash
# 进入worker容器
docker exec -it feedback-worker bash

# 执行完整标签闭环流程
python run_all.py

# 退出容器
exit
```

#### 2.14 配置Coze Agent调用

在Coze工作台配置HTTP工具：
- **请求URL**: `http://8.148.202.136:8001/insert_feedback`
- **请求方法**: POST
- **请求头**: 
  - `X-API-Key`: 查看.env文件中的API_KEY值
- **请求体**: JSON格式的反馈数据列表

### 3. 验证部署

#### 3.1 检查服务状态
```bash
# 查看服务状态
docker-compose ps

# 检查日志
docker-compose logs -f feedback-api
```

#### 3.2 测试 API 接口
```bash
# 健康检查
curl http://你的服务器IP:8001/health

# 获取统计信息
curl http://你的服务器IP:8001/stats
```

#### 3.3 配置 Coze Agent

在 Coze 工作台配置 HTTP 工具：
- **请求URL**: `http://你的服务器IP:8001/insert_feedback`
- **请求方法**: POST
- **请求头**: 
  - `X-API-Key`: 查看 .env 文件中的 API_KEY 值
- **请求体**: JSON 格式的反馈数据列表

## 📁 项目结构

```
feedback-system/
├── api/                      # FastAPI接口服务
│   ├── Dockerfile           # API服务Dockerfile
│   ├── requirements.txt     # Python依赖
│   └── feedback_insert.py   # 反馈数据插入接口
├── worker/                  # 定时任务工作服务
│   ├── Dockerfile           # Worker服务Dockerfile
│   ├── Dockerfile.cron      # Cron定时任务Dockerfile
│   ├── requirements.txt     # Python依赖
│   ├── config.py            # 配置文件
│   ├── utils.py             # 工具函数
│   ├── mysql_sample.py      # MySQL分层抽样
│   ├── coze_generate_tag.py # Coze标签生成
│   ├── pgvector_cluster.py  # PGVector聚类
│   ├── batch_match_tag.py   # 批量标签匹配
│   ├── edge_sample_update.py # 边缘样本更新
│   ├── run_all.py           # 主执行脚本
│   └── crontab              # Cron定时任务配置
├── mysql/                   # MySQL配置
│   └── init/                # 初始化SQL脚本
├── postgres/                # PostgreSQL配置
│   ├── Dockerfile           # PostgreSQL+PGVector Dockerfile
│   └── init/                # 初始化SQL脚本
├── docker-compose.yml       # Docker Compose配置
├── .env.example             # 环境变量示例
├── deploy.sh                # 一键部署脚本
└── README.md                # 项目说明
```

## 🔧 配置说明

### 环境变量配置

主要配置项（在 `.env` 文件中）：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `MYSQL_PASSWORD` | MySQL root密码 | 自动生成 |
| `PG_PASSWORD` | PostgreSQL密码 | 自动生成 |
| `COZE_API_KEY` | Coze API密钥 | 需手动配置 |
| `COZE_APP_ID` | Coze应用ID | 需手动配置 |
| `API_KEY` | FastAPI接口密钥 | 自动生成 |
| `VECTOR_MODEL` | 向量模型 | m3e-base |
| `SIMILARITY_THRESHOLD` | 相似度阈值 | 0.6 |

### 数据持久化

所有数据都存储在云盘挂载的目录中：

- **MySQL数据**: `/data/mysql`
- **PostgreSQL数据**: `/data/postgresql`
- **应用日志**: `/data/logs`

## 🐳 Docker 容器管理

### 常用命令

```bash
# 启动所有服务
docker-compose up -d

# 停止所有服务
docker-compose down

# 重启服务
docker-compose restart

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f [服务名]

# 构建镜像
docker-compose build

# 查看容器资源使用情况
docker stats
```

### 服务列表

| 服务名 | 容器名 | 作用 | 端口 |
|--------|--------|------|------|
| `feedback-api` | `feedback-api` | FastAPI接口服务 | 8001:8000 |
| `feedback-worker` | `feedback-worker` | 定时任务工作容器 | - |
| `feedback-cron` | `feedback-cron` | Cron定时调度 | - |
| `mysql` | `mysql` | MySQL数据库 | 3306:3306 |
| `postgres` | `postgres` | PostgreSQL+PGVector | 5432:5432 |
| `nginx` | `nginx` | Nginx反向代理（可选） | 80:80 |

## ⏰ 定时任务

系统自动配置了以下定时任务（在 `feedback-cron` 容器中）：

| 时间 | 任务 | 说明 |
|------|------|------|
| `0 1 * * *` | `run_all.py` | 每天凌晨1点执行完整标签闭环流程 |
| `0 * * * *` | API健康检查 | 每小时检查API服务状态 |
| `0 3 * * 0` | 数据备份 | 每周日凌晨3点执行数据备份 |

## 📊 监控与维护

### 日志管理

所有服务日志集中存储在 `/data/logs` 目录：

```bash
# 查看API日志
tail -f /data/logs/feedback_api.log

# 查看工作服务日志
tail -f /data/logs/run_all.log

# 查看Cron日志
tail -f /data/logs/cron.log
```

### 健康检查

```bash
# API健康检查
curl http://你的服务器IP:8001/health

# 服务可用性检查
docker-compose ps
```

### 性能监控

```bash
# 查看容器资源使用情况
docker stats

# 查看数据库连接数
docker exec -it mysql mysql -uroot -p -e "SHOW STATUS LIKE 'Threads_connected';"
```

## 🔒 安全配置

### 1. 防火墙配置

```bash
# 配置UFW防火墙
ufw allow 22/tcp
ufw allow 8001/tcp
ufw allow 3306/tcp
ufw allow 5432/tcp
ufw enable
```

### 2. 数据库安全

- 数据库密码自动生成并加密存储
- 生产环境建议关闭公网访问，使用内网连接
- 定期更新数据库密码

### 3. API安全

- 所有API接口都需要 `X-API-Key` 认证
- 建议定期更换API密钥
- 生产环境建议配置HTTPS

## 📈 性能优化

### 1. 容器资源限制

根据服务器配置调整 `docker-compose.yml` 中的资源限制：

```yaml
services:
  feedback-api:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

### 2. 数据库优化

- MySQL 配置 innodb_buffer_pool_size
- PostgreSQL 配置 shared_buffers 和 work_mem
- 为向量索引配置合适的 lists 参数

### 3. 向量计算优化

- 使用多进程进行向量计算
- 配置 Redis 缓存热点向量数据
- 调整批处理大小以适应服务器内存

## 🔄 数据迁移

### 从本地迁移到云环境

```bash
# 导出本地MySQL数据
mysqldump -uroot -p feedback_db > feedback_db.sql

# 导入到云MySQL
docker exec -i mysql mysql -uroot -p$MYSQL_PASSWORD feedback_db < feedback_db.sql

# 导出本地PostgreSQL数据
pg_dump -U postgres feedback_vector > feedback_vector.sql

# 导入到云PostgreSQL
docker exec -i postgres psql -U postgres feedback_vector < feedback_vector.sql
```

## 🐛 常见问题

### 1. Docker 安装失败

**问题**: `E: Unable to locate package docker-ce`

**解决方案**:
```bash
# 检查Ubuntu版本
lsb_release -a

# 使用官方安装脚本
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
```

### 2. 端口被占用

**问题**: `Error starting userland proxy: listen tcp 0.0.0.0:3306: bind: address already in use`

**解决方案**:
```bash
# 检查端口占用
netstat -tlnp | grep 3306

# 停止占用端口的服务
systemctl stop mysql
```

### 3. 向量模型下载失败

**问题**: `ConnectionError: Could not download model`

**解决方案**:
```bash
# 配置国内镜像
export HF_ENDPOINT=https://hf-mirror.com

# 或者手动下载模型到容器中
```

### 4. Coze API 调用失败

**问题**: `API key not valid`

**解决方案**:
```bash
# 检查Coze API配置
cat .env | grep COZE

# 重启服务
docker-compose restart feedback-worker
```

## 📞 技术支持

### 问题反馈

1. **查看日志**: `docker-compose logs -f [服务名]`
2. **检查服务状态**: `docker-compose ps`
3. **验证数据库连接**: 
   ```bash
   docker exec -it mysql mysql -uroot -p
   docker exec -it postgres psql -U postgres
   ```

### 联系方式

- **技术文档**: [项目Wiki](https://github.com/your-repo/feedback-system/wiki)
- **问题反馈**: [GitHub Issues](https://github.com/your-repo/feedback-system/issues)
- **技术支持**: support@example.com

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [Coze API](https://www.coze.com/) - AI 标签生成
- [PGVector](https://github.com/pgvector/pgvector) - 向量数据库扩展
- [Sentence Transformers](https://github.com/UKPLab/sentence-transformers) - 文本向量化
- [Docker](https://www.docker.com/) - 容器化平台

---

**部署完成后，请立即配置 Coze API 信息并测试数据流转！**