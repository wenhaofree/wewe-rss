#!/bin/sh

# 等待数据库连接
echo "Waiting for database connection..."
while ! nc -z host.docker.internal 5432; do
  sleep 1
done
echo "Database connected!"

# 复制PostgreSQL schema
cp /app/prisma/schema.postgresql.prisma /app/prisma/schema.prisma

# 生成Prisma客户端
cd /app && npx prisma generate

# 运行数据库迁移（如果需要）
cd /app && npx prisma db push

# 启动应用
cd /app && node dist/main.js