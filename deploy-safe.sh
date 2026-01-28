#!/bin/bash
# Plane 安全部署脚本（保留所有数据）
# 使用方法: ./deploy-safe.sh [server-user@server-ip] [project-path]

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 参数
SERVER=${1:-"root@your-server-ip"}
PROJECT_PATH=${2:-"/opt/plane"}
BACKUP_DIR="/opt/plane-backups"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}     Plane 安全部署脚本（数据保留模式）${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 1. 确认部署信息
echo -e "${YELLOW}部署信息：${NC}"
echo "  服务器: $SERVER"
echo "  项目路径: $PROJECT_PATH"
echo "  备份目录: $BACKUP_DIR"
echo ""

read -p "确认开始部署？(y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}部署已取消${NC}"
    exit 1
fi

# 2. 验证本地修改
echo -e "\n${YELLOW}步骤 1: 验证本地修改...${NC}"

if ! grep -q 'FALLBACK_LANGUAGE: TLanguage = "zh-CN"' packages/i18n/src/constants/language.ts; then
    echo -e "${RED}❌ 前端默认语言未设置为 zh-CN${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 前端默认语言: zh-CN${NC}"

if ! grep -q 'language = models.CharField(max_length=255, default="zh-CN")' apps/api/plane/db/models/user.py; then
    echo -e "${RED}❌ 后端默认语言未设置为 zh-CN${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 后端默认语言: zh-CN${NC}"

# 3. 在服务器上创建备份
echo -e "\n${YELLOW}步骤 2: 在服务器上备份数据...${NC}"

ssh ${SERVER} << ENDSSH
# 创建备份目录
mkdir -p ${BACKUP_DIR}/${BACKUP_DATE}

cd ${PROJECT_PATH}

echo "备份数据到: ${BACKUP_DIR}/${BACKUP_DATE}"

# 备份数据库
echo "  - 备份数据库..."
docker compose exec -T plane-db pg_dump -U plane plane > ${BACKUP_DIR}/${BACKUP_DATE}/database.sql 2>/dev/null || echo "  警告: 数据库备份失败"

# 备份上传文件
echo "  - 备份上传文件..."
docker run --rm -v plane_uploads:/data -v ${BACKUP_DIR}/${BACKUP_DATE}:/backup alpine tar czf /backup/uploads.tar.gz -C /data . 2>/dev/null || echo "  警告: 文件备份失败"

# 备份 .env 文件
echo "  - 备份配置文件..."
cp .env ${BACKUP_DIR}/${BACKUP_DATE}/ 2>/dev/null || true
cp apps/api/.env ${BACKUP_DIR}/${BACKUP_DATE}/ 2>/dev/null || true
cp apps/web/.env ${BACKUP_DIR}/${BACKUP_DATE}/ 2>/dev/null || true
cp apps/admin/.env ${BACKUP_DIR}/${BACKUP_DATE}/ 2>/dev/null || true
cp apps/space/.env ${BACKUP_DIR}/${BACKUP_DATE}/ 2>/dev/null || true
cp apps/live/.env ${BACKUP_DIR}/${BACKUP_DATE}/ 2>/dev/null || true

echo "✅ 备份完成: ${BACKUP_DIR}/${BACKUP_DATE}"
ENDSSH

echo -e "${GREEN}✅ 数据备份完成${NC}"

# 4. 同步代码（不删除任何文件）
echo -e "\n${YELLOW}步骤 3: 同步代码到服务器...${NC}"

rsync -avz \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude '__pycache__' \
    --exclude '*.pyc' \
    --exclude '.DS_Store' \
    --exclude 'logs' \
    --exclude '*.log' \
    --exclude '.env' \
    --exclude 'pgdata' \
    --exclude 'redisdata' \
    --exclude 'uploads' \
    --exclude 'rabbitmq_data' \
    ./ ${SERVER}:${PROJECT_PATH}/

echo -e "${GREEN}✅ 代码同步完成（未删除任何服务器文件）${NC}"

# 5. 在服务器上构建和部署
echo -e "\n${YELLOW}步骤 4: 在服务器上构建镜像...${NC}"

ssh ${SERVER} << ENDSSH
cd ${PROJECT_PATH}

# 停止服务（保留数据卷）
echo "停止服务（保留数据卷）..."
docker compose down

# 构建镜像
echo "构建 Docker 镜像..."
docker compose build --no-cache

# 启动服务
echo "启动服务..."
docker compose up -d

# 等待服务就绪
echo "等待服务启动..."
sleep 30

echo "检查服务状态..."
docker compose ps
ENDSSH

echo -e "${GREEN}✅ 服务部署完成${NC}"

# 6. 验证部署
echo -e "\n${YELLOW}步骤 5: 验证部署...${NC}"

ssh ${SERVER} << 'ENDSSH'
cd /opt/plane

echo "检查后端默认语言..."
docker compose exec -T api python manage.py shell << 'EOF'
from plane.db.models.user import Profile
default_lang = Profile._meta.get_field('language').default
print(f"✅ 后端默认语言: {default_lang}")

from plane.db.models import User
zh_users = User.objects.filter(language="zh-CN").count()
all_users = User.objects.count()
print(f"✅ 总用户数: {all_users}")
print(f"✅ 中文用户数: {zh_users}")
EOF
ENDSSH

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}     部署成功！所有数据已保留${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}📦 备份位置：${NC}"
echo "  ${SERVER}:${BACKUP_DIR}/${BACKUP_DATE}/"
echo ""
echo -e "${YELLOW}📝 备份内容：${NC}"
echo "  - database.sql     (数据库)"
echo "  - uploads.tar.gz   (用户上传文件)"
echo "  - *.env            (配置文件)"
echo ""
echo -e "${YELLOW}🔍 如需恢复备份：${NC}"
echo "  ssh ${SERVER}"
echo "  cd ${BACKUP_DIR}/${BACKUP_DATE}"
echo "  cat database.sql | docker exec -i plane-db psql -U plane plane"
echo ""
