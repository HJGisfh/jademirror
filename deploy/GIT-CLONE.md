# 用 Git 在云服务器上部署

与 `ZIP-UPLOAD.md` 相同目标：**Ubuntu + Docker** 跑 JadeMirror API，只是代码用 **git clone / pull** 获取。

## 1. 服务器准备

```bash
sudo apt-get update
sudo apt-get install -y git
```

## 2. 克隆仓库

**HTTPS（简单，私有库需 Token）：**

```bash
cd ~
git clone https://github.com/你的用户名/Jade.git
cd Jade/deploy
```

**SSH（推荐，需先在服务器生成密钥并把公钥加到 GitHub/Gitee）：**

```bash
ssh-keygen -t ed25519 -C "ubuntu@lightsail" -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
# 把输出整行复制到 Git 网站 → SSH Keys

git clone git@github.com:你的用户名/Jade.git
cd Jade/deploy
```

## 3. 配置并启动

```bash
cp .env.example .env
nano .env
```

填写 **`DEEPSEEK_API_KEY`**、**`QWEN_API_KEY`**，**`PUBLIC_API_BASE=http://150.109.235.111:5000`**（或你的公网 IP / 域名）。

```bash
docker compose up -d --build
docker compose logs -f
```

## 4. 安全组与自检

云平台放行 **TCP 5000**，然后：

```bash
curl -s http://127.0.0.1:5000/api/health
```

浏览器：`http://<公网IP>:5000/api/health`  
手机 App：`http://<公网IP>:5000/api`

## 5. 以后更新

```bash
cd ~/Jade
git pull
cd deploy
docker compose up -d --build
```

有合并冲突时先在本机解决再 push，服务器再 `git pull`。

## 6. 与 zip 方式的对比

| 项目     | Git                     | zip        |
|----------|-------------------------|------------|
| 首次部署 | `git clone`             | 上传解压   |
| 更新     | `git pull` + 重建镜像 | 重新上传解压、重建 |
| 密钥     | 建议 SSH deploy key     | 无需仓库凭据 |

详细说明（HTTPS、持久化、HTTPS 反代）见 **`deploy/README.md`**。
