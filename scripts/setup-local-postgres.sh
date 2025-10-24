#!/bin/bash

# 本地 PostgreSQL 快速设置脚本
# 用于快速设置本地 WeWe-RSS PostgreSQL 开发环境

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐘 WeWe-RSS 本地 PostgreSQL 快速设置${NC}"
echo "=================================="

# 检查 PostgreSQL 是否已安装
check_postgres() {
    if command -v psql &> /dev/null; then
        echo -e "${GREEN}✅ PostgreSQL 已安装${NC}"
        return 0
    else
        echo -e "${RED}❌ 未找到 PostgreSQL${NC}"
        return 1
    fi
}

# 安装 PostgreSQL (macOS)
install_postgres_macos() {
    echo -e "${YELLOW}📦 在 macOS 上安装 PostgreSQL...${NC}"
    if command -v brew &> /dev/null; then
        brew install postgresql@16
        brew services start postgresql@16
        echo -e "${GREEN}✅ PostgreSQL 安装并启动成功${NC}"
    else
        echo -e "${RED}❌ 请先安装 Homebrew: https://brew.sh/${NC}"
        exit 1
    fi
}

# 安装 PostgreSQL (Ubuntu/Debian)
install_postgres_ubuntu() {
    echo -e "${YELLOW}📦 在 Ubuntu/Debian 上安装 PostgreSQL...${NC}"
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    echo -e "${GREEN}✅ PostgreSQL 安装并启动成功${NC}"
}

# 安装 PostgreSQL (CentOS/RHEL)
install_postgres_centos() {
    echo -e "${YELLOW}📦 在 CentOS/RHEL 上安装 PostgreSQL...${NC}"
    sudo yum install -y postgresql-server postgresql-contrib
    sudo postgresql-setup initdb
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    echo -e "${GREEN}✅ PostgreSQL 安装并启动成功${NC}"
}

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# 设置数据库
setup_database() {
    echo -e "${YELLOW}🗄️  设置数据库...${NC}"

    # 检查 PostgreSQL 服务是否运行
    if ! pg_isready -q; then
        echo -e "${RED}❌ PostgreSQL 服务未运行${NC}"
        echo "请手动启动 PostgreSQL 服务"
        exit 1
    fi

    echo -e "${GREEN}✅ PostgreSQL 服务正在运行${NC}"

    # 创建数据库和用户
    echo -e "${YELLOW}👤 创建数据库用户和数据库...${NC}"

    # 检查用户是否已存在
    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='wewe_rss'" | grep -q 1; then
        echo -e "${YELLOW}⚠️  用户 wewe_rss 已存在${NC}"
    else
        sudo -u postgres psql -c "CREATE USER wewe_rss WITH PASSWORD '123456';"
        echo -e "${GREEN}✅ 用户 wewe_rss 创建成功${NC}"
    fi

    # 检查数据库是否已存在
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "wewe-rss"; then
        echo -e "${YELLOW}⚠️  数据库 wewe-rss 已存在${NC}"
    else
        sudo -u postgres psql -c "CREATE DATABASE \"wewe-rss\" OWNER wewe_rss;"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"wewe-rss\" TO wewe_rss;"
        echo -e "${GREEN}✅ 数据库 wewe-rss 创建成功${NC}"
    fi
}

# 配置环境变量
setup_env() {
    echo -e "${YELLOW}⚙️  配置环境变量...${NC}"

    ENV_FILE="apps/server/.env.local"

    if [ -f "$ENV_FILE" ]; then
        echo -e "${YELLOW}⚠️  环境变量文件已存在，将备份为 .env.local.backup${NC}"
        cp "$ENV_FILE" "$ENV_FILE.backup"
    fi

    cat > "$ENV_FILE" << EOF
# PostgreSQL 配置
DATABASE_PROVIDER="postgresql"
DATABASE_URL="postgresql://wewe_rss:123456@127.0.0.1:5432/wewe-rss?schema=public&connect_timeout=30&pool_timeout=30"

# 服务配置
HOST=0.0.0.0
PORT=4000

# 访问授权码
AUTH_CODE=123567

# 每分钟最大请求次数
MAX_REQUEST_PER_MINUTE=60

# 自动提取全文内容
FEED_MODE="fulltext"

# nginx 转发后的服务端地址
SERVER_ORIGIN_URL=http://localhost:4000

# 定时更新订阅源Cron表达式
CRON_EXPRESSION="35 5,17 * * *"

# 是否开启正文html清理
ENABLE_CLEAN_HTML=false

# 连续更新延迟时间(秒)
UPDATE_DELAY_TIME=60

# 读书转发服务，不需要修改
PLATFORM_URL="https://weread.111965.xyz"
EOF

    echo -e "${GREEN}✅ 环境变量配置完成: $ENV_FILE${NC}"
}

# 初始化 Prisma
setup_prisma() {
    echo -e "${YELLOW}🔧 初始化 Prisma...${NC}"

    # 安装依赖
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}📦 安装项目依赖...${NC}"
        pnpm install
    fi

    # 生成 Prisma 客户端
    cd apps/server
    npx prisma generate
    echo -e "${GREEN}✅ Prisma 客户端生成完成${NC}"

    # 运行迁移
    echo -e "${YELLOW}🔄 运行数据库迁移...${NC}"
    npx prisma migrate deploy
    echo -e "${GREEN}✅ 数据库迁移完成${NC}"

    cd ../..
}

# 测试连接
test_connection() {
    echo -e "${YELLOW}🔗 测试数据库连接...${NC}"

    cd apps/server
    if PGPASSWORD=123456 psql -h 127.0.0.1 -p 5432 -U wewe_rss -d wewe-rss -c "SELECT version();" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 数据库连接测试成功${NC}"
    else
        echo -e "${RED}❌ 数据库连接测试失败${NC}"
        echo "请检查数据库配置和用户权限"
        cd ../..
        exit 1
    fi
    cd ../..
}

# 显示启动说明
show_startup_instructions() {
    echo ""
    echo -e "${GREEN}🎉 本地 PostgreSQL 设置完成！${NC}"
    echo ""
    echo -e "${BLUE}📋 下一步操作:${NC}"
    echo ""
    echo "1. 启动开发服务器:"
    echo "   ${YELLOW}pnpm run build:web && pnpm dev${NC}"
    echo ""
    echo "2. 或者启动生产服务器:"
    echo "   ${YELLOW}pnpm run -r build && pnpm run start:server${NC}"
    echo ""
    echo "3. 访问应用:"
    echo "   ${BLUE}前端: http://localhost:5173${NC}"
    echo "   ${BLUE}后端: http://localhost:4000${NC}"
    echo ""
    echo "4. 如果需要停止 PostgreSQL 服务:"
    echo "   ${YELLOW}# macOS${NC}"
    echo "   brew services stop postgresql@16"
    echo "   ${YELLOW}# Ubuntu/Debian${NC}"
    echo "   sudo systemctl stop postgresql"
    echo ""
    echo "5. 数据库连接信息:"
    echo "   ${BLUE}主机: 127.0.0.1${NC}"
    echo "   ${BLUE}端口: 5432${NC}"
    echo "   ${BLUE}数据库: wewe-rss${NC}"
    echo "   ${BLUE}用户: wewe_rss${NC}"
    echo "   ${BLUE}密码: 123456${NC}"
    echo ""
}

# 主函数
main() {
    # 检查 PostgreSQL 安装
    if ! check_postgres; then
        echo -e "${YELLOW}🔍 检测操作系统...${NC}"
        OS=$(detect_os)

        case $OS in
            "macos")
                install_postgres_macos
                ;;
            "ubuntu"|"debian")
                install_postgres_ubuntu
                ;;
            "centos"|"rhel"|"fedora")
                install_postgres_centos
                ;;
            *)
                echo -e "${RED}❌ 不支持的操作系统: $OS${NC}"
                echo "请手动安装 PostgreSQL: https://www.postgresql.org/download/"
                exit 1
                ;;
        esac

        # 等待 PostgreSQL 启动
        echo -e "${YELLOW}⏳ 等待 PostgreSQL 启动...${NC}"
        sleep 5
    fi

    # 设置数据库
    setup_database

    # 配置环境变量
    setup_env

    # 初始化 Prisma
    setup_prisma

    # 测试连接
    test_connection

    # 显示启动说明
    show_startup_instructions
}

# 检查是否有 root 权限（用于创建用户和数据库）
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}❌ 请不要以 root 用户运行此脚本${NC}"
    echo "使用普通用户运行，脚本会在需要时请求 sudo 权限"
    exit 1
fi

main "$@"