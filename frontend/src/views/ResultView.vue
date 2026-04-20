<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/userStore'

const userStore = useUserStore()
const router = useRouter()

const jade = computed(() => userStore.matchedJade)
const scorePercent = computed(() => Math.round((userStore.matchScore || 0) * 100))
const scoreStyle = computed(() => ({
  '--score-angle': `${Math.max(0, Math.min(100, scorePercent.value)) * 3.6}deg`,
}))
</script>

<template>
  <section class="result section-grid">
    <article v-if="jade" class="result-card jade-card">
      <img :src="jade.image" :alt="jade.name" class="jade-image" />

      <div class="result-info">
        <div class="score-wrap" :style="scoreStyle">
          <div class="score-inner">
            <p class="score-num">{{ scorePercent }}%</p>
            <p class="score-label">匹配度</p>
          </div>
        </div>
        <h2>{{ jade.dynasty }}代 · {{ jade.name }}</h2>
        <p class="text-muted">{{ jade.description }}</p>

        <div class="reason-box">
          <h3>匹配理由</h3>
          <p>{{ userStore.matchReason }}</p>
        </div>

        <div class="actions-row">
          <button type="button" class="jade-button primary" @click="router.push('/chat')">
            与玉对话
          </button>
          <button type="button" class="jade-button secondary" @click="router.push('/generate')">
            生成专属玉
          </button>
          <button type="button" class="jade-button secondary" @click="router.push('/test')">
            重新测试
          </button>
        </div>
      </div>
    </article>

    <article v-else class="jade-card fallback">
      <p class="text-muted">暂无匹配结果，请先完成心理测试。</p>
      <button type="button" class="jade-button primary" @click="router.push('/test')">前往测试</button>
    </article>
  </section>
</template>

<style scoped>
.result-card {
  padding: 1rem;
  display: grid;
  grid-template-columns: 1fr 1.2fr;
  gap: 1rem;
}

.jade-image {
  width: 100%;
  border-radius: var(--radius-md);
  aspect-ratio: 1 / 1;
  object-fit: cover;
  border: 1px solid rgba(65, 99, 86, 0.18);
}

.result-info {
  display: grid;
  align-content: flex-start;
  gap: 0.7rem;
}

.score-wrap {
  width: 112px;
  height: 112px;
  border-radius: 999px;
  display: grid;
  place-items: center;
  background: conic-gradient(#2d6d59 var(--score-angle), rgba(117, 157, 139, 0.22) 0);
  box-shadow: inset 0 0 0 1px rgba(45, 94, 77, 0.18);
}

.score-inner {
  width: 86px;
  height: 86px;
  border-radius: 999px;
  background: rgba(248, 252, 250, 0.95);
  border: 1px solid rgba(56, 92, 79, 0.18);
  display: grid;
  align-content: center;
  justify-items: center;
}

.score-num {
  font-size: 1.2rem;
  font-weight: 700;
  color: var(--ink-700);
}

.score-label {
  margin-top: 0.05rem;
  font-size: 0.76rem;
  color: var(--ink-500);
}

.reason-box {
  padding: 0.75rem;
  border-radius: var(--radius-md);
  background: rgba(231, 241, 234, 0.62);
  border: 1px solid rgba(64, 98, 86, 0.16);
}

.reason-box h3 {
  margin-bottom: 0.42rem;
  font-size: 1rem;
}

.fallback {
  padding: 1rem;
  display: grid;
  gap: 0.8rem;
}

@media (max-width: 820px) {
  .result-card {
    grid-template-columns: 1fr;
  }
}
</style>
