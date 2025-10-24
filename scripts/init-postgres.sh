#!/bin/bash

# PostgreSQL 初始化脚本
# 用于初始化 WeWe-RSS PostgreSQL 数据库

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🐘 WeWe-RSS PostgreSQL 初始化脚本${NC}"
echo "=================================="

# 默认配置
DEFAULT_DB_HOST="localhost"
DEFAULT_DB_PORT="5432"
DEFAULT_DB_NAME="wewe-rss"
DEFAULT_DB_USER="wewe_rss"
DEFAULT_DB_PASSWORD="123456"

# 获取用户输入或使用默认值
read -p "数据库主机 [$DEFAULT_DB_HOST]: " DB_HOST
DB_HOST=${DB_HOST:-$DEFAULT_DB_HOST}

read -p "数据库端口 [$DEFAULT_DB_PORT]: " DB_PORT
DB_PORT=${DB_PORT:-$DEFAULT_DB_PORT}

read -p "数据库名称 [$DEFAULT_DB_NAME]: " DB_NAME
DB_NAME=${DB_NAME:-$DEFAULT_DB_NAME}

read -p "数据库用户 [$DEFAULT_DB_USER]: " DB_USER
DB_USER=${DB_USER:-$DEFAULT_DB_USER}

read -s -p "数据库密码: " DB_PASSWORD
if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD=$DEFAULT_DB_PASSWORD
    echo -e "\n${YELLOW}使用默认密码: $DEFAULT_DB_PASSWORD${NC}"
else
    echo -e "\n${GREEN}使用自定义密码${NC}"
fi

echo ""
echo -e "${GREEN}配置信息:${NC}"
echo "主机: $DB_HOST"
echo "端口: $DB_PORT"
echo "数据库: $DB_NAME"
echo "用户: $DB_USER"
echo ""

# 检查 PostgreSQL 客户端工具
if ! command -v psql &> /dev/null; then
    echo -e "${RED}❌ 未找到 psql 客户端工具${NC}"
    echo "请先安装 PostgreSQL 客户端："
    echo "  Ubuntu/Debian: sudo apt-get install postgresql-client"
    echo "  CentOS/RHEL: sudo yum install postgresql"
    echo "  macOS: brew install postgresql"
    exit 1
fi

# 测试数据库连接
echo -e "${YELLOW}🔗 测试数据库连接...${NC}"
if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "SELECT version();" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 数据库连接成功${NC}"
else
    echo -e "${RED}❌ 数据库连接失败${NC}"
    echo "请检查连接配置和数据库服务状态"
    exit 1
fi

# 检查数据库是否存在，如果不存在则创建
echo -e "${YELLOW}🏗️  检查并创建数据库...${NC}"
DB_EXISTS=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")

if [ -z "$DB_EXISTS" ]; then
    echo "创建数据库: $DB_NAME"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "CREATE DATABASE \"$DB_NAME\";"
    echo -e "${GREEN}✅ 数据库创建成功${NC}"
else
    echo -e "${YELLOW}⚠️  数据库已存在${NC}"
fi

# 生成环境变量文件
ENV_FILE=".env.postgresql"
echo -e "${YELLOW}📝 生成环境变量文件: $ENV_FILE${NC}"

cat > $ENV_FILE << EOF
# PostgreSQL 配置
DATABASE_PROVIDER="postgresql"
DATABASE_URL="postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME?schema=public&connect_timeout=30&pool_timeout=30"

# 其他配置
HOST=0.0.0.0
PORT=4000
AUTH_CODE=123567
MAX_REQUEST_PER_MINUTE=60
FEED_MODE="fulltext"
SERVER_ORIGIN_URL=http://localhost:4000
CRON_EXPRESSION="35 5,17 * * *"
ENABLE_CLEAN_HTML=false
UPDATE_DELAY_TIME=60
PLATFORM_URL="https://weread.111965.xyz"
EOF

echo -e "${GREEN}✅ 环境变量文件已生成${NC}"

# 安装依赖并生成 Prisma 客户端
echo -e "${YELLOW}📦 安装依赖并生成 Prisma 客户端...${NC}"
if [ -f "package.json" ]; then
    npm install
    npx prisma generate
    echo -e "${GREEN}✅ 依赖安装和客户端生成完成${NC}"
else
    echo -e "${YELLOW}⚠️  未找到 package.json，请手动安装依赖${NC}"
fi

# 运行数据库迁移
echo -e "${YELLOW}🔄 运行数据库迁移...${NC}"
if [ -f "package.json" ]; then
    npx prisma migrate deploy
    echo -e "${GREEN}✅ 数据库迁移完成${NC}"
else
    echo -e "${YELLOW}⚠️  请手动运行: npx prisma migrate deploy${NC}"
fi

echo ""
echo -e "${GREEN}🎉 PostgreSQL 初始化完成！${NC}"
echo ""
echo "下一步："
echo "1. 复制环境变量: cp $ENV_FILE .env.local"
echo "2. 修改 .env.local 中的其他配置"
echo "3. 启动应用: npm run dev 或 npm run start"
echo ""
echo "使用 Docker Compose 启动 PostgreSQL:"
echo "docker-compose -f docker-compose.postgresql.yml up -d"