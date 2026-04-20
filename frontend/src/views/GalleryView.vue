<script setup>
import { computed, ref } from 'vue'
import { useAudioStore } from '@/stores/audioStore'
import { useUserStore } from '@/stores/userStore'

const userStore = useUserStore()
const audioStore = useAudioStore()

const works = computed(() => userStore.works)
const selectedWork = ref(null)
const pageError = ref('')

function formatDate(iso) {
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) {
    return iso
  }
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function openWork(work) {
  selectedWork.value = work
}

function closeWork() {
  selectedWork.value = null
}

function removeWork(workId) {
  userStore.removeWork(workId)
  if (selectedWork.value?.id === workId) {
    selectedWork.value = null
  }
}

async function replayWorkSound(work) {
  pageError.value = ''

  try {
    await audioStore.playJadeMelody({
      jade: null,
      emotion: work.emotion,
      mode: 'touch',
      overrideAudioParams: work.audioParams,
    })
  } catch (error) {
    pageError.value = error.message || '音效回放失败。'
  }
}
</script>

<template>
  <section class="gallery section-grid">
    <p v-if="pageError" class="error-text">{{ pageError }}</p>

    <article v-if="!works.length" class="jade-card empty">
      <h3>展厅为空</h3>
      <p class="text-muted">先前往“专属玉生成”页面保存你的第一件作品。</p>
    </article>

    <div v-else class="gallery-grid">
      <article v-for="work in works" :key="work.id" class="work-card jade-card">
        <button type="button" class="image-trigger" @click="openWork(work)">
          <img :src="work.imageDataURL" :alt="work.jadeName" />
        </button>

        <div class="work-body">
          <h3>{{ work.jadeName }}</h3>
          <p class="text-muted">{{ work.jadeDynasty }}代 · {{ formatDate(work.date) }}</p>
          <p class="text-muted">情绪：{{ work.emotion }}</p>
        </div>

        <div class="actions-row">
          <button type="button" class="jade-button secondary" @click="replayWorkSound(work)">播放音效</button>
          <button type="button" class="jade-button warn" @click="removeWork(work.id)">删除</button>
        </div>
      </article>
    </div>

    <div v-if="selectedWork" class="modal" @click.self="closeWork">
      <article class="modal-card jade-card">
        <img :src="selectedWork.imageDataURL" :alt="selectedWork.jadeName" />
        <h3>{{ selectedWork.jadeName }}</h3>
        <p class="text-muted">{{ selectedWork.jadeDynasty }}代 · {{ formatDate(selectedWork.date) }}</p>
        <p class="text-muted">情绪：{{ selectedWork.emotion }}</p>
        <p class="prompt">{{ selectedWork.prompt }}</p>
        <div class="actions-row">
          <button type="button" class="jade-button secondary" @click="replayWorkSound(selectedWork)">
            重新播放触摸音效
          </button>
          <button type="button" class="jade-button primary" @click="closeWork">关闭</button>
        </div>
      </article>
    </div>
  </section>
</template>

<style scoped>
.empty {
  padding: 1rem;
  display: grid;
  gap: 0.6rem;
}

.gallery-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.8rem;
}

.work-card {
  padding: 0.75rem;
  display: grid;
  gap: 0.65rem;
  background: linear-gradient(145deg, rgba(255, 255, 255, 0.86), rgba(241, 248, 243, 0.72));
  transition: transform 0.22s ease, box-shadow 0.22s ease;
}

.work-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 16px 30px rgba(39, 72, 62, 0.12);
}

.image-trigger {
  border: none;
  padding: 0;
  background: transparent;
  border-radius: var(--radius-md);
  overflow: hidden;
  cursor: pointer;
}

.image-trigger img {
  width: 100%;
  aspect-ratio: 1 / 1;
  object-fit: cover;
  transition: transform 0.24s ease;
}

.image-trigger:hover img {
  transform: scale(1.03);
}

.work-body {
  display: grid;
  gap: 0.28rem;
}

.modal {
  position: fixed;
  inset: 0;
  background: rgba(21, 34, 31, 0.45);
  display: grid;
  place-items: center;
  padding: 1rem;
  z-index: 20;
}

.modal-card {
  width: min(760px, 100%);
  padding: 1rem;
  display: grid;
  gap: 0.7rem;
}

.modal-card img {
  width: 100%;
  max-height: 420px;
  object-fit: contain;
  border-radius: var(--radius-md);
  background: rgba(238, 245, 240, 0.78);
}

.prompt {
  max-height: 120px;
  overflow: auto;
  padding: 0.65rem;
  border-radius: var(--radius-md);
  border: 1px solid rgba(56, 89, 77, 0.2);
  background: rgba(245, 249, 246, 0.82);
  color: var(--ink-500);
}

.error-text {
  color: var(--danger);
}

@media (max-width: 1000px) {
  .gallery-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .gallery-grid {
    grid-template-columns: 1fr;
  }
}
</style>
