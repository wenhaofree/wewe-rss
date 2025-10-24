#!/bin/bash

# MySQL 到 PostgreSQL 迁移脚本
# 用于将现有的 MySQL 数据迁移到 PostgreSQL

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 MySQL 到 PostgreSQL 迁移脚本${NC}"
echo "=================================="

# 检查必要工具
check_tool() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ 未找到 $1 工具${NC}"
        return 1
    else
        echo -e "${GREEN}✅ $1 工具已安装${NC}"
        return 0
    fi
}

echo -e "${YELLOW}🔍 检查必要工具...${NC}"
TOOLS=("mysql" "psql" "node" "npm")
for tool in "${TOOLS[@]}"; do
    check_tool $tool
done

# 配置文件路径
MYSQL_ENV_FILE=".env.mysql"
POSTGRES_ENV_FILE=".env.postgresql"

echo ""
echo -e "${YELLOW}📝 配置数据库连接信息${NC}"

# MySQL 配置
echo "MySQL 配置:"
read -p "MySQL 主机 [localhost]: " MYSQL_HOST
MYSQL_HOST=${MYSQL_HOST:-localhost}

read -p "MySQL 端口 [3306]: " MYSQL_PORT
MYSQL_PORT=${MYSQL_PORT:-3306}

read -p "MySQL 数据库名 [wewe-rss]: " MYSQL_DB
MYSQL_DB=${MYSQL_DB:-wewe-rss}

read -p "MySQL 用户名 [root]: " MYSQL_USER
MYSQL_USER=${MYSQL_USER:-root}

read -s -p "MySQL 密码: " MYSQL_PASSWORD
echo ""

# PostgreSQL 配置
echo ""
echo "PostgreSQL 配置:"
read -p "PostgreSQL 主机 [localhost]: " PG_HOST
PG_HOST=${PG_HOST:-localhost}

read -p "PostgreSQL 端口 [5432]: " PG_PORT
PG_PORT=${PG_PORT:-5432}

read -p "PostgreSQL 数据库名 [wewe-rss]: " PG_DB
PG_DB=${PG_DB:-wewe-rss}

read -p "PostgreSQL 用户名 [wewe_rss]: " PG_USER
PG_USER=${PG_USER:-wewe_rss}

read -s -p "PostgreSQL 密码: " PG_PASSWORD
echo ""

# 生成环境变量文件
generate_env_files() {
    echo -e "${YELLOW}📝 生成环境变量文件...${NC}"

    # MySQL 环境变量
    cat > $MYSQL_ENV_FILE << EOF
DATABASE_PROVIDER="mysql"
DATABASE_URL="mysql://$MYSQL_USER:$MYSQL_PASSWORD@$MYSQL_HOST:$MYSQL_PORT/$MYSQL_DB"
EOF

    # PostgreSQL 环境变量
    cat > $POSTGRES_ENV_FILE << EOF
DATABASE_PROVIDER="postgresql"
DATABASE_URL="postgresql://$PG_USER:$PG_PASSWORD@$PG_HOST:$PG_PORT/$PG_DB?schema=public&connect_timeout=30&pool_timeout=30"
EOF

    echo -e "${GREEN}✅ 环境变量文件已生成${NC}"
}

# 测试数据库连接
test_connections() {
    echo -e "${YELLOW}🔗 测试数据库连接...${NC}"

    # 测试 MySQL
    if mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT 1;" $MYSQL_DB > /dev/null 2>&1; then
        echo -e "${GREEN}✅ MySQL 连接成功${NC}"
    else
        echo -e "${RED}❌ MySQL 连接失败${NC}"
        exit 1
    fi

    # 测试 PostgreSQL
    if PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DB -c "SELECT 1;" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PostgreSQL 连接成功${NC}"
    else
        echo -e "${RED}❌ PostgreSQL 连接失败${NC}"
        exit 1
    fi
}

# 数据迁移
migrate_data() {
    echo -e "${YELLOW}🔄 开始数据迁移...${NC}"

    # 临时目录
    TEMP_DIR=$(mktemp -d)
    echo "临时目录: $TEMP_DIR"

    # 导出 MySQL 数据
    echo -e "${BLUE}📤 导出 MySQL 数据...${NC}"

    # 导出 accounts 表
    mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DB -e "SELECT * FROM accounts;" > $TEMP_DIR/accounts.csv
    # 导出 feeds 表
    mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DB -e "SELECT * FROM feeds;" > $TEMP_DIR/feeds.csv
    # 导出 articles 表
    mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DB -e "SELECT * FROM articles;" > $TEMP_DIR/articles.csv

    echo -e "${GREEN}✅ MySQL 数据导出完成${NC}"

    # 切换到 PostgreSQL schema 并生成客户端
    echo -e "${BLUE}🔄 切换到 PostgreSQL 配置...${NC}"
    cp $POSTGRES_ENV_FILE .env.local

    # 生成 PostgreSQL Prisma 客户端
    DATABASE_PROVIDER="postgresql" DATABASE_URL="postgresql://$PG_USER:$PG_PASSWORD@$PG_HOST:$PG_PORT/$PG_DB" npx prisma generate

    # 运行迁移
    DATABASE_PROVIDER="postgresql" DATABASE_URL="postgresql://$PG_USER:$PG_PASSWORD@$PG_HOST:$PG_PORT/$PG_DB" npx prisma migrate deploy

    echo -e "${GREEN}✅ PostgreSQL 准备完成${NC}"

    # 创建数据导入脚本
    cat > $TEMP_DIR/import_data.js << EOF
const { PrismaClient } = require('@prisma/client');
const fs = require('fs');
const path = require('path');

const prisma = new PrismaClient();

async function importCSVData() {
  try {
    console.log('🔄 开始导入数据...');

    // 导入 accounts
    const accountsData = fs.readFileSync(path.join(__dirname, 'accounts.csv'), 'utf8')
      .split('\n')
      .filter(line => line.trim())
      .slice(1) // 跳过标题行
      .map(line => {
        const [id, token, name, status, created_at, updated_at] = line.split('\t');
        return {
          id: id.trim(),
          token: token.trim(),
          name: name.trim(),
          status: parseInt(status),
          createdAt: new Date(created_at),
          updatedAt: updated_at && updated_at.trim() !== 'NULL' ? new Date(updated_at) : null
        };
      });

    if (accountsData.length > 0) {
      await prisma.account.createMany({ data: accountsData });
      console.log(\`✅ 导入 \${accountsData.length} 条 accounts 记录\`);
    }

    // 导入 feeds
    const feedsData = fs.readFileSync(path.join(__dirname, 'feeds.csv'), 'utf8')
      .split('\n')
      .filter(line => line.trim())
      .slice(1)
      .map(line => {
        const [id, mp_name, mp_cover, mp_intro, status, sync_time, update_time, created_at, updated_at, has_history] = line.split('\t');
        return {
          id: id.trim(),
          mpName: mp_name.trim(),
          mpCover: mp_cover.trim(),
          mpIntro: mp_intro.trim(),
          status: parseInt(status),
          syncTime: parseInt(sync_time),
          updateTime: parseInt(update_time),
          createdAt: new Date(created_at),
          updatedAt: updated_at && updated_at.trim() !== 'NULL' ? new Date(updated_at) : null,
          hasHistory: has_history && has_history.trim() !== 'NULL' ? parseInt(has_history) : 1
        };
      });

    if (feedsData.length > 0) {
      await prisma.feed.createMany({ data: feedsData });
      console.log(\`✅ 导入 \${feedsData.length} 条 feeds 记录\`);
    }

    // 导入 articles (分批处理)
    const articlesLines = fs.readFileSync(path.join(__dirname, 'articles.csv'), 'utf8')
      .split('\n')
      .filter(line => line.trim())
      .slice(1);

    const batchSize = 1000;
    for (let i = 0; i < articlesLines.length; i += batchSize) {
      const batch = articlesLines.slice(i, i + batchSize);
      const articlesData = batch.map(line => {
        const [id, mp_id, title, pic_url, publish_time, created_at, updated_at] = line.split('\t');
        return {
          id: id.trim(),
          mpId: mp_id.trim(),
          title: title.trim(),
          picUrl: pic_url.trim(),
          publishTime: parseInt(publish_time),
          createdAt: new Date(created_at),
          updatedAt: updated_at && updated_at.trim() !== 'NULL' ? new Date(updated_at) : null
        };
      });

      if (articlesData.length > 0) {
        await prisma.article.createMany({ data: articlesData });
        console.log(\`✅ 导入批次 \${Math.floor(i/batchSize) + 1}: \${articlesData.length} 条 articles 记录\`);
      }
    }

    console.log('🎉 数据导入完成！');

  } catch (error) {
    console.error('❌ 导入失败:', error);
  } finally {
    await prisma.\$disconnect();
  }
}

importCSVData();
EOF

    # 运行数据导入脚本
    echo -e "${BLUE}📥 导入数据到 PostgreSQL...${NC}"
    cd $TEMP_DIR && DATABASE_PROVIDER="postgresql" DATABASE_URL="postgresql://$PG_USER:$PG_PASSWORD@$PG_HOST:$PG_PORT/$PG_DB" node import_data.js

    echo -e "${GREEN}✅ 数据导入完成${NC}"

    # 清理临时文件
    rm -rf $TEMP_DIR
}

# 确认迁移
confirm_migration() {
    echo ""
    echo -e "${YELLOW}⚠️  警告: 即将开始数据迁移${NC}"
    echo "此操作将:"
    echo "1. 从 MySQL 导出数据"
    echo "2. 导入到 PostgreSQL 数据库"
    echo ""
    read -p "确认继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}❌ 迁移已取消${NC}"
        exit 1
    fi
}

# 主函数
main() {
    confirm_migration
    generate_env_files
    test_connections
    migrate_data

    echo ""
    echo -e "${GREEN}🎉 迁移完成！${NC}"
    echo ""
    echo "下一步:"
    echo "1. 使用新的环境变量: cp $POSTGRES_ENV_FILE .env.local"
    echo "2. 启动应用: npm run dev"
    echo ""
    echo "如果遇到问题，请检查:"
    echo "- 数据库连接配置"
    echo "- 数据完整性"
    echo "- 应用日志"
}

main "$@"