# 一起听歌吧 · 多房间点歌房

基于 Spring Boot 的多房间同步听歌应用：多人进同一个房间，点歌、聊天、投票切歌，所有人的播放进度保持同步。
前端（Vue 3 + Vuetify）已内置在后端 jar 中，由后端同源提供，**一条 `docker compose up -d` 就能跑起整套服务**。

支持的音源：**网易云音乐** 与 **QQ 音乐**（咪咕、酷我/虾米已在代码中移除）。

## 项目背景

此版本是多房间版，在 jusic-serve 的基础上演进：[Jusic-serve](https://github.com/JumpAlang/Jusic-serve)

* 后端：本项目
* 前端：[Jusic-ui](https://github.com/JumpAlang/Jusic-ui/tree/jusic-ui-houses)
* 小程序：[Jusic-mini](https://github.com/JumpAlang/Jusic_mini)

---

# 快速开始

## 1. 准备

只需要 **Docker** 与 **Docker Compose**（Docker 20.10+ 自带 `docker compose` 子命令）。

**只需要两个文件**——镜像已发布到 Docker Hub，不必 clone 仓库，也不必本地构建：

```bash
curl -O https://raw.githubusercontent.com/Xuemantou/Jusic-Serve-Houses/jusic_serve_houses/docker-compose.yml
curl -O https://raw.githubusercontent.com/Xuemantou/Jusic-Serve-Houses/jusic_serve_houses/.env.example
```

要改代码、自己构建镜像，再 clone 整个仓库，见文末[从源码构建](#从源码构建)。

## 2. 配置

```bash
cp .env.example .env
vi .env
```

至少要改这几项（详见 [.env.example](.env.example) 里的逐项说明）：

| 变量 | 说明 |
|---|---|
| `QQ` | 你的 QQ 号。灌 QQ 会员 cookie 时，cookie 里的 uin 必须等于这个值，否则不生效 |
| `APIPWD` | 接口认证密码（用户名固定 `admin`） |
| `RoleRootPassword` | 管理员提权密码：聊天框输入「root 这个密码」 |
| `ServerJUrl` | @管理员 的微信推送地址。**必须改成自己的**，否则消息会发到项目作者那里 |
| `WyAccount` | 网易账号名。它同时是 Redis 里网易 cookie 的存储键名，定了之后不要再改 |
| `QqCookie` | QQ 音乐会员 cookie，**决定 VIP 歌能否完整播放**，填法见 [灌入音源登录态](#灌入音源登录态重要) |
| `WyCookie` | 网易云会员 cookie，同上 |

> ⚠️ `.env` 由 docker compose 逐行解析，**注释必须单独成行**。
> 写成 `HouseSize=128  # 房间数上限` 会把「# 房间数上限」一起当成值传给容器。

> `RedisHost` 与 `MusicApi` 不用配，compose 已固定指向容器网络内的 `redis` 与 `music-api`。

## 3. 启动

```bash
docker compose up -d
docker compose ps          # 三个服务都应是 Up；jusic-redis 显示 healthy
```

首次会从 Docker Hub 拉取约 1GB 镜像，耗时取决于网速；镜像拉完后约 30 秒起服务。
之后再启动都是秒级。

## 4. 访问

浏览器打开 **<http://localhost:8080>**

---

# 灌入音源登录态（重要）

这一步决定 **VIP 曲目能不能完整播放**。不填也能用，但付费歌曲只会播放 30 秒试听。

两个音源的 cookie 都统一填在 `.env` 里，`docker compose up -d` 启动时自动灌入。
**换 cookie 只需改 `.env` 再 `up -d`，不用 curl 任何接口，容器重建也不会丢。**

## 1. 抓 QQ 音乐 cookie

1. 浏览器登录 <https://y.qq.com>（用你的会员账号）
2. F12 →「网络 / Network」→ 刷新页面 → 点最上面那条请求
3. 「请求头 / Request Headers」→ 找到 `Cookie:` 这一行，**复制整行的值**
   （别用 `document.cookie`，它拿不到 HttpOnly 字段，会缺 `qm_keyst`）
4. 粘进 `.env`：

```ini
QQ=你的QQ号
QqCookie=粘贴整串 cookie
```

⚠️ cookie 里的 `uin` **必须等于** `QQ`。不一致时启动日志会打印 `QqCookie 已忽略`，VIP 依然取不到链接。

## 2. 抓网易云 cookie

1. 浏览器登录 <https://music.163.com>（用你的会员账号）
2. F12 →「网络」→ 刷新页面 → 点最上面那条 HTML 请求
3. 「请求头 → `Cookie:`」整串复制（**必须含 `MUSIC_U=`**，末尾分号可带可不带）
4. 粘进 `.env`：

```ini
WyAccount=你的网易账号名
WyCookie=粘贴整串 cookie
```

⚠️ `WyAccount` 同时是后端 Redis 里网易 cookie 的存储键名，**定了之后别再改**；
改了必须重新填一次 `WyCookie`，否则读不到旧登录态。

## 3. 启动并验证

```bash
docker compose up -d
docker compose logs music-api | grep QqCookie     # 应打印：已从 QqCookie 环境变量注入 QQ 登录态：uin=xxx
docker compose logs jusic | grep WyCookie         # 应打印：网易 cookie 已从 WyCookie 环境变量灌入
```

验证 QQ 是否生效（返回带 `vkey` 的地址即为成功）：

```bash
curl -s "http://localhost:3300/song/urls?id=0039MnYb0qxYhV"
```

网易没有单曲验证接口，直接播一首 VIP 歌确认能放完整时长即可。
**cookie 失效时会自动告警**：取歌时若发现返回的是试听片段，后端会记 ERROR 日志
`⚠️ 网易返回 30 秒试听片段`，并在配置了 `ServerJUrl` 时推一条微信通知（同一状态每小时最多一次）。
看到告警就重抓一次 cookie 填回 `.env`。

## 说明

* QQ 登录态另有一份落盘缓存在 `qq-data` 数据卷、网易的落在 Redis 的 `jusic_retain_key_*`。
  **`.env` 里填了就以 `.env` 为准**（每次启动覆盖），留空才沿用缓存里的旧值。
* 除 `.env` 之外也保留一次性灌入接口，仅用于调试：
  * QQ：`curl -X POST "http://localhost:3300/user/setCookie" --data-urlencode "data=<cookie>"`
  * 网易（需 Basic 认证，用户名固定 `admin`）：
    `curl -u admin:你的APIPWD -X POST "http://localhost:8080/netease/setCookiePost" -H "Content-Type: application/json" -d '{"cookie":"<cookie>"}'`

---

# 使用

在聊天窗口发送指令即可。

**普通用户**

| 指令 | 说明 |
|---|---|
| `点歌 关键字` | 点一首歌（也支持网易云音乐 ID） |
| `投票切歌` | 发起切歌投票，超过在线人数 30% 时生效 |
| `设置昵称 名字` | 修改自己的显示昵称（仅当前客户端） |
| `删除音乐 歌曲名` | 删除自己点错的歌 |

**管理员**（先用 `root 密码` 提权，密码见 `RoleRootPassword`）

| 指令 | 说明 |
|---|---|
| `置顶音乐 音乐名` / `删除音乐 音乐名` | 调整播放列表 |
| `拉黑用户 用户id` / `漂白用户 用户id` | 用户黑名单 |
| `拉黑音乐 音乐id` / `漂白音乐 音乐id` | 音乐黑名单 |
| `点赞模式` / `退出点赞模式` | 按点赞数优先播放 |
| `禁止点歌` / `启用点歌`、`禁止切歌` / `启用切歌` | 开关点歌 / 切歌 |
| `清空列表` / `音乐黑名单` / `用户黑名单` | 批量操作 |
| `调整音量 数值` / `投票切歌率 数值` | 房间参数 |
| `倒计时退出 分钟数` / `取消退出` | 定时关闭房间 |
| `修改密码 新密码` / `修改root密码 新密码` | 修改管理密码 |
| `@管理员 内容` | 向管理员发送消息（需配置 `ServerJUrl` 才能收到推送） |

完整指令共 44 条，见前端 `src/composables/useSocket.ts` 的 `sendHandler`。

---

# 日志与排障

## 日志位置

| 文件 | 内容 |
|---|---|
| `logs/common-all.log` | 全量业务日志（INFO 以上），带类名、方法名与行号，**排查首选** |
| `logs/common-error.log` | 仅 ERROR |
| `docker compose logs -f jusic` | 容器标准输出（含框架启动信息） |
| `docker compose logs -f music-api` | 两个音源服务的输出 |

日志目录已挂载到宿主机，可直接 `tail -f logs/common-all.log`。

## 常见问题

| 现象 | 原因与处理 |
|---|---|
| 页面能打开但一点歌就失败 | 先看 `logs/common-error.log`。多为音乐 API 未就绪或音源网络异常 |
| 歌能播但只有 30 秒 | 网易 cookie 失效。日志里会有「网易返回 30 秒试听片段」的 ERROR |
| QQ 曲目取不到播放地址 | cookie 未灌，或 cookie 里的 uin 与 `.env` 的 `QQ` 不一致 |
| 日志里 `刷新未返回新 cookie` | 网易登录态可能已过期，重新灌一次 cookie |
| 后端报 `Unable to connect to redis` | `redis` 容器没起来，看 `docker compose ps` |
| 修改 `.env` 后不生效 | 需要 `docker compose up -d`（会重建受影响的服务） |

---

# 从源码构建

## 前端 → 后端 jar

前端是独立仓库（本地目录 `Jusic-ui/`，Vue 3 + Vuetify）。它的产物需要先复制进后端资源目录，
再打包 jar：

```bash
cd Jusic-ui
npm install && npm run build
rm -rf ../src/main/resources/static/assets ../src/main/resources/static/index.html
cp -r dist/* ../src/main/resources/static/

cd ..
mvn -Dmaven.repo.local=.m2-repo clean package -DskipTests
# 产物：target/jusic-serve.jar
```

## 后端镜像（含前端）

构建成与 compose 里同名的 tag，`docker compose up -d` 就会直接用本地这份，不再去拉取：

```bash
docker build -t xuemantou05/jusic-serve-houses:latest .
docker compose up -d jusic
```

> 若你 fork 成了自己的仓库，建议把镜像名换成自己的 Docker Hub 用户名，
> 并同步修改 `docker-compose.yml` 里 `jusic` 与 `music-api` 的 `image:`。

## 音乐 API 镜像（网易 + QQ 二合一）

构建上下文在 `.docker-build/`，两个音源项目的源码已随仓库提供，直接构建即可：

```bash
docker build -t xuemantou05/jusic-music-api:latest .docker-build
docker compose up -d music-api
```

要同步上游新版时再自行拉取比对（`.docker-build/` 里有本项目的本地改动，需手工合并）：

```bash
git clone --depth 1 https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced.git /tmp/api-enhanced
git clone --depth 1 https://github.com/jsososo/QQMusicApi.git /tmp/QQMusicApi
```

镜像用 supervisord 在一个容器内托管两个 Node 进程（网易 `:3000`、QQ `:3300`），
两个项目的依赖安装方式不同（网易用 pnpm + 自带 lockfile，QQ 用 yarn 1.x），
具体坑位与处理都写在 `.docker-build/Dockerfile` 的注释里。

## 推送镜像到 Docker Hub

仓库根目录的 `push-images.sh` 可一键打标签并推送：

```bash
docker login
./push-images.sh <你的DockerHub用户名>
```

推送后把 `docker-compose.yml` 里的 `image:` 换成远端地址即可供他人直接拉取。

---

## 在线预览

Jusic：[Jusic 点歌台](http://music.alang.run)

## 打赏请我喝奶茶

[打赏](http://www.alang.run/sponsor)

## 相关项目

* JusicServe:[JusicServe](https://github.com/hanhuoer/Jusic-serve)
* Jusic-ui:[Jusic-ui](https://github.com/hanhuoer/Jusic-ui)
* 网易云音乐 api:[NeteaseCloudMusicApiEnhanced/api-enhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced)
* QQ 音乐 api:[jsososo/QQMusicApi](https://github.com/jsososo/QQMusicApi)
