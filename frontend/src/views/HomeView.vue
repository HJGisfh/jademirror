<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import JadeMirrorScene from '@/components/JadeMirrorScene.vue'
import { useUserStore } from '@/stores/userStore'

const router = useRouter()
const userStore = useUserStore()

const hasWorks = computed(() => userStore.works.length > 0)

function startJourney() {
  router.push('/test')
}

function visitGallery() {
  router.push('/gallery')
}
</script>

<template>
  <section class="home">
    <article class="mirror-stage jade-card">
      <JadeMirrorScene />

      <div class="stage-copy">
        <h1>以玉为镜，照见本心</h1>
        <p class="stage-subtitle">在旋转玉璧中开启一段古今对话。</p>
        <p class="stage-desc">让传统玉器拥有可对话、可生成、可触摸的数字生命。</p>

        <button type="button" class="jade-button primary main-cta" @click="startJourney">开始照心</button>

        <button
          type="button"
          class="gallery-link"
          :class="{ weak: !hasWorks }"
          @click="visitGallery"
        >
          {{ hasWorks ? '参观展厅' : '参观展厅（暂无藏玉）' }}
        </button>
      </div>
    </article>
  </section>
</template>

<style scoped>
.home {
  display: grid;
}

.mirror-stage {
  padding: 1rem;
  display: grid;
  gap: 1rem;
  justify-items: center;
  background:
    radial-gradient(circle at 50% 16%, rgba(237, 247, 241, 0.7), rgba(247, 242, 233, 0.85));
}

.stage-copy {
  width: min(760px, 100%);
  display: grid;
  justify-items: center;
  text-align: center;
  gap: 0.6rem;
}

.stage-copy h1 {
  margin: 0;
  font-size: clamp(1.55rem, 3.6vw, 2.35rem);
  letter-spacing: 0.03em;
}

.stage-subtitle {
  margin: 0;
  color: var(--ink-500);
  font-size: 1.02rem;
}

.stage-desc {
  margin: 0;
  color: var(--ink-400);
  font-size: 0.95rem;
}

.main-cta {
  margin-top: 0.35rem;
  min-width: 156px;
  font-size: 1rem;
}

.gallery-link {
  border: none;
  background: transparent;
  color: var(--ink-500);
  font-size: 0.9rem;
  text-decoration: underline;
  text-decoration-thickness: 1px;
  text-underline-offset: 0.25rem;
  cursor: pointer;
}

.gallery-link.weak {
  color: rgba(93, 118, 110, 0.65);
}

@media (max-width: 720px) {
  .mirror-stage {
    padding: 0.75rem;
  }
}
</style>
