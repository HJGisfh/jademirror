@echo off
chcp 65001 >nul 2>&1
echo ============================================
echo   Hunyuan3D-2 本地部署 - 一键设置脚本
echo   适配 RTX 3050 (4GB VRAM) 超低显存模式
echo ============================================
echo.

set "SEVEN_ZIP=C:\Program Files\7-Zip\7z.exe"
set "DOWNLOAD_DIR=%USERPROFILE%\Downloads"
set "INSTALL_DIR=E:\Jade\Hunyuan3D2_WinPortable"
set "ARCHIVE=%DOWNLOAD_DIR%\Hunyuan3D2_WinPortable.7z"

if not exist "%ARCHIVE%" (
    echo [错误] 未找到下载文件: %ARCHIVE%
    echo 请先下载 Hunyuan3D2_WinPortable.7z 到 %DOWNLOAD_DIR%
    echo 下载地址: https://github.com/YanWenKun/Hunyuan3D-2-WinPortable/releases/download/v1/Hunyuan3D2_WinPortable.7z
    echo 国内镜像: https://ghfast.top/https://github.com/YanWenKun/Hunyuan3D-2-WinPortable/releases/download/v1/Hunyuan3D2_WinPortable.7z
    pause
    exit /b 1
)

echo [1/5] 解压整合包...
if exist "%INSTALL_DIR%" (
    echo 目录已存在: %INSTALL_DIR%
    echo 跳过解压步骤
) else (
    if not exist "%SEVEN_ZIP%" (
        echo [错误] 未找到 7-Zip: %SEVEN_ZIP%
        echo 请先安装 7-Zip: https://7-zip.org/
        pause
        exit /b 1
    )
    "%SEVEN_ZIP%" x "%ARCHIVE%" -o"E:\Jade" -y
    if errorlevel 1 (
        echo [错误] 解压失败
        pause
        exit /b 1
    )
    echo 解压完成
)
echo.

echo [2/5] 复制中文脚本...
if exist "%INSTALL_DIR%\中文脚本" (
    copy /Y "%INSTALL_DIR%\中文脚本\*.bat" "%INSTALL_DIR%\" >nul 2>&1
    echo 中文脚本已复制
) else (
    echo 中文脚本目录不存在，跳过
)
echo.

echo [3/5] 初始化环境...
echo 这一步会安装 Python 依赖，可能需要几分钟
cd /d "%INSTALL_DIR%"
if exist "0-initialize.bat" (
    call "0-initialize.bat"
) else if exist "更新.bat" (
    call "更新.bat"
) else (
    echo 未找到初始化脚本，请手动运行 0-initialize.bat
)
echo.

echo [4/5] 下载模型权重 (~26GB)...
echo 这一步会下载混元3D的模型文件，需要较长时间
echo 如果下载失败，可以重新运行 2-下载模型.bat 继续
if exist "2-下载模型.bat" (
    call "2-下载模型.bat"
) else (
    echo 未找到下载脚本，请手动运行 2-download-models.bat
)
echo.

echo [5/5] 启动 API 服务器 (超低显存模式)...
echo.
echo ============================================
echo   部署完成！
echo ============================================
echo.
echo 接下来请运行以下命令启动服务:
echo.
echo   cd /d "%INSTALL_DIR%"
echo   运行_超低显存模式.bat
echo.
echo 或者直接运行 API 服务器:
echo.
echo   cd /d "%INSTALL_DIR%\Hunyuan3D-2"
echo   python\python.exe api_server.py --host 0.0.0.0 --port 8080 --profile 5
echo.
echo 服务启动后，访问 http://localhost:8080 测试
echo JadeMirror 后端会自动连接 http://127.0.0.1:8080
echo.
pause
