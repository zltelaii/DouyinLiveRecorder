FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

WORKDIR /app

# ffmpeg：拉流录制 + 弹幕烧录都要用
# nodejs：抖音签名通过 PyExecJS 执行 JS，没有 Node 运行时弹幕抓不了
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg ffmpeg tzdata && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

COPY . /app

# 镜像内保留一份默认配置。宿主机挂载的 config 目录通常是空的，
# 首次启动时 entrypoint 会用这里的内容初始化，否则程序只能拿到一份空配置
RUN cp -r /app/config /app/defaults_config && \
    mkdir -p /app/downloads /app/logs /app/backup_config && \
    sed -i 's/\r$//' /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh

VOLUME ["/app/config", "/app/downloads", "/app/logs"]

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["python", "-u", "main.py"]
