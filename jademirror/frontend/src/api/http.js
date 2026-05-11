import axios from 'axios'

const AUTH_TOKEN_KEY = 'jademirror-auth-token-v1'

const http = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/api',
  timeout: 60000,
})

http.interceptors.request.use((config) => {
  try {
    const token = localStorage.getItem(AUTH_TOKEN_KEY)
    if (token) {
      config.headers = config.headers || {}
      if (!config.headers.Authorization) {
        config.headers.Authorization = `Bearer ${token}`
      }
    }
  } catch {
    // ignore localStorage failures
  }

  return config
})

http.interceptors.response.use(
  (response) => response,
  (error) => {
    const backendError = error.response?.data?.error
    const message = backendError || error.message || '请求失败'
    const wrapped = new Error(message)
    // 供 authStore 等区分「未授权」与「网络/超时/5xx」，避免刷新时误清空登录态
    if (error.response?.status != null) {
      wrapped.status = error.response.status
    }
    if (error.code) {
      wrapped.code = error.code
    }
    return Promise.reject(wrapped)
  },
)

export default http
