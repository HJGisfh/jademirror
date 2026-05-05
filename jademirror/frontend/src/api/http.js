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
    return Promise.reject(new Error(backendError || error.message || '请求失败'))
  },
)

export default http
