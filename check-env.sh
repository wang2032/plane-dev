#!/bin/bash
# Plane .env 配置检查脚本

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}检查 Plane .env 配置...${NC}"
echo ""

# 1. 检查文件是否存在
echo -e "${YELLOW}步骤 1: 检查 .env 文件${NC}"

files=(
    ".env"
    "apps/api/.env"
    "apps/web/.env"
    "apps/admin/.env"
    "apps/space/.env"
    "apps/live/.env"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $file${NC}"
    else
        echo -e "${RED}❌ $file 不存在${NC}"
        echo -e "   请运行: cp $file.example $file"
    fi
done

echo ""

# 2. 检查关键配置
echo -e "${YELLOW}步骤 2: 检查关键配置${NC}"

# 检查根目录 .env
if [ -f ".env" ]; then
    # 检查是否使用了默认密码
    if grep -q 'POSTGRES_PASSWORD="plane"' .env; then
        echo -e "${RED}❌ 数据库使用默认密码，请修改${NC}"
    else
        echo -e "${GREEN}✅ 数据库密码已修改${NC}"
    fi

    if grep -q 'RABBITMQ_PASSWORD="plane"' .env; then
        echo -e "${RED}❌ RabbitMQ 使用默认密码，请修改${NC}"
    else
        echo -e "${GREEN}✅ RabbitMQ 密码已修改${NC}"
    fi

    if grep -q 'AWS_ACCESS_KEY_ID="access-key"' .env; then
        echo -e "${RED}❌ MinIO 使用默认密钥，请修改${NC}"
    else
        echo -e "${GREEN}✅ MinIO 密钥已修改${NC}"
    fi
fi

echo ""

# 3. 检查 API 配置
echo -e "${YELLOW}步骤 3: 检查 API 配置${NC}"

if [ -f "apps/api/.env" ]; then
    # 检查 DEBUG 模式
    if grep -q 'DEBUG=1' apps/api/.env; then
        echo -e "${RED}❌ DEBUG=1，生产环境请设为 0${NC}"
    else
        echo -e "${GREEN}✅ DEBUG 已关闭${NC}"
    fi

    # 检查 CORS 设置
    if grep -q 'localhost' apps/api/.env; then
        echo -e "${YELLOW}⚠️  CORS 设置包含 localhost，请检查${NC}"
    else
        echo -e "${GREEN}✅ CORS 已配置${NC}"
    fi

    # 检查域名配置
    if grep -q 'plane.10rig.com:8443' apps/api/.env; then
        echo -e "${GREEN}✅ 域名已配置${NC}"
    else
        echo -e "${YELLOW}⚠️  请检查域名配置${NC}"
    fi
fi

echo ""

# 4. 检查前端配置
echo -e "${YELLOW}步骤 4: 检查前端配置${NC}"

frontends=("apps/web" "apps/admin" "apps/space")

for app in "${frontends[@]}"; do
    if [ -f "$app/.env" ]; then
        if grep -q 'localhost' $app/.env; then
            echo -e "${YELLOW}⚠️  $app 包含 localhost${NC}"
        else
            echo -e "${GREEN}✅ $app 域名已配置${NC}"
        fi
    fi
done

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}检查完成！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}如需修改配置，请运行：${NC}"
echo "  nano .env"
echo "  nano apps/api/.env"
echo "  nano apps/web/.env"
echo ""
