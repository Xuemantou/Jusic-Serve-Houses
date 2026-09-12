# 二合一音乐 API 聚合镜像：网易云(3000) + QQ音乐(3300)
#
# 与作者的 jumpalang/jusic_music_api:2.1 相比：
#   - 去掉咪咕(3400) 与 酷我/虾米铜钟(8081)：后端代码已删除对它们的调用
#   - 网易换成仍在维护的 NeteaseCloudMusicApiEnhanced/api-enhanced（接口契约与原版一致）
#   - QQ 仍用 jsososo/QQMusicApi：它是唯一保持后端契约（/search?key=、/song/urls 等）的实现
#
# 构建：docker build -t jusic-music-api:2in1 .
# 运行：docker run -d --name jusicMusicApi --restart always \
#         -e QQ=你的QQ号 -p 3000:3000 -p 3300:3300 \
#         -v /宿主机路径/qq-data:/app/qq/data \
#         jusic-music-api:2in1

FROM node:18-slim

# supervisord：在一个容器里托管两个 Node 进程，沿用原镜像的「聚合」形态
# pnpm 固定装 9.x：上游 lockfile 是 lockfileVersion 9.0，corepack 默认拉的 pnpm 12 不兼容
RUN apt-get update \
 && apt-get install -y --no-install-recommends supervisor ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g pnpm@9 --no-audit --no-fund

# ---------------- 网易云 :3000 ----------------
WORKDIR /app/netease
COPY netease/ ./
# 项目自带 pnpm-lock.yaml；--ignore-scripts 用于跳过 husky 的 prepare 钩子
RUN pnpm install --prod --frozen-lockfile --ignore-scripts

# ---------------- QQ音乐 :3300 ----------------
WORKDIR /app/qq
COPY qq/ ./
# 必须用 yarn 并尊重项目自带的 yarn.lock：
# 改用 pnpm/npm 会因缺少对应锁文件而按 ^ 范围拉到最新版依赖
# （实测装上 undici@7，它需要 Node 20+，在 Node 18 下直接 ReferenceError: File is not defined）。
# 两个额外坑：
#  1. node 官方镜像里 corepack 预置了 /usr/local/bin/yarn shim（指向 yarn 4，不认 v1 锁文件），须先删；
#  2. yarn.lock 是 2021 年生成的，其中 143 处指向 registry.npm.taobao.org、4 处指向 registry.nlark.com，
#     这两个镜像域名均已停用，直接 install 会 ENOTFOUND。统一改写到 registry.npmmirror.com（旧路径兼容）。
RUN rm -f /usr/local/bin/yarn /usr/local/bin/yarnpkg \
 && npm install -g yarn@1.22.22 --no-audit --no-fund \
 && yarn config set registry https://registry.npmmirror.com \
 && yarn config set network-timeout 600000 \
 && sed -i -E 's#https://registry\.(npm\.taobao\.org|nlark\.com)/#https://registry.npmmirror.com/#g' yarn.lock \
 && yarn install --production --frozen-lockfile --non-interactive

COPY supervisord.conf /etc/supervisor/conf.d/jusic-music-api.conf

EXPOSE 3000 3300
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/jusic-music-api.conf"]
