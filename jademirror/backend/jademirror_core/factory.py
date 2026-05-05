"""Flask application factory: separate web vs mobile app instance roots and CORS."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv
from flask import Flask, jsonify, request, send_file, send_from_directory
from flask_cors import CORS


def _repo_root() -> Path:
    # jademirror_core -> backend -> jademirror -> 仓库根
    return Path(__file__).resolve().parent.parent.parent.parent


def resolve_instance_root(profile: str) -> Path:
    root = _repo_root()
    if profile == 'web':
        return root / 'jademirror' / 'backend'
    if profile == 'app':
        # Flutter 专用配置与数据目录，与 Web 后端同归 jademirror 下，避免混在 app/ 里
        return root / 'jademirror' / 'mobile_backend'
    raise ValueError(f'unknown profile: {profile!r}')


def _safe_dist_file(dist: Path, rel: str) -> Path | None:
    """仅当文件在 dist 目录内且存在时返回路径，防止路径穿越。"""
    if not rel or rel.startswith('/') or '..' in rel.split('/'):
        return None
    try:
        base = dist.resolve()
        candidate = (dist / rel).resolve()
        if str(candidate).startswith(str(base)) and candidate.is_file():
            return candidate
    except OSError:
        return None
    return None


def _register_vue_spa(app: Flask) -> None:
    """若存在 Vite 构建产物，则托管前端；与 /api 同端口，无需域名即可用 IP 访问网页。"""
    dist = _repo_root() / 'jademirror' / 'frontend' / 'dist'
    index = dist / 'index.html'
    if not index.is_file():
        return

    assets = dist / 'assets'

    @app.get('/assets/<path:filename>')
    def _vite_assets(filename: str):
        if not assets.is_dir():
            return jsonify({'error': 'Not found'}), 404
        return send_from_directory(assets, filename)

    @app.errorhandler(404)
    def _spa_or_api_404(e):
        if request.path.startswith('/api'):
            return jsonify({'error': 'Not found'}), 404
        if request.path.startswith('/assets/'):
            return jsonify({'error': 'Not found'}), 404
        rel = request.path.lstrip('/')
        if rel:
            hit = _safe_dist_file(dist, rel)
            if hit is not None:
                return send_file(hit)
        return send_file(index.resolve(), mimetype='text/html')


def create_app(profile: str = 'web') -> Flask:
    instance_root = resolve_instance_root(profile)
    instance_root.mkdir(parents=True, exist_ok=True)
    load_dotenv(instance_root / '.env', override=True)
    load_dotenv(override=True)

    from . import application as appmod

    appmod.configure_instance(instance_root)
    appmod.refresh_settings(profile)

    app = Flask(__name__)
    app.config['INSTANCE_ROOT'] = str(instance_root)
    app.config['PROFILE'] = profile

    if profile == 'web':
        raw = os.getenv(
            'ALLOWED_ORIGINS',
            'http://localhost:5173,http://127.0.0.1:5173',
        )
        origins = [x.strip() for x in raw.split(',') if x.strip()]
        CORS(app, resources={r'/api/*': {'origins': origins or ['http://localhost:5173']}})
    else:
        CORS(app, resources={r'/api/*': {'origins': '*'}})

    app.register_blueprint(appmod.bp)
    appmod.init_auth_db()

    if profile == 'web':
        _register_vue_spa(app)

    return app
