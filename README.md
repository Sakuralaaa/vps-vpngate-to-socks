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

首次启动会在日志里输出 Web 地址、账号和密码。配置也会保存到：

```text
./data/ui_auth.json
```

## 使用方式

打开：

```text
http://你的VPS公网IP:8787/<随机路径>/
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
