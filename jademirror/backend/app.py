"""
JadeMirror Web 后端入口：服务 Vue/Vite 前端，读 jademirror/backend/.env。
与手机 App 后端（app/backend）数据与配置隔离。
"""
import os

from jademirror_core import create_app

app = create_app('web')

if __name__ == '__main__':
    from jademirror_core.application import _server_listen_port

    listen_port = _server_listen_port()
    print('\n[Jademirror Web] 本地 API: http://127.0.0.1:%s/api' % listen_port)
    print('[Jademirror Web] health: http://127.0.0.1:%s/api/health' % listen_port)
    print('[Jademirror Web] Vite 通过 /api 代理到此进程；CORS 见 jademirror/backend/.env 中 ALLOWED_ORIGINS\n')
    app.run(host='0.0.0.0', port=listen_port, debug=True)
