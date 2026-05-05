"""
JadeMirror Flutter 手机端专用 API：读取 jademirror/mobile_backend/.env，
与 Web 使用的 jademirror/backend/.env 分离（数据库、生成目录互不覆盖）。
默认端口 5001，避免与本机 Web 后端 5000 冲突。

在 jademirror/backend 目录执行:
  python app_mobile.py
"""
import os

os.environ.setdefault('PORT', '5001')

from jademirror_core import create_app

app = create_app('app')

if __name__ == '__main__':
    from jademirror_core.application import _server_listen_port, suggested_api_base_url

    listen_port = _server_listen_port()
    api_base = suggested_api_base_url()
    health_url = (
        f'{api_base}/health'
        if api_base.endswith('/api')
        else f'{api_base.rstrip("/")}/health'
    )
    print('\n[Jademirror 手机后端]「我 → 服务器地址」填:', api_base)
    print('[Jademirror 手机后端] 浏览器自检:', health_url)
    print(
        f'[Jademirror 手机后端] 当前 PORT={listen_port}'
        '（未设 PORT 时默认 5001；若 mobile_backend/.env 写了 PORT=5000 则会用 5000）\n'
    )
    app.run(host='0.0.0.0', port=listen_port, debug=True)
