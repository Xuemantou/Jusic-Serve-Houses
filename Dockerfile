# 本镜像同时承载后端与前端：前端（Jusic-ui）的构建产物已打进 jar 的
# BOOT-INF/classes/static/，由 Spring Boot 同源提供，因此不需要单独的前端镜像。
#
# 构建前先产出 jar：
#   cd Jusic-ui && npm run build && rm -rf ../src/main/resources/static/assets ../src/main/resources/static/index.html \
#     && cp -r dist/* ../src/main/resources/static/
#   cd .. && mvn -Dmaven.repo.local=.m2-repo clean package -DskipTests
#   docker build -t jusic-serve-houses:latest .
#
# 运行请用 docker compose（见 docker-compose.yml），
# 它会一并拉起 redis 与 music-api，并把 RedisHost/MusicApi 指向容器网络地址。
FROM eclipse-temurin:17-jre-jammy

ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /app
COPY target/jusic-serve.jar ./jusic-serve.jar

# logback 会写 logs/common-all.log 与 logs/common-error.log，先建好目录便于挂载
RUN mkdir -p /app/logs

EXPOSE 8888
ENTRYPOINT ["java", "-jar", "/app/jusic-serve.jar"]
