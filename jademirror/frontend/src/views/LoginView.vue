<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/authStore'

const authStore = useAuthStore()
const route = useRoute()
const router = useRouter()

const mode = ref('login')
const submitting = ref(false)
const errorText = ref('')
const successText = ref('')

const loginForm = reactive({
  username: '',
  password: '',
})

const registerForm = reactive({
  username: '',
  nickname: '',
  password: '',
  confirmPassword: '',
})

const redirectPath = computed(() => {
  const queryRedirect = route.query.redirect
  if (typeof queryRedirect === 'string' && queryRedirect.startsWith('/')) {
    return queryRedirect
  }
  return '/'
})

function switchMode(nextMode) {
  mode.value = nextMode
  errorText.value = ''
  successText.value = ''
}

async function handleLogin() {
  submitting.value = true
  errorText.value = ''
  successText.value = ''

  try {
    await authStore.login(loginForm)
    successText.value = '登录成功，正在进入玉镜。'
    router.replace(redirectPath.value)
  } catch (error) {
    errorText.value = error.message || '登录失败，请重试。'
  } finally {
    submitting.value = false
  }
}

async function handleRegister() {
  submitting.value = true
  errorText.value = ''
  successText.value = ''

  try {
    if (registerForm.password !== registerForm.confirmPassword) {
      throw new Error('两次输入的密码不一致。')
    }

    await authStore.register(registerForm)
    successText.value = '注册成功，正在进入主页。'
    router.replace(redirectPath.value)
  } catch (error) {
    errorText.value = error.message || '注册失败，请重试。'
  } finally {
    submitting.value = false
  }
}

async function handleGuestLogin() {
  submitting.value = true
  errorText.value = ''
  successText.value = ''

  try {
    await authStore.guestLogin()
    successText.value = '游客登录成功，正在进入玉镜。'
    router.replace(redirectPath.value)
  } catch (error) {
    errorText.value = error.message || '游客登录失败，请重试。'
  } finally {
    submitting.value = false
  }
}

onMounted(() => {
  if (authStore.isLoggedIn) {
    router.replace(redirectPath.value)
  }
})
</script>

<template>
  <section class="login-page">
    <article class="login-card jade-card">
      <header class="login-head">
        <h2>进入玉镜</h2>
        <p class="text-muted">登录后可保存测试轨迹、对话记录与个人藏玉作品。</p>
        <p class="hint-text">注册要求：用户名至少 3 个字符，密码至少 6 位，且用户名不能重复。</p>
      </header>

      <div class="mode-switch">
        <button
          type="button"
          class="mode-btn"
          :class="{ active: mode === 'login' }"
          @click="switchMode('login')"
        >
          账号登录
        </button>
        <button
          type="button"
          class="mode-btn"
          :class="{ active: mode === 'register' }"
          @click="switchMode('register')"
        >
          新建账号
        </button>
      </div>

      <form v-if="mode === 'login'" class="form-grid" @submit.prevent="handleLogin">
        <label>
          用户名
          <input v-model="loginForm.username" type="text" autocomplete="username" placeholder="请输入用户名" />
        </label>

        <label>
          密码
          <input
            v-model="loginForm.password"
            type="password"
            autocomplete="current-password"
            placeholder="请输入密码"
          />
        </label>

        <button type="submit" class="jade-button primary" :disabled="submitting">
          {{ submitting ? '登录中...' : '登录并进入' }}
        </button>
      </form>

      <form v-else class="form-grid" @submit.prevent="handleRegister">
        <label>
          用户名
          <input v-model="registerForm.username" type="text" autocomplete="username" placeholder="至少 3 个字符" />
        </label>

        <label>
          昵称
          <input v-model="registerForm.nickname" type="text" autocomplete="nickname" placeholder="可选，默认与用户名一致" />
        </label>

        <label>
          密码
          <input
            v-model="registerForm.password"
            type="password"
            autocomplete="new-password"
            placeholder="至少 6 位"
          />
        </label>

        <label>
          确认密码
          <input
            v-model="registerForm.confirmPassword"
            type="password"
            autocomplete="new-password"
            placeholder="再次输入密码"
          />
        </label>

        <button type="submit" class="jade-button primary" :disabled="submitting">
          {{ submitting ? '创建中...' : '注册并进入' }}
        </button>
      </form>

      <div class="guest-section">
        <button
          type="button"
          class="guest-btn"
          :disabled="submitting"
          @click="handleGuestLogin"
        >
          {{ submitting ? '登录中...' : '游客登录' }}
        </button>
        <p class="guest-hint">无需注册，一键进入体验。</p>
      </div>

      <p v-if="errorText" class="error-text">{{ errorText }}</p>
      <p v-if="successText" class="success-text">{{ successText }}</p>
    </article>
  </section>
</template>

<style scoped>
.login-page {
  display: grid;
  place-items: center;
}

.login-card {
  width: min(560px, 100%);
  padding: 1rem;
  display: grid;
  gap: 0.9rem;
}

.login-head {
  display: grid;
  gap: 0.42rem;
}

.hint-text {
  font-size: 0.85rem;
  color: var(--ink-500);
}

.mode-switch {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.5rem;
}

.mode-btn {
  border: 1px solid rgba(57, 94, 80, 0.2);
  background: rgba(238, 245, 240, 0.85);
  color: var(--ink-600);
  border-radius: 999px;
  padding: 0.45rem 0.72rem;
  cursor: pointer;
}

.mode-btn.active {
  background: rgba(47, 88, 74, 0.88);
  color: #f1f7f4;
  border-color: transparent;
}

.form-grid {
  display: grid;
  gap: 0.7rem;
}

label {
  display: grid;
  gap: 0.3rem;
  color: var(--ink-700);
  font-size: 0.92rem;
}

input {
  border: 1px solid rgba(58, 94, 81, 0.22);
  border-radius: var(--radius-md);
  background: rgba(255, 255, 255, 0.9);
  padding: 0.58rem 0.7rem;
  outline: none;
}

input:focus {
  border-color: rgba(52, 95, 80, 0.55);
}

.guest-section {
  display: grid;
  gap: 0.3rem;
  padding-top: 0.2rem;
  border-top: 1px solid rgba(58, 91, 79, 0.1);
}

.guest-btn {
  border: 1px solid rgba(57, 94, 80, 0.22);
  background: rgba(238, 245, 240, 0.85);
  color: var(--ink-600);
  border-radius: 999px;
  padding: 0.5rem 0.72rem;
  cursor: pointer;
  font-size: 0.92rem;
  transition: background 0.2s ease, transform 0.2s ease;
}

.guest-btn:hover:not(:disabled) {
  background: rgba(92, 131, 110, 0.18);
  transform: translateY(-1px);
}

.guest-btn:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.guest-hint {
  margin: 0;
  font-size: 0.78rem;
  color: var(--ink-400);
  text-align: center;
}

.error-text {
  color: var(--danger);
}

.success-text {
  color: #2d7058;
}
</style>
