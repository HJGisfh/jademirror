@echo off
chcp 65001 >nul
title 玉灵童子启动器

echo ========================================
echo    玉灵童子 AI管家启动器
echo ========================================
echo.

:: 检查Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未检测到Python，请先安装Python
    pause
    exit /b 1
)

:: 检查Node.js
node --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未检测到Node.js，请先安装Node.js
    pause
    exit /b 1
)

echo [✓] Python 已安装
echo [✓] Node.js 已安装
echo.

:: 检查后端配置
if not exist "jademirror\backend\.env" (
    echo [警告] 未找到后端配置文件 .env
    echo [提示] 请复制 .env.example 为 .env 并配置API密钥
    echo.
    pause
)

echo [启动] 正在启动后端服务...
start "玉灵童子-后端" cmd /k "cd /d %~dp0jademirror\backend && python app.py"

:: 等待后端启动
timeout /t 5 /nobreak >nul

echo [启动] 正在启动前端服务...
start "玉灵童子-前端" cmd /k "cd /d %~dp0jademirror\frontend && npm run dev"

echo.
echo ========================================
echo    服务启动完成！
echo ========================================
echo.
echo 后端地址: http://localhost:5000
echo 前端地址: http://localhost:5173
echo.
echo 请在浏览器中访问前端地址开始使用
echo 按任意键打开浏览器...
pause >nul

start http://localhost:5173

echo.
echo 提示：关闭此窗口不会停止服务
echo 要停止服务，请关闭后端和前端的命令行窗口
echo.
pause
