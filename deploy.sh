#!/usr/bin/env bash
#
# deploy.sh —— 本机一键「构建 → 重启」（重构期专用）
#
# 为什么不用 CI/CD 干这件事：本机开发回路要的是秒级反馈。
# 走流水线是「push → 排队 → 构建 → 回拉 → 重启」，一轮几分钟；
# 这个脚本全在本地，一轮几秒到几十秒，且不依赖任何外部服务。
#
# 用法：
#   ./deploy.sh                  # 前端构建 + 同步 webroot + 后端打包 + 重启
#   ./deploy.sh --web            # 只构建前端并同步 webroot（最高频：改前端不用重打 jar）
#   ./deploy.sh --backend        # 只打包后端 + 重启
#   ./deploy.sh --restart        # 不构建，只重启（改完 .env 后最常用）
#   ./deploy.sh --no-restart     # 构建但不重启
#   ./deploy.sh --with-tests     # 后端打包时跑测试（默认跳过）
#   ./deploy.sh --clean          # 后端走 clean package（默认增量 package，更快）
#   ./deploy.sh --dry-run        # 只打印将执行的动作，不真的执行
#   ./deploy.sh -h | --help
#
# 可用环境变量覆盖（也可写进 .env）：
#   APP_PORT=8888                    健康检查端口
#   WEBROOT=$PWD/webroot             外置静态资源目录
#   PIDFILE=$PWD/logs/app.pid        进程号文件
#   CONSOLE_LOG=$PWD/logs/console.log 控制台日志
#   UI_DIR=$PWD/Jusic-ui             前端目录
#   HEALTH_TIMEOUT=60                健康检查最长等待秒数
#   STOP_TIMEOUT=20                  优雅停机最长等待秒数
#   JAVA_OPTS="-Xmx512m"             追加 JVM 参数
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- 可配置项 ----------
APP_PORT="${APP_PORT:-8888}"
WEBROOT="${WEBROOT:-$ROOT/webroot}"
PIDFILE="${PIDFILE:-$ROOT/logs/app.pid}"
CONSOLE_LOG="${CONSOLE_LOG:-$ROOT/logs/console.log}"
UI_DIR="${UI_DIR:-$ROOT/Jusic-ui}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-60}"
STOP_TIMEOUT="${STOP_TIMEOUT:-20}"
JAR="$ROOT/target/jusic-serve.jar"
JAR_NAME="$(basename "$JAR")"

# ---------- 行为开关 ----------
DO_WEB=0
DO_BACKEND=0
DO_RESTART=0
WITH_TESTS=0
CLEAN=0
DRY=0

# ---------- 彩色输出 ----------
if [ -t 1 ]; then
  C_RST=$'\033[0m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_INFO=$'\033[36m'
else
  C_RST=""; C_OK=""; C_WARN=""; C_ERR=""; C_INFO=""
fi
info() { printf '%s[deploy]%s %s\n' "$C_INFO" "$C_RST" "$*"; }
ok()   { printf '%s[  ok  ]%s %s\n' "$C_OK" "$C_RST" "$*"; }
warn() { printf '%s[ warn ]%s %s\n' "$C_WARN" "$C_RST" "$*" >&2; }
err()  { printf '%s[ fail ]%s %s\n' "$C_ERR" "$C_RST" "$*" >&2; }
die()  { err "$*"; exit 1; }

usage() {
  awk 'NR>2 { if ($0 ~ /^set -euo pipefail$/) exit; sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
  exit 0
}

# ---------- 参数解析 ----------
parse_args() {
  local no_restart=0
  if [ $# -eq 0 ]; then
    DO_WEB=1; DO_BACKEND=1; DO_RESTART=1
    return 0
  fi
  while [ $# -gt 0 ]; do
    case "$1" in
      -w|--web)        DO_WEB=1 ;;
      -b|--backend)    DO_BACKEND=1; DO_RESTART=1 ;;
      -r|--restart)    DO_RESTART=1 ;;
      --no-restart)    no_restart=1 ;;
      --with-tests)    WITH_TESTS=1 ;;
      --clean)         CLEAN=1 ;;
      --dry-run)       DRY=1 ;;
      -h|--help)       usage ;;
      *)               die "未知参数：$1（用 -h 看用法）" ;;
    esac
    shift
  done
  # 只给了修饰性参数（如 --dry-run / --clean）时，套用默认的「全量」动作
  if [ "$DO_WEB" = 0 ] && [ "$DO_BACKEND" = 0 ] && [ "$DO_RESTART" = 0 ]; then
    DO_WEB=1; DO_BACKEND=1; DO_RESTART=1
  fi
  # --no-restart 显式给出时优先级最高
  if [ "$no_restart" = 1 ]; then DO_RESTART=0; fi
}

# ---------- 执行包装（支持 --dry-run） ----------
run_in() {
  local dir="$1"; shift
  if [ "$DRY" = 1 ]; then
    printf '  %s[dry-run]%s (cd %s && %s)\n' "$C_WARN" "$C_RST" "$dir" "$*"
    return 0
  fi
  ( cd "$dir" && "$@" )
}

command -v curl >/dev/null 2>&1 || die "缺少 curl（健康检查需要）"

# ---------- .env ----------
load_env() {
  if [ -f "$ROOT/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$ROOT/.env"
    set +a
    ok "已加载 .env"
  else
    warn "未找到 .env，将使用 application-prod.yml 的默认值"
    warn "  本机裸跑通常需要：RedisHost=127.0.0.1  MusicApi=http://127.0.0.1"
  fi
}

# ---------- 前端 ----------
build_web() {
  [ -d "$UI_DIR" ] || die "前端目录不存在：$UI_DIR（用 UI_DIR=... 指定）"
  info "构建前端：$UI_DIR"
  if [ ! -d "$UI_DIR/node_modules" ]; then
    warn "node_modules 不存在，先安装依赖（首次会慢）"
    run_in "$UI_DIR" npm install
  fi
  run_in "$UI_DIR" npm run build
  sync_webroot
}

sync_webroot() {
  local dist="$UI_DIR/dist"
  [ -f "$dist/index.html" ] || die "前端产物不存在：$dist/index.html"
  if [ "$DRY" = 1 ]; then
    printf '  %s[dry-run]%s 同步 %s → %s\n' "$C_WARN" "$C_RST" "$dist" "$WEBROOT"
    return 0
  fi
  mkdir -p "$WEBROOT"
  # assets/ 里的文件名带哈希，只覆盖会残留旧文件，必须整体删掉再复制；
  # js/ css/ img/ 是 Vue2 时代的旧结构，一并清掉。
  rm -rf "$WEBROOT/index.html" "$WEBROOT/assets" "$WEBROOT/js" "$WEBROOT/css" "$WEBROOT/img"
  cp -r "$dist"/* "$WEBROOT"/
  # Vite 产物里没有 favicon，从 jar 内 static 兜底复制，避免 /favicon.ico 404
  if [ ! -f "$WEBROOT/favicon.ico" ] && [ -f "$ROOT/src/main/resources/static/favicon.ico" ]; then
    cp "$ROOT/src/main/resources/static/favicon.ico" "$WEBROOT/"
  fi
  ok "前端产物已同步：$WEBROOT"
}

# ---------- 后端 ----------
build_backend() {
  command -v mvn >/dev/null 2>&1 || die "缺少 mvn"
  local mvn_args=(package)
  if [ "$CLEAN" = 1 ]; then
    mvn_args=(clean package)
  fi
  if [ "$WITH_TESTS" = 1 ]; then
    info "打包后端（含测试）"
  else
    info "打包后端（跳过测试）"
    mvn_args+=(-DskipTests)
  fi
  # 注意：增量 package 时服务可以继续跑；Linux 下覆盖运行中的 jar 不影响已启动的 JVM
  run_in "$ROOT" mvn "${mvn_args[@]}"
  if [ "$DRY" != 1 ]; then
    [ -f "$JAR" ] || die "打包后仍找不到 $JAR"
    ok "后端产物：$JAR（$(du -h "$JAR" | cut -f1)）"
  fi
}

# ---------- 停止 ----------
stop_app() {
  local pids="" pid=""

  # ① 优先用 PID 文件（本脚本自己启动的）
  if [ -f "$PIDFILE" ]; then
    pid="$(tr -d '[:space:]' < "$PIDFILE" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      pids="$pid"
    else
      if [ -n "$pid" ]; then
        warn "PID 文件记录 $pid，但该进程已不存在（陈旧文件），忽略"
      fi
      rm -f "$PIDFILE"
    fi
  fi

  # ② 兜底：按命令行匹配，覆盖「在别的终端手工 java -jar 启动」的情况
  if [ -z "$pids" ]; then
    local found
    found="$(pgrep -f -- "-jar .*${JAR_NAME}" 2>/dev/null | tr '\n' ' ' || true)"
    if [ -n "$found" ]; then
      pids="$found"
      warn "PID 文件无记录，按命令行匹配到：$found"
    fi
  fi

  if [ -z "$pids" ]; then
    warn "没有发现运行中的服务，跳过停止"
    return 0
  fi

  info "优雅停机（SIGTERM）：$pids"
  for pid in $pids; do kill "$pid" 2>/dev/null || true; done

  local waited=0 alive
  while [ "$waited" -lt "$STOP_TIMEOUT" ]; do
    alive=""
    for pid in $pids; do
      if kill -0 "$pid" 2>/dev/null; then alive="$alive $pid"; fi
    done
    if [ -z "$alive" ]; then
      ok "已退出（耗时 ${waited}s）"
      rm -f "$PIDFILE"
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done

  warn "等待 ${STOP_TIMEOUT}s 仍未退出，强制 kill -9"
  for pid in $pids; do kill -9 "$pid" 2>/dev/null || true; done
  sleep 1
  rm -f "$PIDFILE"
}

# ---------- 启动 ----------
start_app() {
  [ -f "$JAR" ] || die "找不到 $JAR，先跑 ./deploy.sh --backend"
  if [ "$DRY" = 1 ]; then
    printf '  %s[dry-run]%s 启动 java -jar %s（StaticLocations=file:%s/,classpath:/static/）\n' \
      "$C_WARN" "$C_RST" "$JAR" "$WEBROOT"
    return 0
  fi
  mkdir -p "$(dirname "$PIDFILE")" "$(dirname "$CONSOLE_LOG")"

  # 外置静态目录优先，jar 内 static 兜底：
  # 改前端只要重跑 ./deploy.sh --web，不用重新打 43MB 的 jar。
  export StaticLocations="file:${WEBROOT}/,classpath:/static/"

  # shellcheck disable=SC2086
  nohup java ${JAVA_OPTS:-} -jar "$JAR" >> "$CONSOLE_LOG" 2>&1 &
  local pid=$!
  echo "$pid" > "$PIDFILE"
  ok "已启动 pid=$pid"
  ok "控制台日志：$CONSOLE_LOG"
  info "静态资源：$StaticLocations"
}

# ---------- 健康检查 ----------
wait_healthy() {
  if [ "$DRY" = 1 ]; then
    printf '  %s[dry-run]%s 健康检查 http://127.0.0.1:%s/\n' "$C_WARN" "$C_RST" "$APP_PORT"
    return 0
  fi
  local url="http://127.0.0.1:${APP_PORT}/" i code pid
  pid="$(tr -d '[:space:]' < "$PIDFILE" 2>/dev/null || true)"
  info "健康检查：$url（最长 ${HEALTH_TIMEOUT}s）"
  for ((i = 1; i <= HEALTH_TIMEOUT; i++)); do
    # 必须先确认自己启动的进程还活着：
    # 否则端口被别的进程占用时，新进程已崩、旧服务仍在应答 200，会误报「启动成功」。
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
      err "进程 $pid 已退出，启动失败（常见原因：端口 ${APP_PORT} 已被占用）。日志尾部："
      tail -n 30 "$CONSOLE_LOG" 2>/dev/null || true
      return 1
    fi
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$url" 2>/dev/null || true)"
    if [ "$code" = "200" ]; then
      ok "健康检查通过（${i}s）"
      return 0
    fi
    sleep 1
  done
  err "健康检查超时（${HEALTH_TIMEOUT}s，最后状态码：${code:-无响应}）"
  err "日志尾部："
  tail -n 30 "$CONSOLE_LOG" 2>/dev/null || true
  return 1
}

# ---------- 主流程 ----------
main() {
  local started_at=$SECONDS
  parse_args "$@"
  load_env

  if [ "$DO_WEB" = 1 ]; then build_web; fi
  if [ "$DO_BACKEND" = 1 ]; then build_backend; fi
  if [ "$DO_RESTART" = 1 ]; then
    stop_app
    start_app
    wait_healthy
  fi

  printf '\n'
  ok "完成，耗时 $((SECONDS - started_at))s"
  if [ "$DO_WEB" = 1 ] && [ "$DO_RESTART" = 0 ]; then
    info "改动已进 $WEBROOT。若服务不是本脚本启动的，跑一次 ./deploy.sh --restart 让外置目录生效"
  fi
  if [ "$DO_RESTART" = 1 ] && [ "$DRY" = 0 ]; then
    info "本机访问：http://127.0.0.1:${APP_PORT}/"
  fi
}

main "$@"
