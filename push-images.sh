#!/usr/bin/env bash
#
# 把两个镜像推送到 Docker Hub
#
# 用法：
#   docker login                                  # 先登录（用 Access Token 更安全）
#   ./push-images.sh <dockerhub用户名>            # 例：./push-images.sh alang
#   ./push-images.sh <用户名> --also-latest       # 同时打 latest 之外的标签（见下）
#
# 推送内容：
#   <用户名>/jusic-serve-houses  后端 + 前端（前端已打进 jar）
#   <用户名>/jusic-music-api     音乐 API 聚合：网易(3000) + QQ(3300)
#
set -euo pipefail

USER_NAME="${1:-}"
if [ -z "$USER_NAME" ]; then
  echo "用法: $0 <dockerhub用户名> [标签后缀]" >&2
  echo "例:   $0 alang" >&2
  exit 1
fi

# 允许自定义标签后缀，默认 latest
TAG="${2:-latest}"
TAG="${TAG#--}"   # 容忍 --latest 这种写法

SERVE_LOCAL="jusic-serve-houses:latest"
API_LOCAL="jusic-music-api:2in1"

SERVE_REMOTE="${USER_NAME}/jusic-serve-houses:${TAG}"
API_REMOTE="${USER_NAME}/jusic-music-api:${TAG}"

echo "==> 检查本地镜像"
for img in "$SERVE_LOCAL" "$API_LOCAL"; do
  if ! docker image inspect "$img" >/dev/null 2>&1; then
    echo "找不到本地镜像: $img" >&2
    echo "  后端镜像构建: docker build -t jusic-serve-houses:latest ." >&2
    echo "  音乐API构建:  docker build -t jusic-music-api:2in1 .docker-build" >&2
    exit 1
  fi
  printf "    %-32s %s\n" "$img" "$(docker image inspect "$img" --format '{{.Size}}' | awk '{printf "%.0f MB", $1/1024/1024}')"
done

echo
echo "==> 打标签"
docker tag "$SERVE_LOCAL" "$SERVE_REMOTE"
docker tag "$API_LOCAL"   "$API_REMOTE"
echo "    $SERVE_REMOTE"
echo "    $API_REMOTE"

echo
echo "==> 推送（合计约 1GB，上行带宽决定耗时）"
docker push "$SERVE_REMOTE"
docker push "$API_REMOTE"

echo
echo "完成。别人可以直接用："
echo "  docker pull ${SERVE_REMOTE}"
echo "  docker pull ${API_REMOTE}"
echo
echo "注意：docker-compose.yml 里 music-api 的 image 需要改成 ${API_REMOTE}"
