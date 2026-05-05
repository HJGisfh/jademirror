# JadeMirror 云服务器部署（Docker）

适用于 Ubuntu 22.04 + 已安装 Docker / Docker Compose 的轻量云主机（如腾讯云首尔）。

## 1. 安全组与端口

在云平台 **防火墙 / 安全组** 放行 **入站 TCP 5000**（或你改成 80/443 后再映射）。

## 2. 服务器上准备代码

```bash
sudo apt-get update && sudo apt-get install -y git
git clone <你的仓库地址> Jade
cd Jade/deploy
cp .env.example .env
nano .env   # 填写 DEEPSEEK_API_KEY、QWEN_API_KEY；PUBLIC_API_BASE 改为公网 IP 或域名
```

若未用 Git，可在本机打包上传仓库后解压，保证服务器上存在 `Jade/jademirror/backend` 与 `Jade/deploy` 目录结构。

## 3. 构建并启动

```bash
cd Jade/deploy
docker compose up -d --build
```

查看日志：

```bash
docker compose logs -f
```

## 4. 自检

```bash
curl -s http://127.0.0.1:5000/api/health | head
curl -s http://<公网IP>:5000/api/health | head
```

手机 / Flutter 里「服务器地址」填：**`http://<公网IP>:5000/api`**（有 HTTPS 后改为 `https://.../api`）。

## 5. 更新版本

```bash
cd Jade && git pull
cd deploy && docker compose up -d --build
```

## 6. 可选：HTTPS

建议在前面加 **Nginx / Caddy**，申请 Let’s Encrypt 证书，反代到 `127.0.0.1:5000`；`PUBLIC_API_BASE` 与 App 内地址改为 `https://域名`。

## 说明

- 镜像内 SQLite 与 `generated_models` 在容器层；换镜像重建会丢数据。需要持久化时可再挂卷或改用外置数据库。
- 生产高并发请把会话与文件迁到 PostgreSQL + 对象存储，并提高 `gunicorn` workers（需改存储实现）。
