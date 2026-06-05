# VPNGate-to-VPS

轻量 Docker 代理网关：电脑连接 VPS 上的认证 SOCKS5/HTTP 代理，VPS 再通过 VPNGate OpenVPN 节点出口。内置 Web 管理界面，可刷新/测速/切换节点、修改代理账号密码，并生成 Clash 订阅链接。

## 特性

- Docker Compose 一键部署。
- Web 管理面板默认端口 `8787`，带随机路径和登录账号密码。
- 代理端口默认 `7928`，同时支持 SOCKS5 和 HTTP/HTTPS CONNECT。
- 代理默认强制账号密码认证，避免公网裸奔。
- 自动拉取 VPNGate 节点、测速、连接和失效切换。
- Clash 订阅端点 `/sub/<token>`，可在 Web 面板重置 token。
- 数据持久化到 `./data`，包括节点缓存、日志和账号配置。

## VPS 要求

- Linux VPS，支持 Docker 和 Docker Compose。
- 宿主机必须启用 TUN/TAP，容器需要 `/dev/net/tun`。
- 安全组/防火墙放行：
  - TCP `8787`：Web 管理面板。
  - TCP `7928`：SOCKS5/HTTP 代理。

## 一键部署

```bash
git clone https://github.com/Sakuralaaa/vps-vpngate-to-socks.git
cd vps-vpngate-to-socks
cp .env.example .env
```

如果使用 GitHub Actions 构建出的 GHCR 镜像，也可以把 `docker-compose.yml` 里的 `build: .` 改成：

```yaml
image: ghcr.io/sakuralaaa/vps-vpngate-to-socks:latest
```

编辑 `.env`，建议填入 VPS 公网 IP 或域名：

```bash
PUBLIC_HOST=你的VPS公网IP或域名
```

启动：

```bash
bash deploy.sh
```

也可以直接运行：

```bash
docker compose up -d --build
docker compose logs -f vpngate-to-vps
```

## Zeabur 部署

Zeabur 可以从 GitHub 仓库或 Docker 镜像部署服务，但此项目依赖 OpenVPN TUN 设备。部署前先确认你的 Zeabur 运行环境支持：

- `/dev/net/tun`
- `NET_ADMIN`
- `NET_RAW`
- TCP 端口暴露

如果 Zeabur 服务配置里无法开启这些权限，请改为在你的 VPS 上 SSH 执行 Docker Compose 部署。

### 自托管 Zeabur/K3s TUN 补丁

如果 Zeabur 跑在你自己的 VPS 上，它可能会创建普通 K3s Deployment：容器里没有 `/dev/net/tun`，也没有 `NET_ADMIN`。这种情况下 VPNGate 节点可能显示有 ping 延迟，但 OpenVPN 无法创建 `tun0`，代理会返回 502，或者节点看起来全部不可用。

SSH 到 VPS 宿主机后运行：

```bash
sh scripts/zeabur-k3s-tun-patch.sh
```

也可以显式传入 namespace 和 deployment：

```bash
sh scripts/zeabur-k3s-tun-patch.sh environment-xxxx service-xxxx
```

脚本会给 Deployment 合并 `privileged: true`、`NET_ADMIN`、`NET_RAW`，并挂载宿主机 `/dev/net/tun`，然后等待 pod 滚动完成。Zeabur 后续重新部署可能覆盖这个补丁；如果新 pod 又丢失 `/dev/net/tun`，需要重新执行一次。

### 方式 A：从 GitHub 仓库部署

1. 在 Zeabur 新建 Project。
2. 添加 Service，选择 GitHub Repository。
3. 选择 `Sakuralaaa/vps-vpngate-to-socks` 和 `main` 分支。
4. 构建方式选择 Dockerfile。
5. 环境变量至少设置：

```text
PORT=8787
UI_PORT=8787
UI_HOST=0.0.0.0
LOCAL_PROXY_HOST=0.0.0.0
LOCAL_PROXY_PORT=7928
VPNGATE_DATA_DIR=/app/data
PUBLIC_HOST=你的Web访问域名
```

这里要填真实生成的域名，例如 `mygate.zeabur.app`。不要填写 `PUBLIC_HOST=${ZEABUR_WEB_DOMAIN}` 这种占位符，除非你的平台会在注入容器前先展开它。

6. 暴露 Web HTTP 端口 `8787`。
7. 暴露 TCP 代理端口 `7928`。
8. 如果 Zeabur 给代理端口分配了不同的公网转发地址或端口，再设置：

```text
PUBLIC_PROXY_HOST=Zeabur分配的TCP转发域名或IP
PUBLIC_PROXY_PORT=Zeabur分配的TCP转发端口
```

### 方式 B：使用 GitHub Actions 构建出的 GHCR 镜像

镜像地址：

```text
ghcr.io/sakuralaaa/vps-vpngate-to-socks:latest
```

在 Zeabur 添加 Docker Image Service，填入上面的镜像地址，再按方式 A 设置环境变量和端口。

首次启动后打开：

```text
https://你的域名/manage/
```

第一次打开会要求你设置管理密码。之后进入 Web 管理界面只需要输入这个密码，不需要用户名。

## 使用方式

打开：

```text
http://你的VPS公网IP:8787/manage/
```

登录后进入 `管理员 -> Proxy / Clash`：

- 查看 SOCKS5/HTTP 代理地址。
- 修改代理账号密码。
- 复制 Clash 订阅链接。
- 重置 Clash 订阅 token。

电脑上配置代理：

```text
SOCKS5: 你的VPS公网IP:7928
HTTP:   你的VPS公网IP:7928
```

账号密码使用 Web 面板 `Proxy / Clash` 中显示的代理账号和代理密码。

## Clash 订阅

在 Web 面板复制订阅链接，导入 Clash/Clash Verge/Mihomo 客户端即可。订阅内容会生成一个 `socks5` 节点，server 使用：

1. `.env` 里的 `PUBLIC_HOST`。
2. 如果未设置，则使用访问 Web 面板时的 Host。

如果怀疑订阅泄露，在 Web 面板点击 `重置订阅 Token`，旧链接会立即失效。

## 常用命令

```bash
docker compose ps
docker compose logs -f vpngate-to-vps
docker compose restart vpngate-to-vps
docker compose down
```

## 故障排查

- `Cannot open TUN/TAP`：VPS 或容器没有 TUN 权限，确认已启用 TUN/TAP，并使用 Compose 中的 `/dev/net/tun` 映射。
- Web 打不开：检查 VPS 安全组、系统防火墙和 `docker compose ps` 端口映射。
- 代理无法联网：先在 Web 面板刷新节点并连接可用节点，再使用“网关”自检。
- Clash 节点 server 不正确：设置 `.env` 的 `PUBLIC_HOST` 后重启容器。

## License

本项目基于 `aimili-vpngate` 代码整合，保留 GPLv3 授权。详见 `LICENSE`。
