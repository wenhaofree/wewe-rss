<div align="center">
<img src="https://raw.githubusercontent.com/cooderl/wewe-rss/main/assets/logo.png" width="80" alt="预览"/>

# [WeWe RSS](https://github.com/cooderl/wewe-rss)

更优雅的微信公众号订阅方式。

![主界面](https://raw.githubusercontent.com/cooderl/wewe-rss/main/assets/preview1.png)
</div>

## ✨ 功能

- v2.x版本使用全新接口，更加稳定
- 支持微信公众号订阅（基于微信读书）
- 获取公众号历史发布文章
- 后台自动定时更新内容
- 微信公众号RSS生成（支持`.atom`、`.rss`、`.json`格式)
- 支持全文内容输出，让阅读无障碍
- 所有订阅源导出OPML

### 高级功能

- **标题过滤**：支持通过`/feeds/all.(json|rss|atom)`接口和`/feeds/:feed`对标题进行过滤
  ```
  {{ORIGIN_URL}}/feeds/all.atom?title_include=张三
  {{ORIGIN_URL}}/feeds/MP_WXS_123.json?limit=30&title_include=张三|李四|王五&title_exclude=张三丰|赵六
  ```

- **手动更新**：支持通过`/feeds/:feed`接口触发单个feedid更新
  ```
  {{ORIGIN_URL}}/feeds/MP_WXS_123.rss?update=true
  ```

## 🚀 部署

### 一键部署

- [Deploy on Zeabur](https://zeabur.com/templates/DI9BBD)
- [Railway](https://railway.app/)
- [Hugging Face部署参考](https://github.com/cooderl/wewe-rss/issues/32)

### Docker Compose 部署

参考以下配置文件：
- [docker-compose.yml](https://github.com/cooderl/wewe-rss/blob/main/docker-compose.yml) - MySQL 数据库
- [docker-compose.sqlite.yml](https://github.com/cooderl/wewe-rss/blob/main/docker-compose.sqlite.yml) - SQLite 数据库
- [docker-compose.postgresql.yml](https://github.com/cooderl/wewe-rss/blob/main/docker-compose.postgresql.yml) - PostgreSQL 数据库

### Docker 命令启动

#### MySQL (推荐)

1. 创建docker网络
   ```sh
   docker network create wewe-rss
   ```

2. 启动 MySQL 数据库
   ```sh
   docker run -d \
     --name db \
     -e MYSQL_ROOT_PASSWORD=123456 \
     -e TZ='Asia/Shanghai' \
     -e MYSQL_DATABASE='wewe-rss' \
     -v db_data:/var/lib/mysql \
     --network wewe-rss \
     mysql:8.3.0 --mysql-native-password=ON
   ```

3. 启动 Server
   ```sh
   docker run -d \
     --name wewe-rss \
     -p 4000:4000 \
     -e DATABASE_URL='mysql://root:123456@db:3306/wewe-rss?schema=public&connect_timeout=30&pool_timeout=30&socket_timeout=30' \
     -e AUTH_CODE=123567 \
     --network wewe-rss \
     cooderl/wewe-rss:latest
   ```

[Nginx配置参考](https://raw.githubusercontent.com/cooderl/wewe-rss/main/assets/nginx.example.conf)

#### PostgreSQL (推荐)

使用 Docker Compose 启动：
```sh
docker-compose -f docker-compose.postgresql.yml up -d
```

或手动启动：

1. 创建docker网络
   ```sh
   docker network create wewe-rss-postgres
   ```

2. 启动 PostgreSQL 数据库
   ```sh
   docker run -d \
     --name postgres-db \
     -e POSTGRES_USER=wewe_rss \
     -e POSTGRES_PASSWORD=123456 \
     -e POSTGRES_DB=wewe-rss \
     -e TZ='Asia/Shanghai' \
     -v postgres_data:/var/lib/postgresql/data \
     -p 15432:5432 \
     --network wewe-rss-postgres \
     postgres:16-alpine
   ```

3. 启动 Server
   ```sh
   docker run -d \
     --name wewe-rss-postgres \
     -p 4000:4000 \
     -e DATABASE_PROVIDER=postgresql \
     -e DATABASE_URL='postgresql://wewe_rss:123456@postgres-db:5432/wewe-rss?schema=public&connect_timeout=30&pool_timeout=30' \
     -e AUTH_CODE=123567 \
     --network wewe-rss-postgres \
     cooderl/wewe-rss:latest
   ```

#### SQLite (不推荐)

```sh
docker run -d \
  --name wewe-rss \
  -p 4000:4000 \
  -e DATABASE_TYPE=sqlite \
  -e AUTH_CODE=123567 \
  -v $(pwd)/data:/app/data \
  cooderl/wewe-rss-sqlite:latest
```

### 本地部署

使用 `pnpm install && pnpm run -r build && pnpm run start:server` 命令 (可配合 pm2 守护进程)

#### PostgreSQL 方式 (推荐)

**🚀 快速设置 (推荐)**

使用自动化脚本一键设置：

```shell
# 运行快速设置脚本
./scripts/setup-local-postgres.sh
```

脚本会自动完成：
- 检测并安装 PostgreSQL (支持 macOS、Ubuntu、CentOS)
- 创建数据库和用户
- 配置环境变量
- 初始化 Prisma 和数据库迁移
- 测试数据库连接

**手动设置步骤**：

**步骤 1: 安装并启动 PostgreSQL**

```shell
# macOS 使用 Homebrew
brew install postgresql@16
brew services start postgresql@16

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
sudo systemctl start postgresql

# CentOS/RHEL
sudo yum install postgresql-server postgresql-contrib
sudo postgresql-setup initdb
sudo systemctl start postgresql
```

**步骤 2: 创建数据库和用户**

```shell
# 连接到 PostgreSQL
sudo -u postgres psql

# 在 PostgreSQL 命令行中执行
CREATE USER wewe_rss WITH PASSWORD '123456';
CREATE DATABASE "wewe-rss" OWNER wewe_rss;
GRANT ALL PRIVILEGES ON DATABASE "wewe-rss" TO wewe_rss;
\q
```

**步骤 3: 配置环境变量**

```shell
# 进入服务端目录
cd apps/server

# 复制环境变量模板
cp .env.local.example .env.local

# 编辑环境变量文件
nano .env.local
```

在 `.env.local` 中设置：
```bash
# PostgreSQL 配置
DATABASE_PROVIDER="postgresql"
DATABASE_URL="postgresql://wewe_rss:123456@127.0.0.1:5432/wewe-rss?schema=public&connect_timeout=30&pool_timeout=30"

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
```

**数据库创建：**
```shell
cd app/server

DATABASE_URL="postgresql://root:fuwenhao@127.0.0.1:5432/spider_gzh_db?schema=public&connect_timeout=30&pool_timeout=30" npx prisma db push

验证表是否创建
```

**步骤 4: 初始化数据库**

```shell
# 回到项目根目录
cd ../..

# 安装依赖
pnpm install

# 生成 Prisma 客户端
cd apps/server
npx prisma generate

# 运行数据库迁移
npx prisma migrate dev --name init

# 或者使用现有迁移
npx prisma migrate deploy

# 回到项目根目录
cd ../..
```

**步骤 5: 构建并运行**

```shell
# 构建项目
pnpm run -r build

# 启动服务
pnpm run start:server
```

#### SQLite 方式

**详细步骤**：

```shell
# 需要提前声明环境变量,因为prisma会根据环境变量生成对应的数据库连接
export DATABASE_PROVIDER="sqlite"
export DATABASE_URL="file:../data/wewe-rss.db"
# 删除mysql相关文件,避免prisma生成mysql连接
rm -rf apps/server/prisma
mv apps/server/prisma-sqlite apps/server/prisma
# 生成prisma client
npx prisma generate --schema apps/server/prisma/schema.prisma
# 生成数据库表
npx prisma migrate deploy --schema apps/server/prisma/schema.prisma
# 构建并运行
pnpm run -r build
pnpm run start:server
```

#### 本地开发模式

```shell
# 1. 安装 nodejs 20 和 pnpm
# 2. 修改环境变量：
cp ./apps/web/.env.local.example ./apps/web/.env
cp ./apps/server/.env.local.example ./apps/server/.env

# 3. 启动数据库 (PostgreSQL)
# 确保 PostgreSQL 服务运行并且数据库已创建

# 4. 执行开发命令
pnpm install && pnpm run build:web && pnpm dev
```

⚠️ **注意：此命令仅用于本地开发，不要用于部署！**
- 前端访问 `http://localhost:5173`
- 后端访问 `http://localhost:4000`

## ⚙️ 环境变量

| 变量名                   | 说明                                                                    | 默认值                      |
| ------------------------ | ----------------------------------------------------------------------- | --------------------------- |
| `DATABASE_PROVIDER`      | 数据库提供商，支持 `mysql`、`postgresql`、`sqlite`                      | `mysql`                     |
| `DATABASE_URL`           | **必填** 数据库地址，例如 `mysql://root:123456@127.0.0.1:3306/wewe-rss` | -                           |
| `DATABASE_TYPE`          | 数据库类型，使用 SQLite 时需填写 `sqlite` (已废弃，建议使用 DATABASE_PROVIDER) | -                           |
| `AUTH_CODE`              | 服务端接口请求授权码，空字符或不设置将不启用 (`/feeds`路径不需要)       | -                           |
| `SERVER_ORIGIN_URL`      | 服务端访问地址，用于生成RSS完整路径                                     | -                           |
| `MAX_REQUEST_PER_MINUTE` | 每分钟最大请求次数                                                      | 60                          |
| `FEED_MODE`              | 输出模式，可选值 `fulltext` (会使接口响应变慢，占用更多内存)            | -                           |
| `CRON_EXPRESSION`        | 定时更新订阅源Cron表达式                                                | `35 5,17 * * *`             |
| `UPDATE_DELAY_TIME`      | 连续更新延迟时间，减少被关小黑屋                                        | `60s`                       |
| `ENABLE_CLEAN_HTML`      | 是否开启正文html清理                                                    | `false`                     |
| `PLATFORM_URL`           | 基础服务URL                                                             | `https://weread.111965.xyz` |

### 数据库连接示例

**MySQL**:
```bash
DATABASE_PROVIDER="mysql"
DATABASE_URL="mysql://root:123456@127.0.0.1:3306/wewe-rss"
```

**PostgreSQL**:
```bash
DATABASE_PROVIDER="postgresql"
DATABASE_URL="postgresql://wewe_rss:123456@127.0.0.1:5432/wewe-rss?schema=public&connect_timeout=30&pool_timeout=30"
```

**SQLite**:
```bash
DATABASE_PROVIDER="sqlite"
DATABASE_URL="file:../data/wewe-rss.db"
```

> **注意**: 国内DNS解析问题可使用 `https://weread.965111.xyz` 加速访问

## 🔔 钉钉通知

进入 wewe-rss-dingtalk 目录按照 README.md 指引部署

## 📱 使用方式

1. 进入账号管理，点击添加账号，微信扫码登录微信读书账号。
  
   **注意不要勾选24小时后自动退出**
   
   <img width="400" src="./assets/preview2.png"/>


2. 进入公众号源，点击添加，通过提交微信公众号分享链接，订阅微信公众号。
   **添加频率过高容易被封控，等24小时解封**

   <img width="400" src="./assets/preview3.png"/>

## 🔑 账号状态说明

| 状态       | 说明                                                                |
| ---------- | ------------------------------------------------------------------- |
| 今日小黑屋 | 账号被封控，等一天恢复。账号正常时可通过重启服务/容器清除小黑屋记录 |
| 禁用       | 不使用该账号                                                        |
| 失效       | 账号登录状态失效，需要重新登录                                      |

## 💻 本地开发

1. 安装 nodejs 20 和 pnpm
2. 修改环境变量：
   ```
   cp ./apps/web/.env.local.example ./apps/web/.env
   cp ./apps/server/.env.local.example ./apps/server/.env
   ```
3. 执行 `pnpm install && pnpm run build:web && pnpm dev` 
   
   ⚠️ **注意：此命令仅用于本地开发，不要用于部署！**
4. 前端访问 `http://localhost:5173`，后端访问 `http://localhost:4000`

## ⚠️ 风险声明

为了确保本项目的持久运行，某些接口请求将通过 `weread.111965.xyz` 进行转发。请放心，该转发服务不会保存任何数据。

## ❤️ 赞助

如果觉得 WeWe RSS 项目对你有帮助，可以给我来一杯啤酒！

**PayPal**: [paypal.me/cooderl](https://paypal.me/cooderl)

**微信**:  
<img width="300" src="https://r2-assets.111965.xyz/donate-wechat.jpg" alt="Donate_WeChat.jpg">

## 👨‍💻 贡献者

<a href="https://github.com/cooderl/wewe-rss/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=cooderl/wewe-rss" />
</a>

## 🐘 PostgreSQL 设置

### 快速启动

使用提供的初始化脚本快速设置PostgreSQL：

```bash
# 运行初始化脚本
./scripts/init-postgres.sh

# 或者使用 Docker Compose
docker-compose -f docker-compose.postgresql.yml up -d
```

### 从 MySQL 迁移到 PostgreSQL

如果你正在使用MySQL并希望迁移到PostgreSQL：

```bash
# 运行迁移脚本
./scripts/migrate-to-postgres.sh
```

迁移脚本将会：
1. 导出MySQL数据
2. 创建PostgreSQL数据库结构
3. 导入数据到PostgreSQL
4. 生成新的环境变量配置

### PostgreSQL 优势

- **更好的性能**: 对于复杂查询和大数据量有更好的性能表现
- **丰富的数据类型**: 支持JSON、数组等高级数据类型
- **扩展性**: 支持多种扩展，如全文搜索、地理空间数据等
- **ACID兼容**: 完全兼容ACID特性，数据一致性更好
- **开源社区**: 活跃的开源社区和丰富的文档资源

### 故障排除

**连接问题**:
```bash
# 检查PostgreSQL服务状态
docker-compose -f docker-compose.postgresql.yml ps

# 查看日志
docker-compose -f docker-compose.postgresql.yml logs db
```

**权限问题**:
```bash
# 进入数据库容器
docker-compose -f docker-compose.postgresql.yml exec db psql -U wewe_rss -d wewe-rss

# 重新创建数据库
DROP DATABASE IF EXISTS "wewe-rss";
CREATE DATABASE "wewe-rss";
```

## 📄 License

[MIT](https://raw.githubusercontent.com/cooderl/wewe-rss/main/LICENSE) @cooderl
