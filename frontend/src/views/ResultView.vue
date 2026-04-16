<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/userStore'

const userStore = useUserStore()
const router = useRouter()

const jade = computed(() => userStore.matchedJade)
const scorePercent = computed(() => Math.round((userStore.matchScore || 0) * 100))
</script>

<template>
  <section class="result section-grid">
    <article v-if="jade" class="result-card jade-card">
      <img :src="jade.image" :alt="jade.name" class="jade-image" />

      <div class="result-info">
        <p class="status-pill">匹配度 {{ scorePercent }}%</p>
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
