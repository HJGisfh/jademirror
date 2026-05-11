import { defineStore } from 'pinia'
import http from '@/api/http'

const AUTH_USER_KEY = 'jademirror-auth-user-v1'
const AUTH_TOKEN_KEY = 'jademirror-auth-token-v1'

function readJSON(key, fallback) {
  try {
    const raw = localStorage.getItem(key)
    return raw ? JSON.parse(raw) : fallback
  } catch {
    return fallback
  }
}

function writeJSON(key, value) {
  localStorage.setItem(key, JSON.stringify(value))
}

function readToken() {
  try {
    return localStorage.getItem(AUTH_TOKEN_KEY) || ''
  } catch {
    return ''
  }
}

function writeToken(token) {
  localStorage.setItem(AUTH_TOKEN_KEY, token || '')
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    currentUser: readJSON(AUTH_USER_KEY, null),
    token: readToken(),
    sessionChecked: false,
  }),
  getters: {
    // 以令牌为准：避免仅有 token、用户信息尚未写回内存时被当成未登录（刷新 / hydrates 时序）
    isLoggedIn: (state) => Boolean(state.token),
    displayName: (state) =>
      state.currentUser?.nickname ||
      state.currentUser?.username ||
      (state.token ? '已登录' : '未登录'),
  },
  actions: {
    /**
     * 从 localStorage 拉回 token/user，避免 Pinia 内存与存储不一致时误判未登录。
     * 禁止在「未同步」时用 clearAuth()，否则会清空仍存在于 localStorage 的令牌。
     */
    hydrateFromStorage() {
      const t = readToken()
      const u = readJSON(AUTH_USER_KEY, null)
      if (t) {
        this.token = t
      }
      if (u && typeof u === 'object') {
        this.currentUser = u
      }
    },
    async _syncWorksAfterAuth() {
      try {
        const { useUserStore } = await import('./userStore')
        const userStore = useUserStore()
        await userStore.fetchWorks()
      } catch {
        // ignore sync failures
      }
    },
    applyAuth({ user, token }) {
      this.currentUser = user || null
      this.token = token || ''
      writeJSON(AUTH_USER_KEY, this.currentUser)
      writeToken(this.token)
    },
    clearAuth() {
      this.currentUser = null
      this.token = ''
      writeJSON(AUTH_USER_KEY, null)
      writeToken('')
    },
    async register({ username, password, nickname }) {
      const { data } = await http.post('/auth/register', {
        username,
        password,
        nickname,
      })

      this.applyAuth({ user: data.user, token: data.token })
      this.sessionChecked = true
      await this._syncWorksAfterAuth()
      return data.user
    },
    async guestLogin() {
      const { data } = await http.post('/auth/guest')

      this.applyAuth({ user: data.user, token: data.token })
      this.sessionChecked = true
      await this._syncWorksAfterAuth()
      return data.user
    },
    async login({ username, password }) {
      const { data } = await http.post('/auth/login', {
        username,
        password,
      })

      this.applyAuth({ user: data.user, token: data.token })
      this.sessionChecked = true
      await this._syncWorksAfterAuth()
      return data.user
    },
    async fetchMe() {
      this.hydrateFromStorage()
      if (!this.token) {
        this.clearAuth()
        return null
      }

      const { data } = await http.get('/auth/me')
      this.applyAuth({ user: data.user, token: this.token })
      return data.user
    },
    async ensureSession() {
      if (this.sessionChecked) {
        return this.isLoggedIn
      }

      // 必须先同步存储，再判断是否有令牌；否则内存为空时会误 clearAuth 抹掉 localStorage 里的有效 token
      this.hydrateFromStorage()

      if (!this.token) {
        this.sessionChecked = true
        this.clearAuth()
        return false
      }

      try {
        const user = await this.fetchMe()
        this.sessionChecked = true
        if (user === null && !this.token) {
          return false
        }
        await this._syncWorksAfterAuth()
        return true
      } catch (error) {
        const status = error?.status
        // 仅当服务端明确拒绝会话时再清空本地令牌（过期、无效 token）
        if (status === 401 || status === 403) {
          this.clearAuth()
          this.sessionChecked = true
          return false
        }
        // 网络异常、超时、5xx、后端未启动等：保留令牌，不把用户踢回登录页
        this.sessionChecked = true
        return !!this.token
      }
    },
    async logout() {
      try {
        if (this.token) {
          await http.post('/auth/logout')
        }
      } catch {
        // ignore logout network errors
      }

      // 清空认证信息
      this.clearAuth()
      this.sessionChecked = true
      
      // 清空用户数据
      const { useUserStore } = await import('./userStore')
      const userStore = useUserStore()
      userStore.resetTest()  // 清空测试答案、匹配结果、生成的图片等
      userStore.works = []  // 清空展厅作品
      userStore.persistWorks()  // 持久化空数组
      
      // 清空助手数据
      const { useAssistantStore } = await import('./assistantStore')
      const assistantStore = useAssistantStore()
      assistantStore.messages = []  // 清空对话历史
      assistantStore.memories = []  // 清空记忆
      assistantStore.lastMemoryDigest = ''
      assistantStore.guidedTestActive = false  // 重置测试状态
      assistantStore.guidedQuestionIndex = 0
      assistantStore.galleryTourAuto = false  // 停止展厅导览
      assistantStore.teardown()  // 清理定时器
      
      console.log('✅ 用户登出，所有数据已清空')
    },
  },
})
