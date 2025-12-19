# 🏷️ 标签闭环系统 - 完整部署步骤文档

## 📋 项目概述

标签闭环系统是一个基于Docker的反馈数据智能标签管理平台，支持自动标签生成、向量聚类、批量打标和边缘样本迭代优化。

### 核心功能
- ✅ **Coze 每日生成 1000 条模拟反馈数据**
- ✅ **1% 分层抽样 → Coze 生成初始隐性标签**
- ✅ **PGVector 向量聚类 → 构建初始标签库**
- ✅ **全量数据批量打标 + 边缘样本筛选**
- ✅ **边缘样本迭代 → 持续更新标签库**
- ✅ **Docker 容器化部署 + 自动化运维**

## 🚀 部署流程

### 📋 前置条件

- **操作系统**: Ubuntu 22.04 LTS (Jammy Jellyfish) 64位
- **硬件要求**: 
  - CPU: 2核以上（推荐4核）
  - 内存: 4GB以上（推荐8GB）
  - 存储: 40GB SSD以上
  - 网络: 2Mbps以上带宽
- **权限要求**: root用户权限
- **网络要求**: 能够访问Docker镜像源和GitHub

### 📁 文件结构说明

```
ubuntu-docker-deploy/
├── .env.example                 # 环境变量示例文件
├── docker-compose.yml           # 默认Docker Compose配置
├── docker-compose.aliyun.yml    # 阿里云镜像版本配置
├── docker-compose.offline.yml   # 离线部署版本配置
├── deploy.sh                    # 原部署脚本
├── deploy_simple.sh            # Ubuntu 22.04优化版部署脚本
├── ubuntu2204_check.sh         # Ubuntu 22.04环境检查工具
├── fix_docker_compose.sh       # Docker Compose权限修复工具
├── fix_script_encoding.sh      # 脚本编码修复工具
├── test_docker_install.sh      # Docker安装测试工具
├── deployment_guide.md         # 详细部署指南
└── README.md                   # 快速入门指南
```

## 🔄 部署步骤

### 第一阶段：环境准备与检查

#### 步骤1：系统环境检查（关键步骤）
```bash
# 给环境检查脚本添加执行权限
chmod +x ubuntu2204_check.sh

# 运行全面的环境检查
./ubuntu2204_check.sh

# 根据检查结果解决问题：
# - 安装缺失的软件包
# - 解决端口占用问题
# - 加载必要的内核模块
# - 确保网络连接正常
```

**检查要点：**
- ✅ Ubuntu版本必须是22.04 LTS
- ✅ 内核版本5.4+（支持overlay2）
- ✅ 硬件资源满足最低要求
- ✅ 8001、3306、5432端口未被占用
- ✅ 网络能够访问Docker相关网站

#### 步骤2：系统更新与依赖安装
```bash
# 更新系统包索引（使用超时和重试参数）
apt update -o Acquire::http::Timeout=30 -o Acquire::Retries=3

# 升级系统包（保留现有配置）
apt upgrade -y -o Dpkg::Options::="--force-confold"

# 安装必要的依赖包
apt install -y \
    wget curl vim git unzip \
    apt-transport-https ca-certificates \
    gnupg lsb-release software-properties-common \
    net-tools iputils-ping bc
```

### 第二阶段：Docker环境部署

#### 步骤3：一键部署Docker环境
```bash
# 给优化版部署脚本添加执行权限
chmod +x deploy_simple.sh

# 运行Ubuntu 22.04专属部署脚本
./deploy_simple.sh

# 脚本会自动执行以下操作：
# 1. 配置Ubuntu 22.04阿里云源
# 2. 安装Docker（尝试3种安装方式）
# 3. 安装Docker Compose（尝试3种安装方式）
# 4. 配置overlay2存储驱动
# 5. 配置多镜像源加速
# 6. 创建数据目录
```

#### 步骤4：Docker安装验证
```bash
# 验证Docker是否安装成功
docker --version

# 验证Docker Compose是否安装成功
docker-compose --version

# 检查Docker服务状态
systemctl status docker

# 验证存储驱动（必须是overlay2）
docker info | grep "Storage Driver"

# 验证镜像加速配置
docker info | grep "Registry Mirrors"
```

**预期结果：**
- Docker版本: 20.10+
- Docker Compose版本: 2.21.0+
- 存储驱动: overlay2
- 服务状态: active (running)

### 第三阶段：应用配置与启动

#### 步骤5：环境变量配置
```bash
# 复制环境变量示例文件
cp .env.example .env

# 编辑环境变量文件（重要步骤）
vim .env

# 必须配置的关键参数：
# COZE_API_KEY=your_coze_api_key        # Coze API密钥
# COZE_APP_ID=your_coze_app_id          # Coze应用ID
# API_KEY=your_secure_api_key           # 系统API密钥
# MYSQL_PASSWORD=secure_password        # MySQL数据库密码
# PG_PASSWORD=secure_password           # PostgreSQL数据库密码
```

**配置说明：**
- `COZE_API_KEY` 和 `COZE_APP_ID`：从Coze开发者平台获取
- `API_KEY`：用于API访问认证，建议使用强密码
- 数据库密码：建议使用复杂密码，至少12位

#### 步骤6：启动容器服务
```bash
# 使用阿里云镜像版本启动服务（推荐）
docker-compose -f docker-compose.aliyun.yml up -d

# 查看所有服务状态
docker-compose -f docker-compose.aliyun.yml ps

# 查看启动日志（关键：检查是否有错误）
docker-compose -f docker-compose.aliyun.yml logs -f
```

**服务启动检查：**
- feedback-api：FastAPI服务，端口8001
- feedback-worker：Python工作服务
- feedback-mysql：MySQL数据库，端口3306
- feedback-postgres：PostgreSQL数据库，端口5432
- feedback-worker-cron：定时任务服务

### 第四阶段：服务验证与测试

#### 步骤7：API服务验证
```bash
# 测试API健康检查接口
curl http://localhost:8001/health

# 测试API统计接口
curl http://localhost:8001/stats

# 检查API服务日志
docker-compose -f docker-compose.aliyun.yml logs -f feedback-api
```

**预期响应：**
```json
# 健康检查响应
{
  "status": "healthy",
  "service": "feedback-api",
  "timestamp": "2024-01-01T12:00:00Z"
}

# 统计接口响应
{
  "total_feedback": 0,
  "total_tags": 0,
  "pending_process": 0,
  "last_process_time": null
}
```

#### 步骤8：数据库连接验证
```bash
# 测试MySQL连接
docker exec -it feedback-mysql mysql -uroot -p

# 测试PostgreSQL连接
docker exec -it feedback-postgres psql -U postgres
```

#### 步骤9：阿里云安全组配置
```bash
# 登录阿里云ECS控制台
# 找到IP为8.148.202.136的实例
# 配置安全组规则：

# 公网访问规则：
# 协议：TCP
# 端口：8001/8001
# 授权对象：0.0.0.0/0（或Coze服务器IP）
# 描述：FastAPI API接口

# VPC内部访问规则：
# 协议：TCP
# 端口：3306/3306
# 授权对象：VPC网段（如172.16.0.0/12）
# 描述：MySQL数据库

# 协议：TCP
# 端口：5432/5432
# 授权对象：VPC网段（如172.16.0.0/12）
# 描述：PostgreSQL数据库
```

### 第五阶段：运维配置与监控

#### 步骤10：定时任务配置
```bash
# 查看当前cron任务
crontab -l

# 编辑cron任务
crontab -e

# 添加以下定时任务：
# 每天凌晨1点执行完整标签闭环流程
0 1 * * * cd /home/user/vibecoding/workspace/ubuntu-docker-deploy && docker-compose -f docker-compose.aliyun.yml exec feedback-worker python /app/run_all.py >> /data/logs/cron.log 2>&1

# 每小时检查API健康状态
0 * * * * curl -s http://localhost:8001/health > /dev/null || echo "$(date) API健康检查失败" >> /data/logs/health_check.log

# 每周日凌晨3点执行数据备份
0 3 * * 0 cd /home/user/vibecoding/workspace/ubuntu-docker-deploy && ./backup_data.sh >> /data/logs/backup.log 2>&1
```

#### 步骤11：监控配置
```bash
# 查看容器资源使用情况
docker stats

# 监控API服务日志
tail -f /data/logs/feedback_api.log

# 监控工作服务日志
tail -f /data/logs/run_all.log

# 监控定时任务日志
tail -f /data/logs/cron.log
```

## 🛠️ 故障排除

### 常见问题及解决方案

#### 问题1：Docker安装失败
```bash
# 症状：执行deploy_simple.sh后Docker未安装成功
# 解决方案：

# 1. 使用权限修复工具
chmod +x fix_docker_compose.sh
./fix_docker_compose.sh

# 2. 手动安装docker.io包（Ubuntu 22.04备用方案）
apt install -y docker.io

# 3. 检查系统服务状态
systemctl status docker
systemctl start docker
```

#### 问题2：端口被占用
```bash
# 症状：启动容器时提示端口已被占用
# 解决方案：

# 检查端口占用情况
ss -tlnp | grep 3306  # MySQL端口
ss -tlnp | grep 5432  # PostgreSQL端口
ss -tlnp | grep 8001  # API端口

# 停止占用端口的服务
systemctl stop mysql
systemctl stop mariadb

# 禁用自动启动
systemctl disable mysql
systemctl disable mariadb
```

#### 问题3：脚本编码错误
```bash
# 症状：执行脚本时出现编码相关错误
# 解决方案：

# 使用编码修复工具
chmod +x fix_script_encoding.sh
./fix_script_encoding.sh

# 检查文件编码
file deploy.sh
head -n 5 deploy.sh | xxd
```

#### 问题4：网络连接问题
```bash
# 症状：无法拉取Docker镜像或连接失败
# 解决方案：

# 运行网络诊断
./test_docker_install.sh

# 检查DNS配置
cat /etc/resolv.conf

# 测试网络连接
ping www.baidu.com
curl -I https://mirrors.aliyun.com
```

#### 问题5：存储驱动不是overlay2
```bash
# 症状：Docker使用的存储驱动不是overlay2
# 解决方案：

# 检查当前存储驱动
docker info | grep "Storage Driver"

# 修改daemon.json配置
vim /etc/docker/daemon.json

# 添加或确保以下配置
{
  "storage-driver": "overlay2"
}

# 重启Docker服务
systemctl restart docker
```

## 📊 运维管理

### 日常管理命令

```bash
# 查看服务状态
docker-compose -f docker-compose.aliyun.yml ps

# 启动所有服务
docker-compose -f docker-compose.aliyun.yml start

# 停止所有服务
docker-compose -f docker-compose.aliyun.yml stop

# 重启所有服务
docker-compose -f docker-compose.aliyun.yml restart

# 查看特定服务日志
docker-compose -f docker-compose.aliyun.yml logs -f feedback-api
docker-compose -f docker-compose.aliyun.yml logs -f feedback-worker

# 进入容器内部
docker exec -it feedback-api bash
docker exec -it feedback-mysql mysql -uroot -p
docker exec -it feedback-postgres psql -U postgres

# 查看容器资源使用情况
docker stats

# 清理Docker系统（谨慎使用）
docker system prune -af --volumes
```

### 数据管理

```bash
# 备份MySQL数据
docker exec feedback-mysql mysqldump -uroot -p$MYSQL_PASSWORD feedback_db > backup_mysql.sql

# 备份PostgreSQL数据
docker exec feedback-postgres pg_dump -U postgres feedback_vector > backup_postgres.sql

# 恢复MySQL数据
docker exec -i feedback-mysql mysql -uroot -p$MYSQL_PASSWORD feedback_db < backup_mysql.sql

# 恢复PostgreSQL数据
docker exec -i feedback-postgres psql -U postgres feedback_vector < backup_postgres.sql
```

### 性能监控

```bash
# 监控系统负载
top
htop

# 监控磁盘使用情况
df -h
du -sh /data/*

# 监控内存使用情况
free -h
vmstat 1

# 监控网络连接
netstat -tuln
ss -tuln

# 监控Docker事件
docker events
```

## 🔒 安全管理

### 安全加固措施

```bash
# 更新系统安全补丁
apt update
apt upgrade -y

# 配置防火墙（Ubuntu 22.04使用ufw）
ufw allow 22/tcp
ufw allow 8001/tcp
ufw allow 3306/tcp
ufw allow 5432/tcp
ufw enable

# 定期更新密码
# 修改MySQL密码
docker exec feedback-mysql mysqladmin -uroot -p password "new_secure_password"

# 修改API密钥
# 编辑.env文件，更新API_KEY
vim .env
docker-compose -f docker-compose.aliyun.yml restart feedback-api
```

### 日志审计

```bash
# 查看系统日志
journalctl -u docker
journalctl -u docker-compose

# 查看应用日志
tail -f /data/logs/*.log

# 日志轮转配置
# 编辑logrotate配置
vim /etc/logrotate.d/docker-logs

# 示例配置：
/data/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
```

## 📈 性能优化

### Docker优化

```bash
# 配置Docker daemon优化
vim /etc/docker/daemon.json

# 优化配置示例
{
  "storage-driver": "overlay2",
  "registry-mirrors": ["https://mirrors.aliyun.com"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "default-shm-size": "2g",
  "live-restore": true
}

# 重启Docker服务
systemctl restart docker
```

### 容器资源限制

```bash
# 编辑docker-compose.yml配置资源限制
vim docker-compose.aliyun.yml

# 添加资源限制配置
services:
  feedback-api:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    oom_score_adj: 100
```

## 📞 技术支持

### 问题反馈渠道

1. **查看日志文件**
   - API日志：`/data/logs/feedback_api.log`
   - Worker日志：`/data/logs/run_all.log`
   - Cron日志：`/data/logs/cron.log`

2. **检查服务状态**
   - Docker服务：`systemctl status docker`
   - 容器状态：`docker-compose -f docker-compose.aliyun.yml ps`
   - API状态：`curl http://localhost:8001/health`

3. **常见错误排查**
   - 网络问题：检查防火墙和安全组配置
   - 权限问题：检查文件和目录权限
   - 配置问题：检查环境变量和配置文件
   - 资源问题：检查CPU、内存和磁盘使用情况

## 📝 部署清单

### 必做项
- [ ] 运行环境检查脚本 `ubuntu2204_check.sh`
- [ ] 使用优化版部署脚本 `deploy_simple.sh`
- [ ] 配置环境变量文件 `.env`
- [ ] 启动Docker服务并验证状态
- [ ] 配置阿里云安全组规则
- [ ] 测试API接口可用性
- [ ] 设置定时任务

### 验证项
- [ ] Docker版本 >= 20.10
- [ ] Docker Compose版本 >= 2.21.0
- [ ] 存储驱动 = overlay2
- [ ] 8001端口可访问
- [ ] API健康检查返回正常
- [ ] 所有容器状态为Up
- [ ] 数据库连接正常

## 🎯 部署完成确认

当您完成所有部署步骤后，请执行以下命令确认系统正常运行：

```bash
# 最终验证命令
echo "=== 系统信息 ==="
docker --version
docker-compose --version
docker info | grep "Storage Driver"

echo -e "\n=== 服务状态 ==="
docker-compose -f docker-compose.aliyun.yml ps

echo -e "\n=== API状态 ==="
curl -s http://localhost:8001/health | jq .

echo -e "\n=== 系统资源 ==="
free -h
df -h
top -bn1 | head -20

echo -e "\n=== 部署完成确认 ==="
echo "标签闭环系统部署完成！"
echo "API地址: http://$(curl -s ifconfig.me):8001"
echo "健康检查: http://$(curl -s ifconfig.me):8001/health"
echo "统计接口: http://$(curl -s ifconfig.me):8001/stats"
```

## 📄 文档版本信息

- **文档版本**: v3.0
- **适用系统**: Ubuntu 22.04 LTS (Jammy Jellyfish)
- **最后更新**: 2025-12-19
- **主要功能**: 标签闭环系统完整部署指南

---

**部署完成后，请立即配置Coze API信息并测试数据流转！**

祝您部署顺利！ 🚀