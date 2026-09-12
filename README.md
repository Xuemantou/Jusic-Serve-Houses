## 使用edgeOne 全球加速，一键部署点击下方一键加速
[![使用 EdgeOne Pages 部署](https://cdnstatic.tencentcs.com/edgeone/pages/deploy.svg)](https://edgeone.ai/pages/new?repository-url=https%3A%2F%2Fgithub.com%2FJumpAlang%2FJusic-Serve-Houses%2Ftree%2Fjusic_serve_houses%2Fsrc%2Fmain%2Fresources%2Fstatic&root-directory=src%2Fmain%2Fresources&output-directory=.)

> 热烈庆祝一起听歌吧微信小程序上架成功，搜索：***灵魂自习室***

> 使用docker一键部署一起听歌吧应用，从此你也拥有了自己的点歌台，docker部署详见下方

> 一起听歌吧官方所使用服务器配置,趁双11新用户1年只要84元（建议买3年）：[阿里云ecs_t5_突发型](https://www.aliyun.com/minisite/goods?userCode=ze4tzlf9&share_source=copy_link)
> 趁双11腾讯云新用户1年只要88元（建设买3年）：[腾讯云标准型S4](https://cloud.tencent.com/act/cps/redirect?redirect=10140&cps_key=52c40793a9f078023fbc4d27eee65032&from=activity)

> 目前服务器配置比较弱鸡，经常炸机，欢迎大佬赞助。mail to me .

> 也欢迎小伙伴提交自己搭建的地址到issue,如果可以，创办个一起听歌吧联盟，把所有一起听歌吧的地址聚合在一起。分解服务器压力。

如果遇到问题可以在本项目提 issue

## 项目背景

此版本是多房间版，在jusic-serve的基础上[Jusic-serve](https://github.com/JumpAlang/Jusic-serve)

后端: 本项目

前端: [Jusic-ui](https://github.com/JumpAlang/Jusic-ui/tree/jusic-ui-houses)
小程序: [Jusic-mini](https://github.com/JumpAlang/Jusic_mini)

## docker部署
> 一起听歌吧官方所使用服务器配置,新用户有优惠价100左右：[阿里云ecs_t5_突发型](https://www.aliyun.com/minisite/goods?userCode=ze4tzlf9&share_source=copy_link)
>
1.只要nodejs音乐api接口
  请使用<https://hub.docker.com/r/jumpalang/jusic_music_api>查看说明

2.只要java后端服务
  请使用<https://hub.docker.com/r/jumpalang/jusic_serve_houses>查看说明

3.如果想整套部署

 3.1 使用根目录下的 docker-compose.yml，修改参数后执行 `docker-compose up -d`，
     浏览器访问 <http://localhost:8888>

     全部可用参数及默认值见 [.env.example](.env.example)（`java -jar` 启动时同样适用）。几个常改的：

     * `RedisHost` / `MusicApi`：非 docker 部署时填 `localhost`
     * `APIUSER` / `APIPWD`：接口认证，默认 `admin` / `123456`
     * `ServerJUrl`：被 @管理员 时的推送地址，**必须修改**，否则消息会发到作者那里
     * `RoleRootPassword`：聊天输入「root 密码」提权为管理员

 3.2 使用Jonnyan404小伙伴制作的docker
> 感谢小伙伴制作的docker <https://github.com/Jonnyan404>

`docker run -d --name music -p 8888:8888 jonnyan404/jusic`

## 安装

1. 克隆项目

   ```
   git clone https://github.com/JumpAlang/Jusic-Serve-Houses.git
   ```



2. 安装 Redis

   [Redis](https://redis.io/)

3. 安装音乐基础服务

   3.1 网易云音乐：[NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi)

   3.2 qq音乐:<https://github.com/jsososo/QQMusicApi>

   3.3 咪咕音乐：<https://github.com/JumpAlang/MiguMusicApi>

   3.4 铜钟forJusic(引入了酷我与虾米，当网易或者qq或者虾米找不到资源时，根据歌手名+歌曲名从酷我和虾米搜索)：<https://github.com/JumpAlang/tongzhongForJusic>
4. 配置

   **不需要改源码里的 yml**，用环境变量即可。优先级：命令行参数 > `-D` 系统属性 > 环境变量 > 配置文件。

   ```
   # 方式一：.env 文件（推荐，一次配好所有项）
   cp .env.example .env
   vi .env            # 至少填 RedisHost 与 MusicApi

   # 方式二：启动时直接传参
   java -jar target/jusic-serve.jar --RedisHost=127.0.0.1 --MusicApi=http://127.0.0.1
   ```

   变量清单见 `.env.example`（默认值指向 docker 服务名 `redis` / `jusicMusicApi`，本机裸跑必须覆盖）。

5. 打包项目

   ```
   # 项目是使用 maven 构建的，可以用下面的命令把项目打包成 jar 文件
   > mvn clean package -DskipTests
   # 如果觉得打包过程太久，那么可以选择下面这条命令跳过打包时的项目测试
   > mvn clean package -Dmaven.test.skip
   ```

   产物为 `target/jusic-serve.jar`；若要把前端一起打进去，请先按第 7 步构建前端并复制到
   `src/main/resources/static/`，再执行打包。

6. 启动项目

   ```
   > ./start.sh                          # 自动读取同目录 .env（推荐）
   > DAEMON=1 ./start.sh                 # 后台启动，日志写入 logs/app.log
   > java -jar target/jusic-serve.jar    # 或直接启动，配置用 --参数 / -D 传入
   ```

   停止（需先确保 actuator 已开放 shutdown 端点，端口与凭据按实际修改）：`./shutdown.sh`

7. 前端

   前端是独立仓库（本地目录 `Jusic-ui/`，Vue 3 + Vuetify 4，详见其中的 `README.md`）。
   要让 jar 里带上前端，需在打包前构建并复制产物：

   ```
   cd Jusic-ui
   npm install && npm run build
   rm -rf ../src/main/resources/static/{index.html,assets,js,css,img}
   cp -r dist/* ../src/main/resources/static/
   cd .. && mvn clean package -DskipTests
   ```

   不想每次重新打包时，可让后端读外部目录（改前端只需覆盖该目录并刷新页面）：

   ```
   java -jar target/jusic-serve.jar \
     --spring.resources.static-locations=file:/path/to/webroot/,classpath:/static/
   ```

8. 重构/开发期：一键构建与重启

   改完代码不必手工重跑「npm build → 复制产物 → mvn package → kill → 启动」，
   仓库根目录提供了两个脚本：

   | 场景 | 命令 |
   |---|---|
   | 改前端 | `./deploy.sh --web`（build + 同步到 `webroot/`，**不重打 jar**，刷新浏览器即可）|
   | 改后端 | `./deploy.sh --backend`（mvn package + 重启）|
   | 改 `.env` | `./deploy.sh --restart` |
   | 全量 | `./deploy.sh` |
   | 预演 | `./deploy.sh --dry-run` |
   | 后端热重载 | `./dev.sh`，另开终端 `./dev.sh compile` 触发自动重启 |

   要点：
   - 静态资源走外置目录 `webroot/`（由 `StaticLocations` 环境变量注入，默认值与改动前
     完全一致），所以改前端不再需要重打 43MB 的 jar
   - 进程号在 `logs/app.pid`，控制台日志 `logs/console.log`；停止时先发 SIGTERM 优雅停机，
     超时才 `kill -9`
   - `./dev.sh` 用的是 `mvn spring-boot:run` + devtools：devtools 在 `java -jar` 跑 fat jar 时
     会被自动禁用，因此生产启动不受影响
   - 远程生产发布方案与「什么时候才值得上 CI/CD」，见 `.review/部署与联调指南.md` 第 9 节

## 使用

在聊天窗口发送指令即可，**普通用户**：

| 指令 | 说明 |
|---|---|
| `点歌 关键字` | 点一首歌（也支持网易云音乐 ID） |
| `投票切歌` | 发起切歌投票，超过在线人数 30% 时生效 |
| `设置昵称 名字` | 修改自己的显示昵称（仅当前客户端） |
| `删除音乐 歌曲名` | 删除自己点错的歌 |

**管理员**（先用 `root 密码` 或 `admin 密码` 提权，密码见 `RoleRootPassword`）：

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

## 在线预览

Jusic：[Jusic 点歌台](http://music.alang.run)

## 打赏请我喝奶茶
[打赏](http://www.alang.run/sponsor)

## 相关项目

* JusicServe:[JusicServe](https://github.com/hanhuoer/Jusic-serve)
* Jusic-ui:[Jusic-ui](https://github.com/hanhuoer/Jusic-ui)
* 网易云音乐api:[NeteaseMusic](https://github.com/jsososo/NeteaseMusic)
* qq音乐api:[qqMusicApi](https://github.com/jsososo/QQMusicApi)
* 咪咕音乐api:[miguMusicApi](https://github.com/jsososo/MiguMusicApi)

