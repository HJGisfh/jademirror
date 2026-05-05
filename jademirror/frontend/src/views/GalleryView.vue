<script setup>
import { computed, ref } from 'vue'
import { useAudioStore } from '@/stores/audioStore'
import { useAssistantStore } from '@/stores/assistantStore'
import { useUserStore } from '@/stores/userStore'

const userStore = useUserStore()
const audioStore = useAudioStore()
const assistantStore = useAssistantStore()

const traitLabels = {
  landscape: '山水',
  color: '色泽',
  symbol: '纹样',
  mood: '气韵',
  texture: '质地',
}

const dynastySuffixes = ['良渚', '红山', '龙山', '仰韶', '河姆渡', '大汶口', '三星堆']

function getEraLabel(dynasty) {
  if (!dynasty) return ''
  if (dynastySuffixes.includes(dynasty)) return `${dynasty}文化`
  return `${dynasty}代`
}

function buildJadeIntro(work) {
  const parts = []
  if (work.jadeDescription) parts.push(work.jadeDescription)
  if (work.jadeTraits && Object.keys(work.jadeTraits).length) {
    const traitParts = []
    for (const [key, val] of Object.entries(work.jadeTraits)) {
      const label = traitLabels[key] || key
      traitParts.push(`${label}：${val}`)
    }
    if (traitParts.length) parts.push(traitParts.join('，'))
  }
  return parts.join('。')
}

const works = computed(() => userStore.works)
const tourActive = computed(() => assistantStore.galleryTourIndex >= 0)
const autoTour = computed(() => assistantStore.galleryTourAuto)
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
      mode: 'touch',
      overrideAudioParams: work.audioParams,
    })
  } catch (error) {
    pageError.value = error.message || '音效回放失败。'
  }
}

function startVoiceTour() {
  assistantStore.guideGalleryTour(works.value)
}

function nextTourItem() {
  assistantStore.nextGalleryWork()
}

function prevTourItem() {
  assistantStore.prevGalleryWork()
}

function stopTour() {
  assistantStore.stopGalleryTour()
}

function toggleAutoTour() {
  if (!tourActive.value) {
    return
  }
  if (assistantStore.galleryTourAuto) {
    assistantStore.pauseAutoGalleryTour()
  } else {
    assistantStore.startAutoGalleryTour()
  }
}
</script>

<template>
  <section class="gallery section-grid">
    <div class="actions-row top-guide">
      <button type="button" class="jade-button secondary" @click="startVoiceTour">开启藏室语音导览</button>
      <button type="button" class="jade-button secondary" :disabled="!tourActive" @click="prevTourItem">上一件</button>
      <button type="button" class="jade-button secondary" :disabled="!tourActive" @click="nextTourItem">下一件</button>
      <button type="button" class="jade-button secondary" :disabled="!tourActive" @click="toggleAutoTour">
        {{ autoTour ? '暂停自动' : '自动播放' }}
      </button>
      <button type="button" class="jade-button warn" :disabled="!tourActive" @click="stopTour">结束导览</button>
    </div>
    <p v-if="pageError" class="error-text">{{ pageError }}</p>

    <article v-if="!works.length" class="jade-card empty">
      <h3>藏室为空</h3>
      <p class="text-muted">先前往“专属玉生成”页面保存你的第一件作品。</p>
    </article>

    <div v-else class="gallery-grid">
      <article v-for="work in works" :key="work.id" class="work-card jade-card">
        <button type="button" class="image-trigger" @click="openWork(work)">
          <img :src="work.imageDataURL" :alt="work.jadeName" />
        </button>

        <div class="work-body">
          <h3>{{ work.jadeName }}</h3>
          <p class="text-muted">{{ getEraLabel(work.jadeDynasty) }} · {{ formatDate(work.date) }}</p>
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
        <p class="text-muted">{{ getEraLabel(selectedWork.jadeDynasty) }} · {{ formatDate(selectedWork.date) }}</p>
        <p v-if="selectedWork.jadeDescription || selectedWork.jadeTraits" class="jade-intro">{{ buildJadeIntro(selectedWork) }}</p>
        <p v-if="selectedWork.jadePersonality" class="jade-personality">{{ selectedWork.jadePersonality }}</p>
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

.top-guide {
  justify-content: flex-end;
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

.jade-intro {
  margin: 0.4rem 0 0;
  font-size: 0.88rem;
  line-height: 1.7;
  color: var(--ink-700);
}

.jade-personality {
  margin: 0.4rem 0 0;
  font-size: 0.84rem;
  line-height: 1.7;
  color: var(--ink-600);
  font-style: italic;
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
