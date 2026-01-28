#!/bin/bash
# Plane 中文版部署脚本
# 使用方法: ./deploy-to-server.sh [server-user@server-ip] [project-path]

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 参数
SERVER=${1:-"root@your-server-ip"}
PROJECT_PATH=${2:-"/opt/plane"}

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}     Plane 中文版部署脚本（默认语言：zh-CN）${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 1. 确认部署信息
echo -e "${YELLOW}部署信息：${NC}"
echo "  服务器: $SERVER"
echo "  项目路径: $PROJECT_PATH"
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

# 3. 同步代码到服务器
echo -e "\n${YELLOW}步骤 2: 同步代码到服务器...${NC}"

rsync -avz --delete \
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

echo -e "${GREEN}✅ 代码同步完成${NC}"

# 4. 在服务器上构建和部署
echo -e "\n${YELLOW}步骤 3: 在服务器上构建镜像...${NC}"

ssh ${SERVER} << ENDSSH
cd ${PROJECT_PATH}

# 停止服务
echo "停止现有服务..."
docker compose down

# 清理旧镜像（可选）
echo "清理旧的 Docker 资源..."
docker image prune -f

# 构建镜像
echo "构建 Docker 镜像（这需要 10-20 分钟，请耐心等待）..."
docker compose build --no-cache

# 启动服务
echo "启动服务..."
docker compose up -d

# 等待服务就绪
echo "等待服务启动（30秒）..."
sleep 30

ENDSSH

echo -e "${GREEN}✅ 镜像构建完成${NC}"

# 5. 验证部署
echo -e "\n${YELLOW}步骤 4: 验证部署...${NC}"

ssh ${SERVER} << 'ENDSSH'
cd /opt/plane

echo "检查服务状态..."
docker compose ps

echo ""
echo "检查后端默认语言..."
docker compose exec -T api python manage.py shell << 'EOF'
from plane.db.models.user import Profile
default_lang = Profile._meta.get_field('language').default
print(f"✅ 后端默认语言: {default_lang}")

from plane.db.models import User
zh_users = User.objects.filter(language="zh-CN").count()
print(f"✅ 当前中文用户数: {zh_users}")
EOF
ENDSSH

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}     部署成功！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "🎉 现在可以访问您的 Plane 实例了！"
echo ""
echo "📝 测试步骤："
echo "  1. 打开无痕浏览器"
echo "  2. 访问您的站点并注册新账号"
echo "  3. 检查界面是否为中文"
echo ""
echo "🔧 如有问题，请查看日志："
echo "  docker compose logs -f"
echo ""
