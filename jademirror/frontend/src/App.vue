<script setup>
import { computed, ref } from 'vue'
import { RouterLink, RouterView, useRoute, useRouter } from 'vue-router'
import CompanionPanel from '@/components/CompanionPanel.vue'
import { useAudioStore } from '@/stores/audioStore'
import { useAuthStore } from '@/stores/authStore'

const route = useRoute()
const router = useRouter()
const audioStore = useAudioStore()
const authStore = useAuthStore()
const showAbout = ref(false)

const titleMap = {
  Home: {
    title: '玉镜 · 照心',
    subtitle: '在旋转玉璧中开启一段古今对话。',
  },
  Test: {
    title: '照心测试',
    subtitle: '选择你偏爱的意象，我们将为你匹配最契合的古玉。',
  },
  Login: {
    title: '账号登录',
    subtitle: '登录后可开启完整体验并保留你的藏玉轨迹。',
  },
  Result: {
    title: '匹配结果',
    subtitle: '你的心性已映入玉中。',
  },
  Chat: {
    title: '人格对话',
    subtitle: '让千年古玉以第一人称回应你的提问。',
  },
  Generate: {
    title: '生成专属玉',
    subtitle: '融合偏好与情绪，生成只属于你的数字玉器。',
  },
  Gallery: {
    title: '个人藏室',
    subtitle: '你的作品将沉淀成一座可回看的私藏宝阁。',
  },
}

const pageTitle = computed(() => titleMap[route.name] || titleMap.Home)
const isHome = computed(() => route.name === 'Home')
const soundLabel = computed(() => (audioStore.muted ? '音效关' : '音效开'))
const authLabel = computed(() => (authStore.isLoggedIn ? '退出登录' : '登录'))

function toggleSound() {
  audioStore.setMuted(!audioStore.muted)
}

async function handleAuthAction() {
  if (authStore.isLoggedIn) {
    await authStore.logout()
    router.push('/login')
    return
  }

  router.push('/login')
}
</script>

<template>
  <div class="app-shell">
    <header class="topbar jade-card">
      <RouterLink to="/" class="brand" aria-label="回到玉镜主页">
        <span class="brand-seal">玉</span>
        <div>
          <p class="brand-cn">玉镜</p>
          <p class="brand-en">JadeMirror</p>
        </div>
      </RouterLink>
      <div class="top-actions" aria-label="站点工具">
        <RouterLink to="/" class="tool-link">主页</RouterLink>
        <RouterLink to="/gallery" class="tool-link">个人藏室</RouterLink>
        <span v-if="authStore.isLoggedIn" class="user-badge">{{ authStore.displayName }}</span>
        <button type="button" class="tool-btn" @click="handleAuthAction">{{ authLabel }}</button>
        <button type="button" class="tool-btn" @click="toggleSound">{{ soundLabel }}</button>
        <button type="button" class="tool-btn" @click="showAbout = true">关于</button>
      </div>
    </header>

    <main class="page-wrap">
      <section v-if="!isHome" class="page-heading jade-card">
        <h1>{{ pageTitle.title }}</h1>
        <p>{{ pageTitle.subtitle }}</p>
      </section>

      <RouterView v-slot="{ Component }">
        <Transition name="mist" mode="out-in">
          <component :is="Component" />
        </Transition>
      </RouterView>
    </main>

    <div v-if="showAbout" class="about-layer" @click.self="showAbout = false">
      <article class="about-card jade-card">
        <h2>玉镜 JadeMirror</h2>
        <p>
          以玉为镜，照见本心。你将通过照心测试匹配一件古玉，再与它对话、生成专属玉作，并将作品收藏于个人藏室。
        </p>
        <button type="button" class="jade-button primary" @click="showAbout = false">知道了</button>
      </article>
    </div>

    <CompanionPanel v-if="authStore.isLoggedIn" />
  </div>
</template>

<style scoped>
.app-shell {
  min-height: 100vh;
  width: min(1200px, calc(100vw - 2rem));
  margin: 0 auto;
  padding: 1.25rem 0 2.5rem;
}

.topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem 1.2rem;
}

.brand {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  color: inherit;
  text-decoration: none;
}

.brand-seal {
  width: 2.2rem;
  height: 2.2rem;
  display: grid;
  place-items: center;
  border-radius: 999px;
  background: linear-gradient(160deg, #89a795, #dce9e2);
  color: #10271f;
  font-size: 1.2rem;
  font-weight: 700;
}

.brand-cn {
  margin: 0;
  font-family: 'Ma Shan Zheng', cursive;
  font-size: 1.3rem;
  line-height: 1;
}

.brand-en {
  margin: 0;
  font-size: 0.7rem;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  opacity: 0.75;
}

.top-actions {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.4rem;
}

.user-badge {
  display: inline-flex;
  align-items: center;
  border-radius: 999px;
  border: 1px solid rgba(54, 92, 79, 0.18);
  background: rgba(234, 244, 237, 0.82);
  color: var(--ink-600);
  font-size: 0.8rem;
  padding: 0.35rem 0.7rem;
}

.tool-link {
  text-decoration: none;
  border: 1px solid rgba(56, 90, 77, 0.22);
  background: rgba(248, 252, 249, 0.85);
  color: var(--ink-700);
  padding: 0.35rem 0.72rem;
  border-radius: 999px;
  font-size: 0.82rem;
  transition: transform 0.2s ease, background-color 0.2s ease;
}

.tool-link:hover {
  background: rgba(92, 131, 110, 0.12);
  transform: translateY(-1px);
}

.tool-link.router-link-active {
  background: rgba(45, 89, 75, 0.85);
  color: #eff6f2;
  border-color: transparent;
}

.tool-btn {
  border: 1px solid rgba(56, 90, 77, 0.22);
  background: rgba(248, 252, 249, 0.85);
  color: var(--ink-700);
  padding: 0.35rem 0.72rem;
  border-radius: 999px;
  font-size: 0.82rem;
  cursor: pointer;
  transition: transform 0.2s ease, background-color 0.2s ease;
}

.tool-btn:hover {
  background: rgba(92, 131, 110, 0.12);
  transform: translateY(-1px);
}

.page-wrap {
  margin-top: 1rem;
  display: grid;
  gap: 1rem;
}

.page-heading {
  padding: 1.1rem 1.2rem;
  background: linear-gradient(115deg, rgba(229, 239, 232, 0.9), rgba(247, 244, 236, 0.96));
}

.page-heading h1 {
  margin: 0;
  font-size: clamp(1.45rem, 2.6vw, 2rem);
}

.page-heading p {
  margin: 0.3rem 0 0;
  color: var(--ink-500);
}

.mist-enter-active,
.mist-leave-active {
  transition: opacity 0.28s ease, transform 0.28s ease;
}

.mist-enter-from,
.mist-leave-to {
  opacity: 0;
  transform: translateY(6px);
}

.about-layer {
  position: fixed;
  inset: 0;
  background: rgba(16, 33, 30, 0.36);
  display: grid;
  place-items: center;
  padding: 1rem;
  z-index: 30;
}

.about-card {
  width: min(560px, 100%);
  padding: 1rem;
  display: grid;
  gap: 0.75rem;
}

.about-card h2 {
  margin: 0;
}

.about-card p {
  margin: 0;
  color: var(--ink-500);
  line-height: 1.65;
}

@media (max-width: 920px) {
  .topbar {
    padding: 0.85rem 1rem;
  }
}
</style>
