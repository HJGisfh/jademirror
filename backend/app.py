import os
import secrets
import sqlite3
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import quote

import requests
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_cors import CORS
from werkzeug.security import check_password_hash, generate_password_hash

try:
    from openai import OpenAI
except ImportError:
    OpenAI = None

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / '.env', override=True)
load_dotenv(override=True)

app = Flask(__name__)

allowed_origins = [item.strip() for item in os.getenv('ALLOWED_ORIGINS', '*').split(',') if item.strip()]
CORS(app, resources={r'/api/*': {'origins': allowed_origins or ['*']}})

DEEPSEEK_BASE_URL = os.getenv('DEEPSEEK_BASE_URL', 'https://api.deepseek.com').rstrip('/')
DEEPSEEK_MODEL = os.getenv('DEEPSEEK_MODEL', 'deepseek-chat')
QWEN_BASE_URL = os.getenv('QWEN_BASE_URL', 'https://dashscope.aliyuncs.com').rstrip('/')
QWEN_MODEL = os.getenv('QWEN_MODEL', 'qwen-image-2.0')
REQUEST_TIMEOUT = float(os.getenv('REQUEST_TIMEOUT', '45'))
REQUEST_MAX_RETRIES = int(os.getenv('REQUEST_MAX_RETRIES', '2'))
RATE_LIMIT_PER_MINUTE = int(os.getenv('RATE_LIMIT_PER_MINUTE', '40'))
DEEPSEEK_ALLOW_MOCK = os.getenv('DEEPSEEK_ALLOW_MOCK', '0') == '1'
AUTH_REQUIRED = os.getenv('AUTH_REQUIRED', '1') == '1'
AUTH_TOKEN_TTL_HOURS = int(os.getenv('AUTH_TOKEN_TTL_HOURS', '168'))
AUTH_DB_PATH_ENV = (os.getenv('AUTH_DB_PATH') or '').strip()
AUTH_DB_PATH = Path(AUTH_DB_PATH_ENV) if AUTH_DB_PATH_ENV else BASE_DIR / 'jademirror_auth.db'

request_hits = {}


def utc_now_ts():
    return int(datetime.now(timezone.utc).timestamp())


def utc_expire_ts(hours):
    return int((datetime.now(timezone.utc) + timedelta(hours=hours)).timestamp())


def db_connect():
    conn = sqlite3.connect(AUTH_DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_auth_db():
    with db_connect() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE,
                nickname TEXT NOT NULL,
                password_hash TEXT NOT NULL,
                created_at INTEGER NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS sessions (
                token TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                expires_at INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """
        )
        conn.execute('CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id)')
        conn.execute('CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at)')
        conn.commit()


def prune_expired_sessions(conn):
    conn.execute('DELETE FROM sessions WHERE expires_at < ?', (utc_now_ts(),))


def create_session(conn, user_id):
    token = secrets.token_urlsafe(36)
    created_at = utc_now_ts()
    expires_at = utc_expire_ts(AUTH_TOKEN_TTL_HOURS)
    conn.execute(
        'INSERT INTO sessions(token, user_id, expires_at, created_at) VALUES(?, ?, ?, ?)',
        (token, user_id, expires_at, created_at),
    )
    return token, expires_at


def sanitize_user(row):
    return {
        'id': row['id'],
        'username': row['username'],
        'nickname': row['nickname'],
    }


def extract_bearer_token():
    auth_header = request.headers.get('Authorization', '')
    if auth_header.lower().startswith('bearer '):
        return auth_header[7:].strip()
    return ''


def get_authenticated_user():
    token = extract_bearer_token()
    if not token:
        return None

    with db_connect() as conn:
        prune_expired_sessions(conn)
        row = conn.execute(
            """
            SELECT u.id, u.username, u.nickname, s.expires_at
            FROM sessions s
            JOIN users u ON u.id = s.user_id
            WHERE s.token = ? AND s.expires_at >= ?
            LIMIT 1
            """,
            (token, utc_now_ts()),
        ).fetchone()
        conn.commit()

    if not row:
        return None

    return {
        'token': token,
        'expires_at': row['expires_at'],
        'user': sanitize_user(row),
    }


def require_auth():
    if not AUTH_REQUIRED:
        return {'user': {'id': 0, 'username': 'guest', 'nickname': 'Guest'}, 'token': '', 'expires_at': 0}, None

    auth_result = get_authenticated_user()
    if not auth_result:
        return None, json_error('请先登录后再继续。', 401)
    return auth_result, None


def json_error(message, status=400):
    return jsonify({'error': message}), status


def get_client_key(endpoint_name):
    remote_addr = request.headers.get('X-Forwarded-For', request.remote_addr or 'unknown')
    return f'{remote_addr}:{endpoint_name}'


def check_rate_limit(endpoint_name):
    key = get_client_key(endpoint_name)
    now = time.time()
    window = now - 60

    hits = request_hits.get(key, [])
    hits = [timestamp for timestamp in hits if timestamp > window]

    if len(hits) >= RATE_LIMIT_PER_MINUTE:
        request_hits[key] = hits
        return False

    hits.append(now)
    request_hits[key] = hits
    return True


def request_with_retry(method, url, *, headers=None, payload=None, params=None):
    last_error = None

    for attempt in range(REQUEST_MAX_RETRIES + 1):
        try:
            response = requests.request(
                method=method,
                url=url,
                headers=headers,
                json=payload,
                params=params,
                timeout=REQUEST_TIMEOUT,
            )

            if response.status_code >= 500 and attempt < REQUEST_MAX_RETRIES:
                time.sleep(0.4 * (attempt + 1))
                continue

            return response
        except requests.RequestException as error:
            last_error = error
            if attempt < REQUEST_MAX_RETRIES:
                time.sleep(0.4 * (attempt + 1))

    raise RuntimeError(str(last_error) if last_error else '请求失败')


def unique_items(items):
    seen = set()
    result = []
    for item in items:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result


def deepseek_base_url_candidates(base_url):
    base = (base_url or 'https://api.deepseek.com').rstrip('/')
    candidates = [base]

    if base.endswith('/v1'):
        candidates.append(base[:-3])
    else:
        candidates.append(f'{base}/v1')

    return unique_items(candidates)


def deepseek_endpoint_candidates(base_url):
    return [f'{item}/chat/completions' for item in deepseek_base_url_candidates(base_url)]


def build_jade_guard_prompt(jade_context, match_reason=''):
    if not isinstance(jade_context, dict) or not jade_context:
        return ''

    traits = jade_context.get('traits') or {}
    if isinstance(traits, dict) and traits:
        trait_text = '，'.join([f'{key}:{value}' for key, value in traits.items()])
    else:
        trait_text = '暂无'

    return (
        '【身份锁定】\n'
        f'- 你是玉器：{jade_context.get("dynasty", "未知")}{jade_context.get("name", "无名玉器")}\n'
        f'- 玉器描述：{jade_context.get("description", "暂无")}\n'
        f'- 核心特征：{trait_text}\n'
        f'- 匹配理由：{match_reason or "用户与这件玉器的气质最契合"}\n\n'
        '你只能以这件玉器的身份回答，不可切换到其他玉器。'
    )


def call_deepseek_by_sdk(*, api_key, model, messages, max_tokens, temperature):
    if OpenAI is None:
        raise RuntimeError('openai SDK 未安装，无法使用 client.chat.completions.create 调用')

    last_error = None

    for base_url in deepseek_base_url_candidates(DEEPSEEK_BASE_URL):
        try:
            client = OpenAI(
                api_key=api_key,
                base_url=base_url,
                timeout=REQUEST_TIMEOUT,
                max_retries=REQUEST_MAX_RETRIES,
            )
            response = client.chat.completions.create(
                model=model,
                messages=messages,
                max_tokens=max_tokens,
                temperature=temperature,
            )

            choices = response.choices or []
            if not choices:
                raise RuntimeError('DeepSeek SDK 返回 choices 为空')

            content = choices[0].message.content
            if isinstance(content, list):
                content = ''.join(
                    item.get('text', '') for item in content if isinstance(item, dict)
                )

            content = str(content or '').strip()
            if not content:
                raise RuntimeError('DeepSeek SDK 返回内容为空')

            return content
        except Exception as error:
            last_error = error

    raise RuntimeError(f'DeepSeek SDK 调用失败：{last_error}')


def call_deepseek_by_http(*, api_key, model, messages, max_tokens, temperature):
    payload = {
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': max_tokens,
    }

    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json',
    }

    last_error = None
    for target_url in deepseek_endpoint_candidates(DEEPSEEK_BASE_URL):
        try:
            response = request_with_retry('POST', target_url, headers=headers, payload=payload)

            if response.status_code >= 400:
                try:
                    detail = response.json()
                except ValueError:
                    detail = {'message': response.text}
                last_error = RuntimeError(f'DeepSeek 返回错误：{detail}')
                continue

            raw_data = response.json()
            content = parse_deepseek_content(raw_data)
            content = str(content or '').strip()
            if not content:
                last_error = RuntimeError('DeepSeek HTTP 返回内容为空')
                continue

            return content
        except RuntimeError as error:
            last_error = error

    raise RuntimeError(str(last_error) if last_error else 'DeepSeek HTTP 调用失败')


def build_mock_chat_reply(messages):
    last_user_message = ''
    for item in reversed(messages):
        if item.get('role') == 'user':
            last_user_message = item.get('content', '')
            break

    if not last_user_message:
        last_user_message = '今夜心绪'

    return f'我听见你提到“{last_user_message}”。若心有波澜，可先慢三息，再看眼前光影。'


def build_mock_image_data_url(prompt_text):
    safe_prompt = prompt_text.strip()[:28] or 'JadeMirror'
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
        '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
        '<stop offset="0%" stop-color="#dbe9df"/><stop offset="100%" stop-color="#88a592"/></linearGradient></defs>'
        '<rect width="1024" height="1024" fill="#f5f1e6" rx="60"/>'
        '<circle cx="512" cy="512" r="300" fill="url(#g)"/>'
        '<circle cx="512" cy="512" r="138" fill="#f5f1e6"/>'
        f'<text x="512" y="862" text-anchor="middle" fill="#24463d" font-size="44">{safe_prompt}</text>'
        '</svg>'
    )
    return f'data:image/svg+xml;charset=utf-8,{quote(svg)}'


def parse_deepseek_content(data):
    choices = data.get('choices') or []
    if not choices:
        return ''

    message = choices[0].get('message') or {}
    content = message.get('content', '')

    if isinstance(content, list):
        return ''.join(item.get('text', '') for item in content if isinstance(item, dict))

    return str(content)


def extract_qwen_image_url(data, headers):
    # Synchronous multimodal response format for qwen-image-2.0 series.
    output = data.get('output') or {}
    choices = output.get('choices') or []
    if choices and isinstance(choices, list):
        message = (choices[0] or {}).get('message') or {}
        content = message.get('content') or []
        if content and isinstance(content, list):
            first = content[0] or {}
            image = first.get('image') or first.get('url') or first.get('image_url')
            if image:
                return image

    output = data.get('output') or {}

    results = output.get('results') or []
    if results and isinstance(results, list):
        first = results[0] or {}
        url = first.get('url') or first.get('image_url')
        if url:
            return url

    task_id = output.get('task_id')
    if task_id:
        return poll_qwen_task(task_id, headers)

    data_results = (data.get('data') or {}).get('results') or []
    if data_results and isinstance(data_results, list):
        first = data_results[0] or {}
        url = first.get('url') or first.get('image_url')
        if url:
            return url

    return ''


def is_qwen_async_model(model_name):
    normalized = str(model_name or '').strip().lower()
    return normalized == 'qwen-image' or normalized.startswith('qwen-image-plus')


init_auth_db()


@app.post('/api/auth/register')
def auth_register():
    data = request.get_json(silent=True) or {}
    username = str(data.get('username', '')).strip()
    nickname = str(data.get('nickname', '')).strip() or username
    password = str(data.get('password', ''))

    if len(username) < 3:
        return json_error('用户名至少 3 个字符。')

    if len(password) < 6:
        return json_error('密码至少 6 位。')

    now_ts = utc_now_ts()

    with db_connect() as conn:
        exists = conn.execute('SELECT id FROM users WHERE username = ? LIMIT 1', (username,)).fetchone()
        if exists:
            return json_error('用户名已存在，请更换用户名。', 409)

        password_hash = generate_password_hash(password)
        cursor = conn.execute(
            'INSERT INTO users(username, nickname, password_hash, created_at) VALUES(?, ?, ?, ?)',
            (username, nickname, password_hash, now_ts),
        )
        user_id = cursor.lastrowid
        token, expires_at = create_session(conn, user_id)

        user_row = conn.execute(
            'SELECT id, username, nickname FROM users WHERE id = ? LIMIT 1',
            (user_id,),
        ).fetchone()
        conn.commit()

    return jsonify({'token': token, 'expires_at': expires_at, 'user': sanitize_user(user_row)})


@app.post('/api/auth/login')
def auth_login():
    data = request.get_json(silent=True) or {}
    username = str(data.get('username', '')).strip()
    password = str(data.get('password', ''))

    if not username or not password:
        return json_error('请输入用户名和密码。')

    with db_connect() as conn:
        prune_expired_sessions(conn)
        user_row = conn.execute(
            'SELECT id, username, nickname, password_hash FROM users WHERE username = ? LIMIT 1',
            (username,),
        ).fetchone()

        if not user_row or not check_password_hash(user_row['password_hash'], password):
            return json_error('用户名或密码错误。', 401)

        token, expires_at = create_session(conn, user_row['id'])
        conn.commit()

    return jsonify({'token': token, 'expires_at': expires_at, 'user': sanitize_user(user_row)})


@app.get('/api/auth/me')
def auth_me():
    auth_result, error = require_auth()
    if error:
        return error

    return jsonify({'user': auth_result['user'], 'expires_at': auth_result['expires_at']})


@app.post('/api/auth/logout')
def auth_logout():
    token = extract_bearer_token()
    if not token:
        return json_error('未提供登录令牌。', 401)

    with db_connect() as conn:
        conn.execute('DELETE FROM sessions WHERE token = ?', (token,))
        conn.commit()

    return jsonify({'ok': True})


def poll_qwen_task(task_id, headers):
    task_url = f'{QWEN_BASE_URL}/api/v1/tasks/{task_id}'

    for _ in range(20):
        response = request_with_retry('GET', task_url, headers=headers)
        if response.status_code >= 400:
            return ''

        data = response.json()
        output = data.get('output') or {}
        status = output.get('task_status') or data.get('task_status')

        if status == 'SUCCEEDED':
            results = output.get('results') or []
            if results and isinstance(results, list):
                return results[0].get('url') or results[0].get('image_url') or ''
            return ''

        if status in {'FAILED', 'CANCELED'}:
            return ''

        time.sleep(1.2)

    return ''


@app.get('/api/health')
def health():
    deepseek_api_key = (os.getenv('DEEPSEEK_API_KEY') or '').strip()
    qwen_api_key = (os.getenv('QWEN_API_KEY') or '').strip()
    return jsonify(
        {
            'status': 'ok',
            'service': 'jademirror-flask-proxy',
            'auth_required': AUTH_REQUIRED,
            'auth_db_path': str(AUTH_DB_PATH),
            'deepseek_configured': bool(deepseek_api_key),
            'deepseek_base_url': DEEPSEEK_BASE_URL,
            'deepseek_sdk_enabled': bool(OpenAI),
            'deepseek_mock_enabled': DEEPSEEK_ALLOW_MOCK,
            'qwen_configured': bool(qwen_api_key),
        }
    )


@app.post('/api/deepseek/chat')
def deepseek_chat():
    if not check_rate_limit('deepseek-chat'):
        return json_error('请求过于频繁，请稍后再试。', 429)

    _, auth_error = require_auth()
    if auth_error:
        return auth_error

    data = request.get_json(silent=True) or {}
    messages = data.get('messages') or []
    system_prompt = data.get('systemPrompt') or ''
    jade_context = data.get('jadeContext') or {}
    match_reason = data.get('matchReason') or ''

    if not isinstance(messages, list) or not messages:
        return json_error('messages 不能为空。')

    deepseek_api_key = (os.getenv('DEEPSEEK_API_KEY') or '').strip()
    if not deepseek_api_key:
        if DEEPSEEK_ALLOW_MOCK:
            mock_content = build_mock_chat_reply(messages)
            return jsonify({'content': mock_content, 'mock': True})
        return json_error('DeepSeek API Key 未配置或未读取到，请检查 backend/.env 并重启后端。', 500)

    payload_messages = []
    jade_guard_prompt = build_jade_guard_prompt(jade_context, match_reason)

    full_system_prompt = ''
    if jade_guard_prompt and system_prompt:
        full_system_prompt = f'{jade_guard_prompt}\n\n{system_prompt}'
    elif jade_guard_prompt:
        full_system_prompt = jade_guard_prompt
    else:
        full_system_prompt = system_prompt

    if full_system_prompt:
        payload_messages.append({'role': 'system', 'content': full_system_prompt})

    payload_messages.extend(messages)

    model = data.get('model') or DEEPSEEK_MODEL
    max_tokens = int(data.get('max_tokens', 300))
    temperature = float(data.get('temperature', 0.8))

    sdk_error = None

    try:
        content = call_deepseek_by_sdk(
            api_key=deepseek_api_key,
            model=model,
            messages=payload_messages,
            max_tokens=max_tokens,
            temperature=temperature,
        )
    except RuntimeError as error:
        sdk_error = error

    if sdk_error is not None:
        try:
            content = call_deepseek_by_http(
                api_key=deepseek_api_key,
                model=model,
                messages=payload_messages,
                max_tokens=max_tokens,
                temperature=temperature,
            )
        except Exception as error:
            return json_error(f'DeepSeek 调用失败：SDK={sdk_error}; HTTP={error}', 502)

    return jsonify({'content': content, 'mock': False})


@app.post('/api/qwen/image')
def qwen_image():
    if not check_rate_limit('qwen-image'):
        return json_error('请求过于频繁，请稍后再试。', 429)

    _, auth_error = require_auth()
    if auth_error:
        return auth_error

    data = request.get_json(silent=True) or {}
    prompt = data.get('prompt', '').strip()

    if not prompt:
        return json_error('prompt 不能为空。')

    qwen_api_key = (os.getenv('QWEN_API_KEY') or '').strip()
    if not qwen_api_key:
        return jsonify({'image_url': build_mock_image_data_url(prompt), 'mock': True})

    model = str(data.get('model') or QWEN_MODEL).strip()
    size = str(data.get('size', '1024*1024')).strip() or '1024*1024'
    negative_prompt = str(data.get('negative_prompt', '')).strip()

    headers = {
        'Authorization': f'Bearer {qwen_api_key}',
        'Content-Type': 'application/json',
    }

    if is_qwen_async_model(model):
        # Async image endpoint supports qwen-image/qwen-image-plus family.
        payload = {
            'model': model,
            'input': {
                'prompt': prompt,
            },
            'parameters': {
                'size': size,
                'n': int(data.get('n', 1) or 1),
            },
        }
        if negative_prompt:
            payload['input']['negative_prompt'] = negative_prompt

        headers['X-DashScope-Async'] = 'enable'
        target_url = f'{QWEN_BASE_URL}/api/v1/services/aigc/text2image/image-synthesis'
    else:
        # qwen-image-2.0 and newer high-end variants should use sync multimodal endpoint.
        payload = {
            'model': model,
            'input': {
                'messages': [
                    {
                        'role': 'user',
                        'content': [
                            {'text': prompt},
                        ],
                    }
                ]
            },
            'parameters': {
                'size': size,
            },
        }
        if negative_prompt:
            payload['parameters']['negative_prompt'] = negative_prompt
        target_url = f'{QWEN_BASE_URL}/api/v1/services/aigc/multimodal-generation/generation'

    try:
        response = request_with_retry('POST', target_url, headers=headers, payload=payload)
    except RuntimeError as error:
        return json_error(f'Qwen 请求失败：{error}', 502)

    if response.status_code >= 400:
        try:
            detail = response.json()
        except ValueError:
            detail = {'message': response.text}

        message = f'Qwen 返回错误：{detail}'
        if isinstance(detail, dict):
            detail_message = str(detail.get('message', ''))
            if 'url error' in detail_message.lower():
                message = (
                    f'{message}；通常是模型与端点不匹配。'
                    f'当前使用 model={model}，已选择接口={target_url}'
                )

        return json_error(message, response.status_code)

    raw_data = response.json()
    image_url = extract_qwen_image_url(raw_data, headers)

    if not image_url:
        return json_error('Qwen 返回成功但未拿到图片地址。', 502)

    return jsonify({'image_url': image_url, 'mock': False})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', '5000')), debug=True)
