import http from '@/api/http'

export async function requestDeepSeekChat(payload) {
  const { data } = await http.post('/deepseek/chat', payload)
  return data
}

export async function requestQwenImage(payload) {
  const { data } = await http.post('/qwen/image', payload)
  return data
}
