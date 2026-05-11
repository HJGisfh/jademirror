// 开发环境下若用 127.0.0.1 打开页面，统一到 localhost，避免与 localhost 的登录取的不是同一套 localStorage
if (import.meta.env.DEV && typeof window !== 'undefined' && window.location.hostname === '127.0.0.1') {
  const next = new URL(window.location.href)
  next.hostname = 'localhost'
  window.location.replace(next.toString())
}

import { createApp } from 'vue'
import './style.css'
import App from './App.vue'
import router from './router'
import pinia from './stores'

createApp(App).use(pinia).use(router).mount('#app')
