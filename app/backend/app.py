"""
JadeMirror 手机 App 专用后端入口：读 app/backend/.env，与 Web 后端（jademirror/backend）隔离。
默认端口 5001，避免与 Web 的 5000 冲突。
"""
import os
import sys
from pathlib import Path

# 与 jademirror_core 同仓库：从仓库根可导入 jademirror_core
_ROOT = Path(__file__).resolve().parent.parent.parent
_backend_parent = _ROOT / 'jademirror' / 'backend'
if str(_backend_parent) not in sys.path:
    sys.path.insert(0, str(_backend_parent))

# 未配置 .env 时与 Web 后端（5000）错开
os.environ.setdefault('PORT', '5001')

from jademirror_core import create_app

app = create_app('app')

if __name__ == '__main__':
    from jademirror_core.application import _server_listen_port, suggested_api_base_url

    listen_port = _server_listen_port()
    api_base = suggested_api_base_url()
    health_url = f'{api_base}/health' if api_base.endswith('/api') else f'{api_base.rstrip("/")}/health'
    print('\n[Jademirror App 后端] 手机「我 → 服务器地址」填:', api_base)
    print('[Jademirror App 后端] 浏览器自检:', health_url)
    print(f'[Jademirror App 后端] 当前 PORT={listen_port}（未设 PORT 时默认 5001；若在 .env 写了 PORT=5000 则会用 5000）\n')
    app.run(host='0.0.0.0', port=listen_port, debug=True)
