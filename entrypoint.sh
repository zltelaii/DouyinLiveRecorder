#!/bin/sh
# 容器入口：初始化配置 + 环境自检，最后把控制权交给 CMD
set -eu

# 宿主机挂载的 config 目录首次通常是空的，此时用镜像内的默认配置初始化。
# 否则程序只能读到一份空 config.ini，所有选项走默认值（弹幕抓取会是关闭的）。
if [ ! -s /app/config/config.ini ]; then
    if [ -d /app/defaults_config ]; then
        mkdir -p /app/config
        cp -rn /app/defaults_config/. /app/config/ 2>/dev/null || true
        echo "[entrypoint] 已将默认配置初始化到 /app/config"
    fi
fi

# 直播间地址必须预先填好：容器没有交互终端，程序卡在读取地址时不会提示你去哪填
if [ ! -s /app/config/URL_config.ini ]; then
    echo ""
    echo "[entrypoint] 提示：config/URL_config.ini 目前是空的。"
    echo "[entrypoint] 请在宿主机上往这个文件里写入直播间地址（每行一个），容器会自动开始录制。"
    echo "[entrypoint] 需要弹幕的话，确认 config/config.ini 中：是否录制弹幕(是/否) = 是"
    echo ""
fi

echo "[entrypoint] ffmpeg: $(ffmpeg -version 2>/dev/null | head -n 1 || echo '缺失')"
echo "[entrypoint] node:   $(node --version 2>/dev/null || echo '缺失（弹幕签名需要）')"

exec "$@"
