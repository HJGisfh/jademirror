import http from '@/api/http'

export async function requestDeepSeekChat(payload) {
  const { data } = await http.post('/deepseek/chat', payload)
  return data
}

export async function requestQwenImage(payload) {
  const { data } = await http.post('/qwen/image', payload)
  return data
}

export async function request3DGeneration(payload) {
  const { data } = await http.post('/3d/generate', payload, { timeout: 600000 })
  return data
}

export async function requestAssistantTurn(payload) {
  const { data } = await http.post('/assistant/turn', payload)
  return data
}

export async function requestAssistantProactive(payload) {
  const { data } = await http.post('/assistant/proactive', payload)
  return data
}

export async function fetchAssistantMemories() {
  const { data } = await http.get('/assistant/memories')
  return data
}

export async function pinAssistantMemory(memoryId, pinned) {
  const { data } = await http.patch(`/assistant/memories/${memoryId}/pin`, { pinned })
  return data
}

export async function deleteAssistantMemory(memoryId) {
  const { data } = await http.delete(`/assistant/memories/${memoryId}`)
  return data
}

export async function clearAssistantMemories() {
  const { data } = await http.delete('/assistant/memories')
  return data
}

export async function exportAssistantMemories() {
  const { data } = await http.get('/assistant/memories/export')
  return data
}

/**
 * 火山豆包 TTS 代理：把文本/persona/mood 发到后端，拿回 mp3 二进制 Blob。
 * 失败抛 Error 由调用方决定回退。
 */
export async function synthesizeVoiceCloud({ text, persona = 'default', mood = '' }) {
  const { data } = await http.post(
    '/voice/tts',
    { text, persona, mood, encoding: 'mp3' },
    { responseType: 'blob' },
  )
  return data
}

export async function fetchHealth() {
  const { data } = await http.get('/health')
  return data
}
