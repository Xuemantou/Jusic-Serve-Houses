#!/usr/bin/env bash
#
# 启动脚本：读取同目录的 .env，然后启动打包好的 jar。
#
# 用法：
#   ./start.sh                            # 前台启动（直接看日志，Ctrl-C 停止）
#   ./start.sh --server.port=9000         # 额外参数透传给 Spring Boot
#   DAEMON=1 ./start.sh                   # 后台启动，日志写入 logs/app.log
#   JAVA_OPTS="-Xmx512m" ./start.sh       # 追加 JVM 参数
#
# 说明：Spring Boot 不原生识别 .env 文件，这里用 `set -a` 把其中的 KEY=VALUE
#       导出为环境变量后，application-prod.yml 里的 ${Xxx} 占位符才能取到。
#
set -euo pipefail
cd "$(dirname "$0")"

# ---- 定位 jar（兼容 target/ 或与脚本同目录两种放法）----
JAR="${JAR:-}"
if [ -z "$JAR" ]; then
  for candidate in target/jusic-serve.jar jusic-serve.jar; do
    if [ -f "$candidate" ]; then JAR="$candidate"; break; fi
  done
fi
if [ -z "$JAR" ] || [ ! -f "$JAR" ]; then
  echo "找不到 jar。请先构建：" >&2
  echo "  cd Jusic-ui && npm run build" >&2
  echo "  cp -r dist/* ../src/main/resources/static/" >&2
  echo "  cd .. && mvn clean package -DskipTests" >&2
  exit 1
fi

# ---- 加载 .env ----
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
  echo "已加载 .env"
else
  echo "未找到 .env，将使用 application-prod.yml 的默认值。"
  echo "  本机裸跑通常需要：RedisHost=127.0.0.1  MusicApi=http://127.0.0.1"
  echo "  可复制模板：cp .env.example .env"
fi

# ---- 启动 ----
if [ "${DAEMON:-0}" = "1" ]; then
  mkdir -p logs
  # shellcheck disable=SC2086
  nohup java ${JAVA_OPTS:-} -jar "$JAR" "$@" >> logs/app.log 2>&1 &
  echo "已后台启动（pid $!），日志：logs/app.log"
else
  echo "启动 $JAR ..."
  # shellcheck disable=SC2086
  exec java ${JAVA_OPTS:-} -jar "$JAR" "$@"
fi
