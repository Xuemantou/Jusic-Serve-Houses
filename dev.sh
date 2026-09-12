#!/usr/bin/env bash
#
# dev.sh —— 开发模式启动后端（devtools 热重载，不用反复打 jar）
#
# 开发回路（重构期推荐）：
#   终端 A：./dev.sh            启动后端；之后改 Java 代码不用重启它
#   终端 B：./dev.sh compile    重编译 → devtools 检测到 target/classes 变化 → 自动重启
#   前端：  ./deploy.sh --web   改前端后同步到 webroot（同源，最接近生产行为）
#       或  cd Jusic-ui && npm run dev    （Vite HMR，但走跨域）
#
# 用法：
#   ./dev.sh                    # 启动（默认端口 8888）
#   DEV_PORT=8899 ./dev.sh      # 换端口，避免和已在运行的实例冲突
#   ./dev.sh compile            # 在另一个终端触发重编译 + 自动重启
#   ./dev.sh --dry-run          # 只打印将执行的命令
#   ./dev.sh -h | --help
#
# 可用环境变量：DEV_PORT、WEBROOT、UI_DIR、JAVA_OPTS
#
# ⚠️ 为什么必须用 mvn spring-boot:run：
#    devtools 只在「展开的 classpath」下生效。用 java -jar 跑打包好的 fat jar 时
#    Spring Boot 会自动禁用 devtools —— 生产启动（start.sh / deploy.sh）正是靠这一点
#    完全不受影响，两者互不干扰。
#
# ⚠️ 热重启不是无限可用的，重启几次后必然崩：
#    devtools 重启若干次后会撞上 CGLIB 的
#      LinkageError: loader 'app' attempted duplicate class definition for
#      ...WebSocketHandlerDecorator$$FastClassBySpringCGLIB$$
#    应用起不来、端口不再监听，而且这个错误**无法自愈**（classloader 已被污染），
#    再跑几次 compile 也没用。此时 Ctrl-C 后重新 ./dev.sh 即可（新 JVM 是干净的）。
#    判断方法：logs/common-error.log 里出现上述 LinkageError，
#    或启动日志里出现成对的 "JusicDisposable.destroy" 而端口不通。
#
#    另一个坑：本脚本用 mvn compile 触发的重启走的是完整 spring-boot:run 生命周期，
#    会执行 test-compile；若测试代码引用了已删除的类，会以编译失败的形式
#    表现成"后端起不来"。删 Java 类时记得连 src/test 一起查。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

DEV_PORT="${DEV_PORT:-${APP_PORT:-8888}}"
WEBROOT="${WEBROOT:-$ROOT/webroot}"

if [ -t 1 ]; then
  C_RST=$'\033[0m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_INFO=$'\033[36m'
else
  C_RST=""; C_OK=""; C_WARN=""; C_ERR=""; C_INFO=""
fi
info() { printf '%s[ dev  ]%s %s\n' "$C_INFO" "$C_RST" "$*"; }
ok()   { printf '%s[  ok  ]%s %s\n' "$C_OK" "$C_RST" "$*"; }
warn() { printf '%s[ warn ]%s %s\n' "$C_WARN" "$C_RST" "$*" >&2; }
err()  { printf '%s[ fail ]%s %s\n' "$C_ERR" "$C_RST" "$*" >&2; }
die()  { err "$*"; exit 1; }

usage() {
  awk 'NR>2 { if ($0 ~ /^set -euo pipefail$/) exit; sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
  exit 0
}

DRY=0
MODE="run"
for arg in "$@"; do
  case "$arg" in
    compile)  MODE="compile" ;;
    --dry-run) DRY=1 ;;
    -h|--help) usage ;;
    *) die "未知参数：$arg（用 -h 看用法）" ;;
  esac
done

command -v mvn >/dev/null 2>&1 || die "缺少 mvn"

# ---------- compile 模式：在另一个终端触发重编译 ----------
if [ "$MODE" = "compile" ]; then
  if [ "$DRY" = 1 ]; then
    echo "  [dry-run] (cd $ROOT && mvn -q compile)"
    exit 0
  fi
  info "重编译（devtools 检测到 target/classes 变化后会自动重启）"
  exec mvn -q compile
fi

# ---------- run 模式 ----------
if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
  ok "已加载 .env"
else
  warn "未找到 .env，将使用 application-prod.yml 默认值（本机裸跑通常需要 RedisHost=127.0.0.1）"
fi

# 外置静态目录优先，jar 内 static 兜底：改前端只要 ./deploy.sh --web，不用重打 jar
export StaticLocations="file:${WEBROOT}/,classpath:/static/"

if [ ! -f "$WEBROOT/index.html" ]; then
  warn "$WEBROOT/index.html 不存在，页面会回落到 classpath:/static/（可能是 jar 里的旧前端）"
  warn "  想让改完的前端生效：另开一个终端跑 ./deploy.sh --web"
fi

# 端口占用提醒（devtools 模式自己不会自动换端口）
if command -v ss >/dev/null 2>&1; then
  if ss -ltn 2>/dev/null | grep -qE "[:.]${DEV_PORT}[[:space:]]"; then
    warn "端口 ${DEV_PORT} 已被占用：可能是生产实例还在跑"
    warn "  先 ./deploy.sh --restart 之前停掉它，或用 DEV_PORT=8899 ./dev.sh 换端口"
  fi
fi

JVM_ARGS="-Dfile.encoding=UTF-8"
if [ -n "${JAVA_OPTS:-}" ]; then
  JVM_ARGS="$JVM_ARGS $JAVA_OPTS"
fi
MVN_ARGS=(spring-boot:run -Dspring-boot.run.fork=true)
MVN_ARGS+=("-Dspring-boot.run.arguments=--server.port=${DEV_PORT}")
MVN_ARGS+=("-Dspring-boot.run.jvmArguments=$JVM_ARGS")

printf '\n'
info "启动开发模式：端口 $DEV_PORT"
info "静态资源：$StaticLocations"
info "改完 Java 代码后，另开终端跑：./dev.sh compile"
printf '\n'

if [ "$DRY" = 1 ]; then
  echo "  [dry-run] (cd $ROOT && mvn ${MVN_ARGS[*]})"
  exit 0
fi

exec mvn "${MVN_ARGS[@]}"
