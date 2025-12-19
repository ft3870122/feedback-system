# 🏷️ 标签闭环系统部署指南

## 📋 系统概述

标签闭环系统是一个基于Docker的反馈数据智能标签管理平台，支持自动标签生成、向量聚类、批量打标和边缘样本迭代优化。系统采用微服务架构，包含API服务、Worker服务和数据库服务。

### 核心功能
- ✅ **Coze 每日生成 1000 条模拟反馈数据**
- ✅ **1% 分层抽样 → Coze 生成初始隐性标签**
- ✅ **PGVector 向量聚类 → 构建初始标签库**
- ✅ **全量数据批量打标 + 边缘样本筛选**
- ✅ **边缘样本迭代 → 持续更新标签库**
- ✅ **Docker 容器化部署 + 自动化运维**

## 🏗️ 系统架构

### 组件关系图
```
📱 外部系统 → 🔌 FastAPI API → 🗄️ MySQL + 🔍 PostgreSQL(pgvector) → ⚙️ Python Worker → 🤖 Coze API
```

### 服务组件说明

| 服务名称 | 容器名称 | 端口 | 实例信息 | 说明 |
|---------|---------|------|---------|------|
| MySQL | feedback-mysql | 3306 | 实例ID: rm-7xv26nb6109rln469 | 存储原始反馈数据和标签结果 |
| PostgreSQL | feedback-postgres | 5432 | 实例ID: pgm-7xvwb5g00mgfsv56 | 存储向量数据和标签聚类 |
| FastAPI API | feedback-api | 8001 | ECS IP: 8.148.202.136 | 提供数据插入和查询接口 |
| Python Worker | feedback-worker | - | ECS IP: 8.148.202.136 | 执行标签生成和匹配任务 |
| Worker Cron | feedback-worker-cron | - | ECS IP: 8.148.202.136 | 定时执行标签闭环流程 |

## 🔧 部署方案

### 📋 前提条件

- **操作系统**: Ubuntu 22.04 LTS 64位（Jammy Jellyfish）
- **实例规格**: 2核4G（推荐4核8G）
- **存储**: 40GB SSD云盘
- **带宽**: 2Mbps以上
- **权限**: root用户权限
- **网络**: 稳定的网络连接（或使用离线部署方案）
- **内核版本**: 5.4+（确保overlay2存储驱动支持）

### 🌐 网络端口配置要求

#### 公网访问（出行）
- 8001/tcp - FastAPI API 接口（必须开放，供 Coze 公网调用）

#### VPC 内部访问（入行）
- 3306/tcp - MySQL 数据库（仅 VPC 内部访问）
- 5432/tcp - PostgreSQL 数据库（仅 VPC 内部访问）
- 8001/tcp - FastAPI API 接口（VPC 内部也可访问）

## 🚀 部署步骤

### 方法一：一键部署（推荐）

```bash
# 给部署脚本添加执行权限
chmod +x deploy.sh

# 运行部署脚本
./deploy.sh

# 选择选项：
# 1) 完整安装（推荐）
# 2) 仅安装 Docker 和 Docker Compose
# 3) 仅配置环境和启动服务
```

### 方法二：分步部署

#### 1. 系统环境准备

```bash
# 更新系统包
apt update && apt upgrade -y

# 安装必要工具
apt install -y wget curl vim git unzip

# 禁用IPv6（解决连接问题）
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p 2>/dev/null || true

# 配置DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 114.114.114.114" >> /etc/resolv.conf
```

#### 2. 国内网络环境优化

```bash
# 配置apt阿里云源（Ubuntu 22.04专用）
cp /etc/apt/sources.list /etc/apt/sources.list.bak
cat > /etc/apt/sources.list << 'EOF'
deb [arch=amd64] http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb [arch=amd64] http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb [arch=amd64] http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb [arch=amd64] http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
EOF

# 更新apt缓存
apt-get clean
apt-get update -o Acquire::http::Timeout=30 -o Acquire::Retries=3
```

#### 3. 安装Docker和Docker Compose（Ubuntu 22.04优化版）

```bash
# 安装依赖包
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# 添加Docker官方GPG密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 添加Docker源（使用阿里云镜像）
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新apt并安装Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# 确保使用overlay2存储驱动（Ubuntu 22.04推荐）
cat > /etc/docker/daemon.json << 'EOF'
{
  "storage-driver": "overlay2",
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://mirror.ccs.tencentyun.com",
    "https://hub-mirror.c.163.com",
    "https://reg-mirror.qiniu.com",
    "https://registry.cn-hangzhou.aliyuncs.com"
  ],
  "dns": ["8.8.8.8", "114.114.114.114"],
  "ipv6": false
}
EOF

# 启动Docker服务（Ubuntu 22.04使用systemd）
systemctl daemon-reload
systemctl start docker
systemctl enable docker

# 安装Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# 验证安装
docker --version
docker-compose --version
```

#### 4. 配置环境变量

```bash
# 复制环境变量示例文件
cp .env.example .env

# 编辑环境变量文件
vim .env

# 配置关键参数
# MYSQL_PASSWORD=your_secure_password
# PG_PASSWORD=your_secure_password
# COZE_API_KEY=your_coze_api_key
# COZE_APP_ID=your_coze_app_id
# API_KEY=your_secure_api_key
```

#### 5. 阿里云安全组配置

登录阿里云控制台，配置以下安全组规则：

1. **公网访问规则**：
   - 协议类型：TCP
   - 端口范围：8001/8001
   - 授权对象：0.0.0.0/0（或Coze服务器IP段）
   - 描述：FastAPI API接口

2. **VPC内部访问规则**：
   - 协议类型：TCP
   - 端口范围：3306/3306
   - 授权对象：VPC网段（如172.16.0.0/12）
   - 描述：MySQL数据库

   - 协议类型：TCP
   - 端口范围：5432/5432
   - 授权对象：VPC网段（如172.16.0.0/12）
   - 描述：PostgreSQL数据库

#### 6. 构建并启动服务

```bash
# 使用国内镜像版本构建服务
docker-compose -f docker-compose.aliyun.yml build

# 启动所有服务
docker-compose -f docker-compose.aliyun.yml up -d

# 查看服务状态
docker-compose -f docker-compose.aliyun.yml ps
```

#### 7. 验证部署

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

## 🔧 故障排除工具

### 1. 脚本编码修复工具

如果遇到脚本编码问题：

```bash
# 使用编码修复工具
chmod +x fix_script_encoding.sh
./fix_script_encoding.sh
```

### 2. Docker Compose权限修复工具

如果遇到"Permission denied"错误：

```bash
# 使用权限修复工具
chmod +x fix_docker_compose.sh
./fix_docker_compose.sh
```

### 3. Docker安装测试工具

验证Docker环境是否正常：

```bash
# 使用测试工具
chmod +x test_docker_install.sh
./test_docker_install.sh
```

## 📁 离线部署方案

### 1. 准备基础镜像

在有网络的环境中：

```bash
# 拉取基础镜像
docker pull mysql:8.0
docker pull postgres:15
docker pull python:3.8-slim

# 保存镜像为文件
docker save -o mysql-8.0.tar mysql:8.0
docker save -o postgres-15.tar postgres:15
docker save -o python-3.8-slim.tar python:3.8-slim
```

### 2. 在目标服务器上加载镜像

```bash
# 加载镜像文件
docker load -i mysql-8.0.tar
docker load -i postgres-15.tar
docker load -i python-3.8-slim.tar
```

### 3. 使用离线模式构建和启动

```bash
# 使用离线模式构建镜像
docker-compose -f docker-compose.offline.yml build --no-cache

# 启动所有服务
docker-compose -f docker-compose.offline.yml up -d
```

## 🔗 API 接口说明

### 1. 数据插入接口

```
POST http://8.148.202.136:8001/insert_feedback

Headers:
X-API-Key: your_api_key
Content-Type: application/json

Body:
{
    "feedback_list": [
        {
            "product": "产品A",
            "content": "这是一条反馈内容",
            "channel": "app",
            "create_time": "2024-01-01 12:00:00"
        }
    ]
}
```

### 2. 健康检查接口

```
GET http://8.148.202.136:8001/health

Response:
{
    "status": "healthy",
    "service": "feedback-api",
    "timestamp": "2024-01-01T12:00:00Z"
}
```

### 3. 统计信息接口

```
GET http://8.148.202.136:8001/stats

Response:
{
    "total_feedback": 1000,
    "total_tags": 50,
    "pending_process": 0,
    "last_process_time": "2024-01-01T12:00:00Z"
}
```

## 🐳 常用Docker命令（Ubuntu 22.04优化）

```bash
# 查看服务状态
docker-compose -f docker-compose.aliyun.yml ps

# 查看日志
docker-compose -f docker-compose.aliyun.yml logs -f [服务名]

# 重启服务
docker-compose -f docker-compose.aliyun.yml restart

# 停止服务
docker-compose -f docker-compose.aliyun.yml down

# 查看容器资源使用情况
docker stats

# 进入容器
docker exec -it [容器名] bash

# 检查Docker服务状态（Ubuntu 22.04使用systemd）
systemctl status docker

# 重启Docker服务
systemctl restart docker

# 检查Docker存储驱动（Ubuntu 22.04推荐overlay2）
docker info | grep "Storage Driver"

# 清理Docker系统（Ubuntu 22.04安全清理）
docker system prune -af --volumes
```

## ⏰ 定时任务

系统自动配置了以下定时任务：

| 时间 | 任务 | 说明 |
|------|------|------|
| `0 1 * * *` | `run_all.py` | 每天凌晨1点执行完整标签闭环流程 |
| `0 * * * *` | API健康检查 | 每小时检查API服务状态 |
| `0 3 * * 0` | 数据备份 | 每周日凌晨3点执行数据备份 |

## 📊 监控与维护

### 日志管理

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
curl http://8.148.202.136:8001/health

# 服务可用性检查
docker-compose -f docker-compose.aliyun.yml ps
```

### 性能监控

```bash
# 查看容器资源使用情况
docker stats

# 查看数据库连接数
docker exec -it feedback-mysql mysql -uroot -p -e "SHOW STATUS LIKE 'Threads_connected';"
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

### 3. API安全（Ubuntu 22.04增强）

- 所有API接口都需要 `X-API-Key` 认证
- 建议定期更换API密钥
- 生产环境建议配置HTTPS
- Ubuntu 22.04推荐使用certbot自动配置SSL证书：
  ```bash
  # 安装certbot（Ubuntu 22.04）
  apt-get install -y certbot python3-certbot-nginx
  
  # 自动获取并配置SSL证书
  certbot --nginx -d your-domain.com
  ```

## 📈 性能优化

### 1. 容器资源限制（Ubuntu 22.04优化）

根据服务器配置调整 `docker-compose.yml` 中的资源限制：

```yaml
services:
  feedback-api:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
    # Ubuntu 22.04推荐的安全设置
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    # 优化OOM行为
    oom_score_adj: 100
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
docker exec -i feedback-mysql mysql -uroot -p$MYSQL_PASSWORD feedback_db < feedback_db.sql

# 导出本地PostgreSQL数据
pg_dump -U postgres feedback_vector > feedback_vector.sql

# 导入到云PostgreSQL
docker exec -i feedback-postgres psql -U postgres feedback_vector < feedback_vector.sql
```

## 🐛 常见问题

### 1. Docker 安装失败（Ubuntu 22.04特定问题）

**问题**: `E: Unable to locate package docker-ce` 或 `连接get.docker.com失败`

**解决方案**:
```bash
# Ubuntu 22.04专用安装方法
apt-get install -y docker.io

# 或者使用阿里云镜像源安装
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun

# 如果还是失败，使用apt直接安装
apt-get install -y docker.io docker-compose
```

### 2. 端口被占用（Ubuntu 22.04优化）

**问题**: `Error starting userland proxy: listen tcp 0.0.0.0:3306: bind: address already in use`

**解决方案**:
```bash
# 检查端口占用（Ubuntu 22.04推荐）
ss -tlnp | grep 3306

# 停止占用端口的服务（Ubuntu 22.04使用systemd）
systemctl stop mysql
# 或者停止MariaDB（Ubuntu 22.04默认）
systemctl stop mariadb

# 禁用自动启动
systemctl disable mysql
# 或者
systemctl disable mariadb
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
docker-compose -f docker-compose.aliyun.yml restart feedback-worker
```

## 📞 技术支持

### 问题反馈

1. **查看日志**: `docker-compose -f docker-compose.aliyun.yml logs -f [服务名]`
2. **检查服务状态**: `docker-compose -f docker-compose.aliyun.yml ps`
3. **验证数据库连接**: 
   ```bash
   docker exec -it feedback-mysql mysql -uroot -p
   docker exec -it feedback-postgres psql -U postgres
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