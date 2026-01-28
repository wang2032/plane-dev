#!/bin/bash
# Plane 数据备份脚本
# 使用方法: ./backup-data.sh [server-user@server-ip] [project-path]

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SERVER=${1:-"root@your-server-ip"}
PROJECT_PATH=${2:-"/opt/plane"}
BACKUP_DIR="/opt/plane-backups"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}     Plane 数据备份${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

ssh ${SERVER} << ENDSSH
# 创建备份目录
mkdir -p ${BACKUP_DIR}/${BACKUP_DATE}

echo -e "${YELLOW}开始备份到: ${BACKUP_DIR}/${BACKUP_DATE}${NC}"
echo ""

cd ${PROJECT_PATH}

# 1. 备份数据库
echo -e "${GREEN}步骤 1: 备份数据库...${NC}"
docker compose exec -T plane-db pg_dump -U plane plane > ${BACKUP_DIR}/${BACKUP_DATE}/database.sql
if [ $? -eq 0 ]; then
    SIZE=$(du -h ${BACKUP_DIR}/${BACKUP_DATE}/database.sql | cut -f1)
    echo -e "✅ 数据库备份完成 (${SIZE})"
else
    echo -e "❌ 数据库备份失败"
fi

# 2. 备份上传文件
echo -e "\n${GREEN}步骤 2: 备份上传文件...${NC}"
docker run --rm -v plane_uploads:/data -v ${BACKUP_DIR}/${BACKUP_DATE}:/backup alpine tar czf /backup/uploads.tar.gz -C /data .
if [ $? -eq 0 ]; then
    SIZE=$(du -h ${BACKUP_DIR}/${BACKUP_DATE}/uploads.tar.gz | cut -f1)
    echo -e "✅ 文件备份完成 (${SIZE})"
else
    echo -e "❌ 文件备份失败"
fi

# 3. 备份 Redis 数据
echo -e "\n${GREEN}步骤 3: 备份 Redis 数据...${NC}"
docker compose exec -T plane-redis redis-cli --rdb - > /dev/null 2>&1
docker run --rm -v plane_redisdata:/data -v ${BACKUP_DIR}/${BACKUP_DATE}:/backup alpine tar czf /backup/redis.tar.gz -C /data .
if [ $? -eq 0 ]; then
    SIZE=$(du -h ${BACKUP_DIR}/${BACKUP_DATE}/redis.tar.gz | cut -f1)
    echo -e "✅ Redis 备份完成 (${SIZE})"
else
    echo -e "⚠️  Redis 备份失败（可选）"
fi

# 4. 备份配置文件
echo -e "\n${GREEN}步骤 4: 备份配置文件...${NC}"
for file in .env apps/api/.env apps/web/.env apps/admin/.env apps/space/.env apps/live/.env; do
    if [ -f "$file" ]; then
        cp $file ${BACKUP_DIR}/${BACKUP_DATE}/
        echo -e "✅ 已备份: $file"
    fi
done

# 5. 创建备份清单
echo -e "\n${GREEN}步骤 5: 创建备份清单...${NC}"
cat > ${BACKUP_DIR}/${BACKUP_DATE}/backup-info.txt << EOF
备份时间: $(date)
备份目录: ${BACKUP_DIR}/${BACKUP_DATE}
项目路径: ${PROJECT_PATH}

备份内容:
- database.sql      数据库完整备份
- uploads.tar.gz    用户上传文件
- redis.tar.gz      Redis 数据（可选）
- *.env             配置文件

恢复方法:
1. 数据库: cat database.sql | docker exec -i plane-db psql -U plane plane
2. 文件: docker run --rm -v plane_uploads:/data -v \$(pwd):/backup alpine tar xzf /backup/uploads.tar.gz -C /data
3. 配置: cp *.env ${PROJECT_PATH}/
EOF

echo -e "✅ 备份清单已创建"

# 6. 显示备份信息
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}     备份完成！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}备份位置：${NC}"
ls -lh ${BACKUP_DIR}/${BACKUP_DATE}/
echo ""
echo -e "${YELLOW}查看备份信息：${NC}"
echo "  cat ${BACKUP_DIR}/${BACKUP_DATE}/backup-info.txt"
echo ""

# 清理旧备份（保留最近 7 天）
echo -e "${YELLOW}清理旧备份（保留最近 7 天）...${NC}"
find ${BACKUP_DIR} -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null
echo -e "✅ 清理完成"
ENDSSH
