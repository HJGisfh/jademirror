<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import EmotionCapture from '@/components/EmotionCapture.vue'
import { emotionLabelMap } from '@/data/questions'
import { useApiStore } from '@/stores/apiStore'
import { useAudioStore } from '@/stores/audioStore'
import { useUserStore } from '@/stores/userStore'
import { createFallbackJadeDataURL, urlToDataURL } from '@/utils/image'
import { buildImagePrompt } from '@/utils/prompt'

const userStore = useUserStore()
const apiStore = useApiStore()
const audioStore = useAudioStore()

const jade = computed(() => userStore.matchedJade)
const currentEmotion = computed(() => userStore.currentEmotion)

const promptText = ref(userStore.lastPrompt || '')
const previewImage = ref(userStore.generatedImageDataUrl || '')
const pageError = ref('')
const saveNotice = ref('')

let pressTimer = null

async function generateJade() {
  if (!jade.value) {
    return
  }

  saveNotice.value = ''
  pageError.value = ''

  const prompt = buildImagePrompt({
    answers: userStore.testAnswers,
    jade: jade.value,
    emotion: currentEmotion.value,
  })

  promptText.value = prompt

  try {
    const imageUrl = await apiStore.generateImage({ prompt })

    if (!imageUrl) {
      throw new Error('生成接口未返回图片地址。')
    }

    let dataUrl
    try {
      dataUrl = await urlToDataURL(imageUrl)
    } catch {
      dataUrl = imageUrl
    }

    previewImage.value = dataUrl
    userStore.setGeneratedResult({ imageDataUrl: dataUrl, prompt })
  } catch (error) {
    pageError.value = error.message || '图像生成失败，已回退到占位图。'

    const fallbackDataUrl = createFallbackJadeDataURL(jade.value.name)
    previewImage.value = fallbackDataUrl
    userStore.setGeneratedResult({ imageDataUrl: fallbackDataUrl, prompt })
  }
}

async function replayTouchSound() {
  if (!jade.value) {
    return
  }

  try {
    await audioStore.playDynamicSound({
      jade: jade.value,
      emotion: currentEmotion.value,
    })
  } catch (error) {
    pageError.value = error.message || '当前浏览器无法播放音效。'
  }
}

function beginPress() {
  clearTimeout(pressTimer)
  pressTimer = window.setTimeout(() => {
    replayTouchSound()
  }, 800)
}

function endPress() {
  clearTimeout(pressTimer)
}

function saveToGallery() {
  const work = userStore.saveCurrentWork()
  saveNotice.value = work ? '已保存到个人展厅。' : '请先生成专属玉图像。'
}

function handleEmotionChange(emotion) {
  userStore.setEmotion(emotion)
}

async function primeAudioOnce() {
  try {
    await audioStore.primeContext()
  } catch {
    pageError.value = '音频环境初始化失败，首次触摸时将重试。'
  }
}

onMounted(() => {
  window.addEventListener('pointerdown', primeAudioOnce, { once: true })
})

onBeforeUnmount(() => {
  clearTimeout(pressTimer)
  window.removeEventListener('pointerdown', primeAudioOnce)
})
</script>

<template>
  <section class="generate section-grid">
    <article class="generate-grid">
      <div class="left section-grid">
        <article class="jade-card panel" v-if="jade">
          <h3>{{ jade.dynasty }}代 · {{ jade.name }}</h3>
          <p class="text-muted">{{ jade.description }}</p>
          <p class="status-pill">当前情绪：{{ emotionLabelMap[currentEmotion] || currentEmotion }}</p>

          <div class="actions-row">
            <button type="button" class="jade-button primary" :disabled="apiStore.imageLoading" @click="generateJade">
              {{ apiStore.imageLoading ? '生成中...' : '生成专属玉' }}
            </button>
            <button type="button" class="jade-button secondary" @click="saveToGallery">保存至展厅</button>
            <button type="button" class="jade-button secondary" @click="replayTouchSound">试听音效</button>
          </div>

          <p v-if="saveNotice" class="success">{{ saveNotice }}</p>
          <p v-if="pageError" class="error-text">{{ pageError }}</p>
          <p v-if="apiStore.lastError" class="error-text">{{ apiStore.lastError }}</p>
        </article>

        <EmotionCapture @emotion-change="handleEmotionChange" />
      </div>

      <div class="right section-grid">
        <article class="jade-card image-panel">
          <h3>生成结果</h3>
          <div
            class="image-box"
            @mousedown="beginPress"
            @mouseup="endPress"
            @mouseleave="endPress"
            @touchstart.prevent="beginPress"
            @touchend="endPress"
            @touchcancel="endPress"
          >
            <img v-if="previewImage" :src="previewImage" alt="专属玉生成图" class="generated-image" />
            <p v-else class="text-muted">点击“生成专属玉”后将在此展示结果。长按图像 800ms 可触发触摸音效。</p>
          </div>
        </article>

        <article class="jade-card panel prompt-panel">
          <h3>动态 Prompt</h3>
          <textarea v-model="promptText" rows="6" readonly></textarea>
        </article>
      </div>
    </article>
  </section>
</template>

<style scoped>
.generate-grid {
  display: grid;
  grid-template-columns: minmax(260px, 1fr) minmax(320px, 1.2fr);
  gap: 0.9rem;
}

.panel {
  padding: 1rem;
  display: grid;
  gap: 0.7rem;
}

.image-panel {
  padding: 1rem;
  display: grid;
  gap: 0.7rem;
}

.image-box {
  min-height: 360px;
  display: grid;
  place-items: center;
  border-radius: var(--radius-md);
  border: 1px dashed rgba(54, 89, 76, 0.36);
  background: rgba(242, 248, 244, 0.72);
  text-align: center;
  padding: 0.8rem;
}

.generated-image {
  width: 100%;
  max-height: 540px;
  object-fit: contain;
  border-radius: var(--radius-md);
}

.prompt-panel textarea {
  width: 100%;
  border: 1px solid rgba(56, 92, 79, 0.22);
  border-radius: var(--radius-md);
  background: rgba(255, 255, 255, 0.86);
  padding: 0.65rem 0.72rem;
  resize: none;
  color: var(--ink-700);
}

.success {
  color: #2c6f57;
}

.error-text {
  color: var(--danger);
}

@media (max-width: 980px) {
  .generate-grid {
    grid-template-columns: 1fr;
  }

  .image-box {
    min-height: 280px;
  }
}
</style>
