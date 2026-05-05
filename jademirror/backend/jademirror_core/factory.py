"""Flask application factory: separate web vs mobile app instance roots and CORS."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv
from flask import Flask
from flask_cors import CORS


def _repo_root() -> Path:
    # jademirror_core -> backend -> jademirror -> 仓库根
    return Path(__file__).resolve().parent.parent.parent.parent


def resolve_instance_root(profile: str) -> Path:
    root = _repo_root()
    if profile == 'web':
        return root / 'jademirror' / 'backend'
    if profile == 'app':
        return root / 'app' / 'backend'
    raise ValueError(f'unknown profile: {profile!r}')


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
    return app
