"""豆包语音 WebSocket 双向流式 V3：wss://openspeech.bytedance.com/api/v3/tts/bidirection

帧格式与事件码对齐《豆包语音 WebSocket 双向流式-V3》及 volcengine-audio 开源实现中的封装逻辑。
"""
from __future__ import annotations

import base64
import gzip
import json
import struct
import time
import uuid

try:
    import websocket
except ImportError:  # pragma: no cover - 运行期由 requirements 保证
    websocket = None

# 协议常量（大端）
_PROTOCOL_V1_HEADER_4 = 0x11
_MSG_FULL_CLIENT = 0b0001
_MSG_FULL_SERVER = 0b1001
_MSG_AUDIO_ONLY_SERVER = 0b1011
_MSG_ERROR = 0b1111
_FLAG_EVENT = 0b0100
_SERIAL_JSON = 0b0001
_SERIAL_RAW = 0b0000
_COMP_NONE = 0b0000
_COMP_GZIP = 0b0001

EVT_START_CONNECTION = 1
EVT_FINISH_CONNECTION = 2
EVT_CONNECTION_STARTED = 50
EVT_CONNECTION_FAILED = 51
EVT_START_SESSION = 100
EVT_FINISH_SESSION = 102
EVT_SESSION_STARTED = 150
EVT_SESSION_FINISHED = 152
EVT_SESSION_FAILED = 153
EVT_TASK_REQUEST = 200
EVT_TTS_RESPONSE = 352

# 与官方示例 / volcengine-audio 中 VolcengineTTSBidirectionRequest 一致
TTS_NAMESPACE = 'BidirectionalTTS'


def _hdr(msg_type: int, serial: int, comp: int = _COMP_NONE) -> bytes:
    return bytes(
        [
            _PROTOCOL_V1_HEADER_4,
            (msg_type << 4) | _FLAG_EVENT,
            (serial << 4) | comp,
            0,
        ]
    )


def pack_full_client_json(event: int, session_id: str | None, meta: dict) -> bytes:
    buf = bytearray(_hdr(_MSG_FULL_CLIENT, _SERIAL_JSON, _COMP_NONE))
    buf.extend(struct.pack('>i', event))
    if session_id is not None:
        sid = session_id.encode('utf-8')
        buf.extend(struct.pack('>I', len(sid)))
        buf.extend(sid)
    payload = json.dumps(meta, ensure_ascii=False).encode('utf-8')
    buf.extend(struct.pack('>I', len(payload)))
    buf.extend(payload)
    return bytes(buf)


def pack_start_connection() -> bytes:
    return pack_full_client_json(EVT_START_CONNECTION, None, {})


def pack_finish_connection() -> bytes:
    return pack_full_client_json(EVT_FINISH_CONNECTION, None, {})


def pack_start_session(session_id: str, req_params: dict, user_uid: str) -> bytes:
    meta = {
        'event': EVT_START_SESSION,
        'namespace': TTS_NAMESPACE,
        'user': {'uid': user_uid},
        'req_params': req_params,
    }
    return pack_full_client_json(EVT_START_SESSION, session_id, meta)


def pack_finish_session(session_id: str) -> bytes:
    return pack_full_client_json(EVT_FINISH_SESSION, session_id, {})


def pack_task_request(session_id: str, text: str, speaker: str, audio_params: dict) -> bytes:
    meta = {
        'event': EVT_TASK_REQUEST,
        'namespace': TTS_NAMESPACE,
        'req_params': {
            'text': text,
            'speaker': speaker,
            'audio_params': audio_params,
        },
    }
    return pack_full_client_json(EVT_TASK_REQUEST, session_id, meta)


def _decomp(raw: bytes, comp: int) -> bytes:
    if comp == _COMP_GZIP:
        return gzip.decompress(raw)
    return raw


def parse_server_message(msg: bytes) -> dict:
    """解析一条服务端二进制帧。"""
    if len(msg) < 8:
        raise RuntimeError('火山 WS 响应过短')
    b1, b2 = msg[1], msg[2]
    msg_type = (b1 >> 4) & 0x0F
    ser = (b2 >> 4) & 0x0F
    comp = b2 & 0x0F
    off = 4
    event = struct.unpack('>i', msg[off : off + 4])[0]
    off += 4

    if msg_type == _MSG_ERROR:
        err_c = struct.unpack('>I', msg[off : off + 4])[0] if len(msg) >= off + 4 else 0
        off += 4
        tail = _decomp(msg[off:], comp)
        try:
            j = json.loads(tail.decode('utf-8')) if ser == _SERIAL_JSON and tail else {}
        except json.JSONDecodeError:
            j = {}
        return {'msg_type': msg_type, 'event': event, 'error_code': err_c, 'json': j, 'payload': b''}

    if len(msg) < off + 4:
        return {'msg_type': msg_type, 'event': event, 'first_str': '', 'payload': b'', 'json': None, 'ser': ser}
    slen = struct.unpack('>I', msg[off : off + 4])[0]
    off += 4
    if len(msg) < off + slen:
        raise RuntimeError('火山 WS 响应截断')
    first_str = msg[off : off + slen].decode('utf-8', 'replace')
    off += slen
    rest = msg[off:]
    if len(rest) < 4:
        return {'msg_type': msg_type, 'event': event, 'first_str': first_str, 'payload': rest, 'json': None, 'ser': ser}
    plen = struct.unpack('>I', rest[0:4])[0]
    raw_payload = rest[4 : 4 + plen]
    payload = _decomp(raw_payload, comp)
    out: dict = {
        'msg_type': msg_type,
        'event': event,
        'first_str': first_str,
        'payload': payload,
        'json': None,
        'ser': ser,
    }
    if ser == _SERIAL_JSON and payload:
        try:
            out['json'] = json.loads(payload.decode('utf-8'))
        except json.JSONDecodeError:
            out['json'] = None
    return out


def synthesize_ws_bidirection(
    text: str,
    *,
    app_id: str,
    access_key: str,
    api_key: str,
    resource_id: str,
    speaker: str,
    audio_format: str,
    timeout: float,
    model: str | None = None,
    emotion: str | None = None,
) -> bytes:
    """一次短文本合成：建连 → StartSession → TaskRequest → FinishSession → 收齐音频 → FinishConnection。"""
    if websocket is None:
        raise RuntimeError('缺少依赖 websocket-client，请在 backend 目录执行：pip install websocket-client')

    fmt = audio_format if audio_format in ('mp3', 'wav', 'pcm', 'ogg_opus') else 'mp3'
    audio_params: dict = {
        'format': fmt,
        'sample_rate': 24000,
        'bit_rate': 32000,
    }
    if emotion and '_emo_' in speaker.lower():
        audio_params['emotion'] = emotion
        audio_params['emotion_scale'] = 4

    req_start: dict = {'speaker': speaker, 'audio_params': audio_params}
    if model:
        req_start['model'] = model

    headers = [f'X-Api-Connect-Id: {uuid.uuid4()}']
    ak = (access_key or '').strip()
    api_key = (api_key or '').strip()
    if api_key:
        headers.append(f'X-Api-Key: {api_key}')
        headers.append(f'X-Api-Resource-Id: {resource_id}')
    else:
        if not app_id or not ak:
            raise RuntimeError(
                'WebSocket V3：请在 .env 配置 VOLC_TTS_API_KEY（新版控制台），'
                '或同时配置 VOLC_TTS_APPID 与 VOLC_TTS_TOKEN（或 VOLC_TTS_ACCESS_KEY）'
            )
        headers.append(f'X-Api-App-Id: {app_id.strip()}')
        headers.append(f'X-Api-Access-Key: {ak}')
        headers.append(f'X-Api-Resource-Id: {resource_id}')

    url = 'wss://openspeech.bytedance.com/api/v3/tts/bidirection'
    deadline = time.monotonic() + max(5.0, float(timeout))

    def remaining() -> float:
        return max(0.1, deadline - time.monotonic())

    ws = websocket.create_connection(
        url,
        header=headers,
        timeout=remaining(),
        enable_multithread=False,
    )
    chunks: list[bytes] = []
    try:
        ws.settimeout(remaining())
        ws.send_binary(pack_start_connection())

        saw_connection_started = False
        while time.monotonic() < deadline:
            raw = ws.recv()
            if isinstance(raw, str):
                raise RuntimeError(f'火山 WS 收到文本帧：{raw[:400]}')
            p = parse_server_message(raw)
            ev = p['event']
            if p['msg_type'] == _MSG_ERROR or ev == EVT_CONNECTION_FAILED:
                j = p.get('json') or {}
                raise RuntimeError(f'火山 WS 建连失败 event={ev}: {j}')
            if ev == EVT_CONNECTION_STARTED:
                saw_connection_started = True
                break
        if not saw_connection_started:
            raise RuntimeError('火山 WS 超时：未收到 ConnectionStarted')

        session_id = str(uuid.uuid4())
        ws.settimeout(remaining())
        ws.send_binary(pack_start_session(session_id, req_start, 'jademirror_web'))

        saw_session_started = False
        while time.monotonic() < deadline:
            raw = ws.recv()
            if isinstance(raw, str):
                raise RuntimeError(f'火山 WS 收到文本帧：{raw[:400]}')
            p = parse_server_message(raw)
            ev = p['event']
            if ev == EVT_SESSION_FAILED:
                j = p.get('json') or {}
                raise RuntimeError(f'火山 WS SessionFailed: {j}')
            if ev == EVT_SESSION_STARTED:
                saw_session_started = True
                break
            if p['msg_type'] == _MSG_ERROR:
                j = p.get('json') or {}
                raise RuntimeError(f'火山 WS 错误帧：{j}')
        if not saw_session_started:
            raise RuntimeError('火山 WS 超时：未收到 SessionStarted')

        ws.settimeout(remaining())
        ws.send_binary(pack_task_request(session_id, text, speaker, audio_params))
        ws.send_binary(pack_finish_session(session_id))

        session_done = False
        while time.monotonic() < deadline:
            ws.settimeout(remaining())
            raw = ws.recv()
            if isinstance(raw, str):
                raise RuntimeError(f'火山 WS 收到文本帧：{raw[:400]}')
            p = parse_server_message(raw)
            ev = p['event']
            mt = p['msg_type']

            ser = p.get('ser', 0)
            if ev == EVT_TTS_RESPONSE and p.get('payload'):
                chunks.append(p['payload'])
            elif mt == _MSG_AUDIO_ONLY_SERVER and ser == _SERIAL_RAW and p.get('payload'):
                chunks.append(p['payload'])
            elif ev == EVT_TTS_RESPONSE:
                j = p.get('json') or {}
                b64 = j.get('data') or j.get('audio')
                if isinstance(b64, str) and b64:
                    try:
                        chunks.append(base64.b64decode(b64))
                    except (ValueError, TypeError):
                        pass

            if ev == EVT_SESSION_FINISHED:
                j = p.get('json') or {}
                code = j.get('status_code')
                if code is not None and int(code) != 20000000:
                    raise RuntimeError(f'火山 WS SessionFinished 异常 status_code={code}: {j.get("message")}')
                session_done = True
                break

            if ev == EVT_SESSION_FAILED:
                j = p.get('json') or {}
                raise RuntimeError(f'火山 WS SessionFailed: {j}')

            if mt == _MSG_ERROR:
                j = p.get('json') or {}
                raise RuntimeError(f'火山 WS 错误帧 event={ev}: {j}')

        if not session_done:
            raise RuntimeError('火山 WS 超时：未收到 SessionFinished')

        try:
            ws.settimeout(min(5.0, remaining()))
            ws.send_binary(pack_finish_connection())
        except Exception:
            pass
    finally:
        try:
            ws.close()
        except Exception:
            pass

    out = b''.join(chunks)
    if not out:
        raise RuntimeError('火山 WS 未收到音频数据（请核对 X-Api-Key / ResourceId 与音色 speaker）')
    return out
