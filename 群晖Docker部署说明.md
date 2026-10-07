# 群晖 Docker 部署说明

把改好的 DouyinLiveRecorder（含弹幕抓取 + 自动烧录）做成镜像，在群晖上运行。

## 整体方案

```
本机/仓库 ──push──> GitHub ──Actions 自动构建──> ghcr.io 镜像仓库 ──拉取──> 群晖
```

用的是 **GitHub 自带的容器仓库（GHCR）**，不是 Docker Hub。好处是不需要另外注册
Docker Hub 账号、也没有 Docker Hub 的拉取频率限制，GitHub 账号直接就能用。

镜像地址：

```
ghcr.io/zltelaii/douyin-live-recorder:latest
```

## 一、镜像是怎么来的（不用你手动构建）

仓库里放了 `.github/workflows/ghcr.yml`：**代码一推送到 GitHub，Actions 就自动构建镜像并推到 ghcr.io**。

- 默认构建 `linux/amd64`（群晖绝大多数 x86 机型都可以）
- 如果你的群晖是 **ARM 机型**（DS220j、DS120j、DS418j 等），需要手动触发一次 arm64 构建：
  进 GitHub 仓库 → **Actions** → **Build and Push to GHCR** → **Run workflow** →
  `platforms` 填 `linux/arm64`

构建完成后，在 GitHub 个人主页 → **Packages** 里能看到 `douyin-live-recorder`。

## 二、群晖上拉取（两种做法）

### ⚠️ 先说清楚：注册表里搜不到是正常的

在 Container Manager 左侧点 **注册表**，搜索框里输入 `douyin` 或 `douyin-live-recorder`
**什么都搜不出来**。原因不在你，也不在镜像：

- 那个搜索框是给 **Docker Hub** 用的，走的是 Docker Hub 的搜索接口
- GHCR 压根不提供「列出所有镜像 / 按关键字搜索」这类接口
  （Docker Registry 规范的 `_catalog`、`search` 端点 GHCR 都没实现）

所以 GHCR 上的镜像**只能靠完整地址精确拉取，不能靠搜**。下面三条路任选一条，
本质都是直接填地址，别再在搜索框里浪费时间。

#### 需不需要登录

实测这个镜像是**公开**的（匿名拉取返回 200），群晖不填凭据也能拉。
若你的环境提示 `denied`（比如把包改成了私有），才需要：

1. <https://github.com/settings/tokens> → **Generate new token (classic)**
2. 只勾 `read:packages` 一项
3. 用户名填 GitHub 用户名，密码填这个 token

确认镜像有没有构建好（能看到版本列表就说明成功）：
<https://github.com/users/zltelaii/packages/container/douyin-live-recorder>

### 做法 A：Container Manager 图形界面（推荐）

1. 套件中心安装 **Container Manager**（DSM 7）或 **Docker**（DSM 6）
2. **映像** → **新增** → **从 URL 添加**
3. 填完整地址：`ghcr.io/zltelaii/douyin-live-recorder:latest`
4. 下载完成后选中映像 → **运行**，按下面「三、挂载目录」配置

> 如果点「从 URL 添加」时群晖提示要先添加注册表：
> **设置** → **注册表** → **添加**，地址填 `ghcr.io`。
> 用户名/密码这步可以留空（镜像公开），留空校验不过就填上面说的 token。
> 注意：加完注册表**仍然搜不到**，还是要走第 2 步的「从 URL 添加」。

#### 可以填的两种地址

```
ghcr.io/zltelaii/douyin-live-recorder:latest
```

上面这个标签会随构建更新。想**锁定当前这一版**（避免以后被新构建覆盖），
用 digest 精确引用：

```
ghcr.io/zltelaii/douyin-live-recorder@sha256:07e95b64b8a70e4d7f8ab59e69ac62d27c7679cc7ae287de4904e585c712c0bd
```

还有个按 commit 打的标签：`a8aae9fb494be48beff706e7ce4c2cf68636c0d9`。

> GitHub 上那个 Packages 页面（<https://github.com/users/zltelaii/packages/container/douyin-live-recorder>）
> **只能看版本列表，不能下载镜像文件**。镜像不提供网页下载，只能由 Docker 客户端拉取。

### 做法 A2：用「项目」直接跑 compose（最省事，推荐新手）

Container Manager → **项目** → **新建** → 来源选「创建 docker-compose.yml」，
把仓库里的 `docker-compose.yaml` 内容整段粘进去。

好处是**挂载目录、重启策略、时区全部自带**，不用一个个手填，镜像也会自动拉取。
群晖会自动在 `/volume1/docker/` 下建目录（你也可以在「位置」里改成自己的路径）。

### 做法 A3：群晖拉不动 GHCR 时，改用本地文件导入

如果群晖访问 `ghcr.io` 超时或失败（国内网络偶发），在一台**能上网且装了 Docker**
的电脑上先拉下来打包，再传给群晖：

```bash
docker pull ghcr.io/zltelaii/douyin-live-recorder:latest
docker save ghcr.io/zltelaii/douyin-live-recorder:latest -o douyin-recorder.tar
```

得到一个 `douyin-recorder.tar`，然后群晖上走
**映像 → 新增 → 从文件添加**，选这个 tar 即可，不需要联网拉取。

### 做法 C：先把镜像推到 Docker Hub（好处是群晖能搜到）

GHCR 上搜不到，但 **Docker Hub 上能搜到**——群晖那个搜索框本来就是查 Docker Hub 的。
如果你就是想「搜一下就能装」，把同一个镜像再推一份到 Docker Hub 即可，
群里搜 `douyin-live-recorder` 就能出现。

仓库里已经备好 `.github/workflows/dockerhub.yml`，**只需你配一次凭据**：

**第一步：拿 Docker Hub 的 Access Token**

1. 注册/登录 <https://hub.docker.com>
2. <https://hub.docker.com/settings/security> → **New Access Token**
3. 权限选 **Read & Write**，生成的字符串复制下来（**不是你的登录密码**）

**第二步：把凭据存进 GitHub 仓库**

进 <https://github.com/zltelaii/DouyinLiveRecorder/settings/secrets/actions>
→ **New repository secret**，加两个：

| 名称 | 值 |
|---|---|
| `DOCKERHUB_USERNAME` | 你的 Docker Hub 用户名 |
| `DOCKERHUB_TOKEN` | 上一步生成的 Access Token |

**第三步：手动跑一次构建**

仓库 → **Actions** → 左侧选 **Publish to Docker Hub** → **Run workflow**
→ `image_name` 填 `你的用户名/douyin-live-recorder` → 运行。

> 这个 fork 的默认分支已设为 `feature/douyin-danmaku`（弹幕代码在这条分支上），
> 所以 Actions 页面能直接看到这个 workflow。若某天列表里找不到它，
> 用页面上方的分支选择器切到 `feature/douyin-danmaku` 即可——
> GitHub 只展示默认分支上的 workflow。

跑完（约 2 分钟），群晖上就是：

- **注册表** 里搜 `douyin-live-recorder` → 能搜到，点一下就能下载
- 或者 **映像 → 从 URL 添加** 填 `你的用户名/douyin-live-recorder:latest`

> 仓库名必须是 `用户名/仓库名` 的格式，写成别的会报 `denied`。
> 另外 Docker Hub 匿名拉取有频率限制（每 IP 6 小时 100 次），个人用远不到上限。

### 做法 B：SSH 登录群晖用命令行

群晖要先在「控制面板 → 终端机和 SNMP」里开启 SSH。

```bash
# 公开镜像可以直接拉；提示没权限就先登录
docker login ghcr.io -u 你的GitHub用户名      # 密码用 Personal Access Token
docker pull ghcr.io/zltelaii/douyin-live-recorder:latest
```

用 `docker-compose.yaml`（在共享文件夹里建个目录，比如 `/volume1/docker/douyin/`）：

```bash
cd /volume1/docker/douyin
docker compose up -d
```

## 三、挂载目录（这一步最关键）

程序在容器里的工作目录是 `/app`，必须把这几个目录挂到群晖的共享文件夹，
否则容器一删，配置和录好的视频全没了：

| 容器内路径 | 用途 | 建议群晖路径 |
|---|---|---|
| `/app/config` | 配置文件（config.ini、URL_config.ini） | `/volume1/docker/douyin/config` |
| `/app/downloads` | **录好的视频 + 弹幕文件** | `/volume1/docker/douyin/downloads` |
| `/app/logs` | 日志 | `/volume1/docker/douyin/logs` |
| `/app/backup_config` | 配置备份 | `/volume1/docker/douyin/backup_config` |

**首次启动会自动初始化配置**：你在群晖上新建的 `config` 目录是空的，容器启动时
entrypoint 会把镜像内的默认 `config.ini` 复制进去。所以第一次跑完，去
`docker/douyin/config/` 里就能看到配置文件了。

## 四、启动前必须做的一件事：填直播间地址

编辑 `/volume1/docker/douyin/config/URL_config.ini`，每行一个直播间地址：

```
https://live.douyin.com/12112080561
https://live.douyin.com/745964462470
```

**这个文件空着的话容器不会录任何东西。** 命令行环境下程序无法向你提问，
它会每隔 30 秒重新检查一次——所以你也可以先启动容器，再去补这个文件，不用重启。

## 五、确认弹幕功能已开

打开 `/volume1/docker/douyin/config/config.ini`，检查这几项：

```ini
是否录制弹幕(是/否) = 是
弹幕保存格式(逗号分隔) = json,srt,ass
弹幕最多同时显示行数 = 4
弹幕单条显示时长(秒) = 5
录制完成后自动将弹幕烧录到视频(是/否) = 是
```

镜像内的默认值已经是「全开」，一般不用改。

另外 `[Cookie]` 里的 `抖音cookie` 建议填上**你自己的抖音登录 Cookie**，
没登录状态下礼物、粉丝团这类消息推得不全。（弹幕必需的 ttwid 程序会自动申请，不填也能跑。）

## 六、产物在哪

录制结束后，在 `/volume1/docker/douyin/downloads/` 下能看到：

```
主播名_2026-10-07_14-00-00.mp4                 ← 原始视频
主播名_2026-10-07_14-00-00_弹幕.mp4            ← 烧好弹幕的版本（顶部 4 行）
主播名_2026-10-07_14-00-00.danmaku.jsonl       ← 弹幕全量原始数据
主播名_2026-10-07_14-00-00.danmaku.srt
主播名_2026-10-07_14-00-00.danmaku.ass
```

拿 `_弹幕.mp4` 直接切片即可。

## 七、排错

| 现象 | 原因 / 处理 |
|---|---|
| 注册表里搜索镜像，什么都搜不到 | 正常，GHCR 不支持搜索接口。走「从 URL 添加」填完整地址，见第二节 |
| 点「从 URL 添加」要求先添加注册表 | 设置 → 注册表 → 添加 `ghcr.io`，凭据留空或填 PAT |
| 拉取时提示 `denied` / `unauthorized` | 包被设成私有了，用 PAT 登录；或去 Packages 设置里改成 Public |
| 容器起来就退出，日志说没有直播间地址 | `URL_config.ini` 是空的，见第四节 |
| 提示 `node` 缺失 / 弹幕抓不到 | 镜像构建异常，检查 Actions 构建日志里 Node 那一步 |
| 能录视频但没弹幕文件 | `config.ini` 里弹幕开关是「否」；或直播间未开播（会抓到 0 条） |
| 群晖提示镜像架构不匹配 | 机型是 ARM，按第一节手动触发 arm64 构建 |
| 想自己在本机构建 | 装 Docker Desktop，在项目目录 `docker build -t douyin-recorder .` |

## 八、镜像里装了什么

| 组件 | 用途 |
|---|---|
| `python:3.11-slim` | 运行环境 |
| `ffmpeg` | 拉流录制 + 弹幕烧录 |
| `nodejs 20` | 抖音签名走 PyExecJS 执行 JS，**没有它弹幕抓不了** |
| `tzdata` | 时区固定为 Asia/Shanghai，日志时间才对得上 |
