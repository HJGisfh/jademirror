import { createRouter, createWebHistory } from 'vue-router'
import pinia from '@/stores'
import { useUserStore } from '@/stores/userStore'
import { useAuthStore } from '@/stores/authStore'

const routes = [
  {
    path: '/',
    name: 'Home',
    component: () => import('@/views/HomeView.vue'),
  },
  {
    path: '/test',
    name: 'Test',
    component: () => import('@/views/TestView.vue'),
  },
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/LoginView.vue'),
  },
  {
    path: '/result',
    name: 'Result',
    component: () => import('@/views/ResultView.vue'),
  },
  {
    path: '/chat',
    name: 'Chat',
    component: () => import('@/views/ChatView.vue'),
  },
  {
    path: '/generate',
    name: 'Generate',
    component: () => import('@/views/GenerateView.vue'),
  },
  {
    path: '/gallery',
    name: 'Gallery',
    component: () => import('@/views/GalleryView.vue'),
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior() {
    return { top: 0 }
  },
})

const guardNames = new Set(['Result', 'Chat', 'Generate'])
const publicNames = new Set(['Login'])

router.beforeEach(async (to) => {
  const userStore = useUserStore(pinia)
  const authStore = useAuthStore(pinia)

  await authStore.ensureSession()

  if (!authStore.isLoggedIn && !publicNames.has(to.name)) {
    return { name: 'Login', query: { redirect: to.fullPath } }
  }

  if (authStore.isLoggedIn && to.name === 'Login') {
    return { name: 'Home' }
  }

  if (!guardNames.has(to.name)) {
    return true
  }

  if (!userStore.matchedJade) {
    return { name: 'Test' }
  }

  return true
})

export default router
