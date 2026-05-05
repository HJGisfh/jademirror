# 本机 zip 上传到云服务器部署

适用于：**Windows 本机打包 → 上传到腾讯云 Ubuntu → Docker 启动**（不使用 Git）。

## 一、在本机（Windows）打包

1. 在资源管理器中打开项目根目录，例如 **`E:\Jade`**。
2. **不要**把下面整块打进 zip（体积大且无必要）：
   - `app\build`
   - `app\.dart_tool`
   - `jademirror\frontend\node_modules`
   - 各目录下的 `.venv`、`__pycache__`
3. 选中 **`Jade` 根目录里的内容**（或整个 `Jade` 文件夹），右键 **发送到 → 压缩(zipped)文件夹**，得到例如 **`Jade.zip`**。

若已安装 7-Zip，可先删掉上述文件夹再压缩，zip 更小、上传更快。

## 二、上传到服务器

**方式 A：用浏览器（最简单）**  
在腾讯云控制台打开 **OrcaTerm / 文件管理**，把 **`Jade.zip`** 上传到 **`/home/ubuntu/`**（或你习惯的用户主目录）。

**方式 B：用 PowerShell（本机执行）**  
把 `你的密钥.pem`、`150.109.235.111`、`Jade.zip` 换成实际路径与 IP：

```powershell
scp -i "C:\path\to\your.pem" E:\Jade\Jade.zip ubuntu@150.109.235.111:/home/ubuntu/
```

首次连接若提示 host key，输入 `yes`。

## 三、在服务器上解压并启动

用 **OrcaTerm / SSH** 登录 Ubuntu，执行（路径按你实际上传位置改）：

```bash
cd ~
sudo apt-get update
sudo apt-get install -y unzip

unzip -o Jade.zip -d Jade
cd ~/Jade/deploy

cp .env.example .env
nano .env
```

在 **`.env`** 中填写 **`DEEPSEEK_API_KEY`**、**`QWEN_API_KEY`**，确认：

- **`PUBLIC_API_BASE=http://150.109.235.111:5000`**
- **`ALLOWED_ORIGINS=*`**

保存后执行：

```bash
docker compose up -d --build
docker compose logs -f
```

看到 gunicorn 监听 **0.0.0.0:5000** 且无报错后，按 **Ctrl+C** 退出日志。

## 四、验证

在服务器上：

```bash
curl -s http://127.0.0.1:5000/api/health
```

在你本机浏览器打开：

```text
http://150.109.235.111:5000/api/health
```

若浏览器打不开，到腾讯云 **安全组** 检查是否放行 **入站 TCP 5000**。

## 五、手机 App

「我 → 服务器地址」填：**`http://150.109.235.111:5000/api`**

## 六、以后更新版本

1. 本机重新打 zip（同上，注意排除大目录）。  
2. 上传覆盖 **`Jade.zip`**。  
3. 服务器上：

```bash
cd ~
rm -rf Jade
unzip -o Jade.zip -d Jade
cd ~/Jade/deploy
docker compose up -d --build
```

**注意：** 这样会删掉容器内旧数据（如 SQLite 用户）。若已在线上注册用户，更新前请先 **`docker compose down`** 后按需备份容器内数据，或改用持久化卷（见 `deploy/README.md`）。
