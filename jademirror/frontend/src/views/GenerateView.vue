<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import GeneratedJadeViewer from '@/components/GeneratedJadeViewer.vue'
import JadePhoto3DViewer from '@/components/JadePhoto3DViewer.vue'
import { useApiStore } from '@/stores/apiStore'
import { useAssistantStore } from '@/stores/assistantStore'
import { useAudioStore } from '@/stores/audioStore'
import { useUserStore } from '@/stores/userStore'
import { useVoiceStore } from '@/stores/voiceStore'
import { createFallbackJadeDataURL, urlToDataURL } from '@/utils/image'
import { buildImagePrompt, buildMultiViewPrompts } from '@/utils/prompt'

const router = useRouter()
const userStore = useUserStore()
const apiStore = useApiStore()
const audioStore = useAudioStore()
const assistantStore = useAssistantStore()
const voiceStore = useVoiceStore()

const genDraft = ref('')

const jade = computed(() => userStore.matchedJade)

const traitLabels = {
  landscape: '山水',
  color: '色泽',
  symbol: '纹样',
  mood: '气韵',
  texture: '质地',
}

const dynastySuffixes = ['良渚', '红山', '龙山', '仰韶', '河姆渡', '大汶口', '三星堆']

const jadeEraLabel = computed(() => {
  if (!jade.value) return ''
  const d = jade.value.dynasty || ''
  if (dynastySuffixes.includes(d)) return `${d}文化`
  return `${d}代`
})

const jadeIntroduction = computed(() => {
  if (!jade.value) return ''
  const j = jade.value
  const parts = []
  if (j.description) parts.push(j.description)
  if (j.traits) {
    const traitParts = []
    for (const [key, val] of Object.entries(j.traits)) {
      const label = traitLabels[key] || key
      traitParts.push(`${label}：${val}`)
    }
    if (traitParts.length) parts.push(traitParts.join('，'))
  }
  return parts.join('。')
})

const promptText = ref(userStore.lastPrompt || '')
const previewImage = ref(userStore.generatedImageDataUrl || '')
const originalImageUrl = ref(userStore.generatedImageOriginalUrl || '')
const modelUrl = ref(userStore.generatedModelUrl || '')
const multiViews = ref(userStore.generatedMultiViews || [])
const pageError = ref('')
const saveNotice = ref('')
const touchPulse = ref(false)
const multiViewLoading = ref(false)
const multiViewProgress = ref('')
/** 仅单张生成图时：true=Three 平面立体预览，false=纯 2D 大图 */
const usePhotoStereo = ref(true)

const viewLabelMap = {
  front: '正面',
  left: '左侧',
  right: '右侧',
  back: '背面',
  top: '俯视',
  left_front: '左前',
  right_front: '右前',
  bottom: '仰视',
}

async function generateJade() {
  if (!jade.value) return

  saveNotice.value = ''
  pageError.value = ''

  const prompt = buildImagePrompt({
    answers: userStore.testAnswers,
    jade: jade.value,
    vector: userStore.userVector,
  })

  promptText.value = prompt

  try {
    const imageUrl = await apiStore.generateImage({ prompt })
    if (!imageUrl) throw new Error('生成接口未返回图片地址。')

    let dataUrl
    try { dataUrl = await urlToDataURL(imageUrl) } catch { dataUrl = imageUrl }

    previewImage.value = dataUrl
    originalImageUrl.value = imageUrl
    modelUrl.value = ''
    multiViews.value = []
    userStore.setGeneratedResult({ imageDataUrl: dataUrl, prompt, modelUrl: '', originalUrl: imageUrl })
    userStore.setMultiViews([])
  } catch (error) {
    pageError.value = error.message || '图像生成失败，已回退到占位图。'
    const fallbackDataUrl = createFallbackJadeDataURL(jade.value.name)
    previewImage.value = fallbackDataUrl
    originalImageUrl.value = ''
    modelUrl.value = ''
    multiViews.value = []
    userStore.setGeneratedResult({ imageDataUrl: fallbackDataUrl, prompt, modelUrl: '', originalUrl: '' })
    userStore.setMultiViews([])
  }
}

async function generateMultiViews() {
  if (!jade.value) return

  pageError.value = ''
  multiViewLoading.value = true
  multiViewProgress.value = '准备多视角生成...'

  const viewPrompts = buildMultiViewPrompts({
    answers: userStore.testAnswers,
    jade: jade.value,
    vector: userStore.userVector,
  })

  const results = []
  const total = viewPrompts.length

  for (let i = 0; i < total; i++) {
    const { key, prompt } = viewPrompts[i]
    multiViewProgress.value = `生成视角 ${i + 1}/${total}（${viewLabelMap[key] || key}）...`

    try {
      const imageUrl = await apiStore.generateImage({ prompt })
      if (imageUrl) {
        let dataUrl
        try { dataUrl = await urlToDataURL(imageUrl) } catch { dataUrl = imageUrl }
        results.push({ key, label: viewLabelMap[key] || key, imageUrl: dataUrl })
      }
    } catch {
      results.push({ key, label: viewLabelMap[key] || key, imageUrl: '' })
    }
  }

  const validResults = results.filter((r) => r.imageUrl)
  if (validResults.length === 0) {
    pageError.value = '多视角生成全部失败，请重试。'
    multiViewLoading.value = false
    multiViewProgress.value = ''
    return
  }

  if (validResults.length > 0 && previewImage.value) {
    validResults.unshift({ key: 'front', label: '正面', imageUrl: previewImage.value })
  }

  multiViews.value = validResults
  modelUrl.value = ''
  userStore.setMultiViews(validResults)
  userStore.setGeneratedModelUrl('')

  multiViewLoading.value = false
  multiViewProgress.value = `已完成 ${validResults.length} 个视角`
  window.setTimeout(() => { multiViewProgress.value = '' }, 3000)
}

async function generate3DModel() {
  if (!previewImage.value) {
    pageError.value = '请先生成专属玉图像。'
    return
  }
  pageError.value = ''
  try {
    const payload = {}
    if (originalImageUrl.value) {
      payload.imageUrl = originalImageUrl.value
    } else {
      payload.imageBase64 = previewImage.value
    }
    const resultUrl = await apiStore.generate3DModel(payload)
    if (!resultUrl) throw new Error('3D生成接口未返回模型地址。')
    modelUrl.value = resultUrl
    multiViews.value = []
    userStore.setGeneratedModelUrl(resultUrl)
    userStore.setMultiViews([])
  } catch (error) {
    pageError.value = error.message || '3D模型生成失败。'
  }
}

function switchToTextureView() {
  modelUrl.value = ''
  multiViews.value = []
  multiViewLoading.value = false
  multiViewProgress.value = ''
  pageError.value = ''
  userStore.setGeneratedModelUrl('')
  userStore.setMultiViews([])
}

async function replayTouchSound() {
  if (!jade.value) return
  try {
    await audioStore.playJadeMelody({ jade: jade.value, mode: 'touch' })
    touchPulse.value = true
    window.setTimeout(() => { touchPulse.value = false }, 280)
  } catch (error) {
    pageError.value = error.message || '当前浏览器无法播放音效。'
  }
}

async function replayLongPressSound() {
  if (!jade.value) return
  try {
    await audioStore.playJadeMelody({ jade: jade.value, mode: 'hold' })
    touchPulse.value = true
    window.setTimeout(() => { touchPulse.value = false }, 420)
  } catch (error) {
    pageError.value = error.message || '当前浏览器无法播放音效。'
  }
}

function handleViewerSoundTrigger(mode) {
  if (mode === 'hold') { replayLongPressSound(); return }
  replayTouchSound()
}

function saveToGallery() {
  const work = userStore.saveCurrentWork()
  saveNotice.value = work ? '已保存到个人藏室。' : '请先生成专属玉图像。'
}

async function primeAudioOnce() {
  try { await audioStore.primeContext() } catch { pageError.value = '音频环境初始化失败。' }
}

async function sendGenDraft() {
  const text = genDraft.value.trim()
  if (!text || assistantStore.busy) return
  genDraft.value = ''
  await assistantStore.handleUserText(text, router)
}

async function genVoiceInputOnce() {
  if (assistantStore.busy) return
  voiceStore.stopSpeaking()
  assistantStore.lastError = ''
  voiceStore.lastError = ''
  await assistantStore.listenAndHandle(router)
}

function genBeginHold() {
  if (assistantStore.busy || voiceStore.holdListening || !voiceStore.recognitionSupported) return
  voiceStore.startHoldListening()
}

async function genEndHold() {
  if (!voiceStore.holdListening) return
  const transcript = await voiceStore.stopHoldListening()
  const text = String(transcript || '').trim()
  if (text) {
    await assistantStore.handleUserText(text, router)
  }
}

function genStopListening() {
  voiceStore.stopListening()
}

function genReplayAssistant() {
  const latest = assistantStore.latestReply
  const text = String(latest?.content || '').trim()
  if (!text) {
    assistantStore.lastError = '暂无可重播的玉灵回复。'
    return
  }
  voiceStore.init()
  voiceStore.setPersona(assistantStore.voicePersona)
  voiceStore.speakWithMood(text, assistantStore.emotionalTone)
}

function toggleGenAutoSpeak() {
  assistantStore.autoSpeak = !assistantStore.autoSpeak
}

onMounted(() => {
  window.addEventListener('pointerdown', primeAudioOnce, { once: true })
  voiceStore.init()
  assistantStore.setCompanionMicSuppressed(true)
})
onBeforeUnmount(() => {
  window.removeEventListener('pointerdown', primeAudioOnce)
  assistantStore.setCompanionMicSuppressed(false)
})
</script>

<template>
  <section class="generate section-grid">
    <article v-if="jade" class="info-card jade-card">
      <div class="info-row">
        <div class="info-text">
          <h3>{{ jadeEraLabel }} · {{ jade.name }}</h3>
          <p class="text-muted">{{ jade.description }}</p>
        </div>
        <div class="actions-row">
          <button type="button" class="jade-button primary" :disabled="apiStore.imageLoading" @click="generateJade">
            {{ apiStore.imageLoading ? '生成中...' : '生成专属玉' }}
          </button>
          <button
            type="button"
            class="jade-button accent"
            :disabled="multiViewLoading || !previewImage"
            @click="generateMultiViews"
          >
            {{ multiViewLoading ? multiViewProgress : '生成多视角3D' }}
          </button>
          <button
            type="button"
            class="jade-button secondary"
            :disabled="apiStore.model3DLoading || !previewImage"
            @click="generate3DModel"
          >
            {{ apiStore.model3DLoading ? '3D生成中...' : '生成3D模型' }}
          </button>
          <button type="button" class="jade-button secondary" @click="saveToGallery">保存至藏室</button>
          <button type="button" class="jade-button secondary" @click="replayTouchSound">试听音效</button>
        </div>
      </div>
      <p v-if="multiViewProgress && !multiViewLoading" class="success">{{ multiViewProgress }}</p>
      <p v-if="saveNotice" class="success">{{ saveNotice }}</p>
      <p v-if="pageError" class="error-text">{{ pageError }}</p>
      <p v-if="apiStore.lastError" class="error-text">{{ apiStore.lastError }}</p>
    </article>

    <article class="viewer-card jade-card">
      <div class="image-box" :class="{ active: touchPulse }">
        <JadePhoto3DViewer
          v-if="!modelUrl && multiViews.length === 0 && previewImage && usePhotoStereo"
          :image-src="previewImage"
          @trigger-sound="handleViewerSoundTrigger"
        />
        <img
          v-else-if="!modelUrl && multiViews.length === 0 && previewImage && !usePhotoStereo"
          :src="previewImage"
          alt="生成的专属玉图像"
          class="preview-image"
          @click="replayTouchSound"
        />
        <GeneratedJadeViewer
          v-else-if="modelUrl || multiViews.length > 0"
          :jade="jade"
          :image-src="previewImage"
          :model-url="modelUrl"
          :multi-views="multiViews"
          @trigger-sound="handleViewerSoundTrigger"
        />
        <p v-else class="text-muted placeholder-text">点击上方"生成专属玉"开始创作</p>
      </div>
      <div class="viewer-controls">
        <p class="text-muted viewer-tip">
          <template v-if="multiViews.length > 0">拖拽旋转查看3D立体效果，松手后惯性滑动，点击触发音效</template>
          <template v-else-if="modelUrl">拖拽旋转3D模型，点击触发音效</template>
          <template v-else-if="previewImage && usePhotoStereo">立体预览贴图与千问生成图一致，拖拽旋转、松手惯性滑动，点击触发音效</template>
          <template v-else-if="previewImage && !usePhotoStereo">平面大图与生成图一致，点击图像可试听短音效</template>
          <template v-else>点击"生成专属玉"开始创作</template>
        </p>
        <div class="viewer-actions">
          <button
            v-if="!modelUrl && multiViews.length === 0 && previewImage"
            type="button"
            class="jade-button secondary small"
            @click="usePhotoStereo = !usePhotoStereo"
          >
            {{ usePhotoStereo ? '2D 平面图' : '立体预览' }}
          </button>
          <button
            v-if="modelUrl || multiViews.length > 0"
            type="button"
            class="jade-button secondary small"
            @click="switchToTextureView"
          >
            切换2D视图
          </button>
        </div>
      </div>
    </article>

    <article v-if="jade" class="voice-card jade-card">
      <p class="voice-card-title">与玉灵对话（本页优先使用麦克风）</p>
      <div class="voice-toolbar">
        <button
          type="button"
          class="jade-button secondary small"
          :disabled="assistantStore.busy || !voiceStore.recognitionSupported"
          @click="genVoiceInputOnce"
        >
          语音输入
        </button>
        <button
          type="button"
          class="jade-button secondary small"
          :class="{ hold: voiceStore.holdListening }"
          :disabled="assistantStore.busy || !voiceStore.recognitionSupported"
          @pointerdown.prevent="genBeginHold"
          @pointerup.prevent="genEndHold"
          @pointerleave.prevent="genEndHold"
          @pointercancel.prevent="genEndHold"
        >
          {{ voiceStore.holdListening ? '松开结束' : '按住说话' }}
        </button>
        <button type="button" class="jade-button secondary small" :disabled="!voiceStore.listening" @click="genStopListening">
          停止聆听
        </button>
        <button type="button" class="jade-button secondary small" :disabled="!assistantStore.latestReply" @click="genReplayAssistant">
          重播玉音
        </button>
        <button type="button" class="jade-button secondary small" :disabled="!voiceStore.speaking" @click="voiceStore.stopSpeaking()">
          停止播报
        </button>
        <button
          type="button"
          class="jade-button secondary small"
          :class="{ 'auto-speak-on': assistantStore.autoSpeak }"
          @click="toggleGenAutoSpeak"
        >
          自动播报回复
        </button>
      </div>
      <div class="gen-composer">
        <textarea
          v-model="genDraft"
          rows="2"
          placeholder="也可以说：保存到藏室 / 生成多视角 / 带我回首页..."
          @keydown.enter.exact.prevent="sendGenDraft"
        ></textarea>
        <button type="button" class="jade-button primary small" :disabled="assistantStore.busy" @click="sendGenDraft">发送</button>
      </div>
      <p v-if="assistantStore.lastError" class="error-text">{{ assistantStore.lastError }}</p>
      <p v-if="voiceStore.lastError" class="error-text">{{ voiceStore.lastError }}</p>
    </article>

    <article v-if="jade" class="prompt-card jade-card">
      <h4>{{ jadeEraLabel }} · {{ jade.name }}</h4>
      <p class="jade-intro">{{ jadeIntroduction }}</p>
      <p v-if="jade.personality" class="jade-personality">{{ jade.personality }}</p>
    </article>
  </section>
</template>

<style scoped>
.info-card {
  padding: 1rem;
}

.info-row {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 1rem;
  flex-wrap: wrap;
}

.info-text h3 {
  margin: 0 0 0.3rem;
}

.info-text p {
  margin: 0;
}

.actions-row {
  flex-shrink: 0;
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.viewer-card {
  padding: 1rem;
  display: grid;
  gap: 0.5rem;
}

.image-box {
  min-height: 400px;
  display: grid;
  place-items: center;
  border-radius: var(--radius-md);
  border: 1px dashed rgba(54, 89, 76, 0.36);
  background: rgba(242, 248, 244, 0.72);
  text-align: center;
  padding: 0.8rem;
  transition: transform 0.24s ease, box-shadow 0.24s ease, border-color 0.24s ease;
}

.image-box.active {
  transform: scale(1.01);
  border-color: rgba(46, 97, 79, 0.52);
  box-shadow: 0 14px 34px rgba(63, 112, 93, 0.2);
}

.placeholder-text {
  font-size: 0.9rem;
  opacity: 0.6;
}

.preview-image {
  max-width: 100%;
  max-height: 460px;
  border-radius: var(--radius-md);
  object-fit: contain;
  cursor: pointer;
}

.viewer-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  justify-content: flex-end;
}

.viewer-controls {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.viewer-tip {
  text-align: center;
  font-size: 0.84rem;
  flex: 1;
}

.prompt-card {
  padding: 0.8rem 1rem;
  display: grid;
  gap: 0.4rem;
}

.prompt-card h4 {
  margin: 0;
  font-size: 0.95rem;
}

.jade-intro {
  margin: 0.4rem 0 0;
  font-size: 0.88rem;
  line-height: 1.7;
  color: var(--ink-700);
}

.jade-personality {
  margin: 0.5rem 0 0;
  font-size: 0.84rem;
  line-height: 1.7;
  color: var(--ink-600);
  font-style: italic;
}

.success {
  color: #2c6f57;
  margin: 0.3rem 0 0;
}

.error-text {
  color: var(--danger);
  margin: 0.3rem 0 0;
}

.jade-button.accent {
  background: linear-gradient(135deg, #3a7d68, #2d6b56);
  color: #f0f8f4;
  border-color: #3a7d68;
}

.jade-button.accent:hover:not(:disabled) {
  background: linear-gradient(135deg, #4a8d78, #3d7b66);
}

.jade-button.small {
  font-size: 0.78rem;
  padding: 0.3rem 0.7rem;
}

.voice-card {
  padding: 0.85rem 1rem;
  display: grid;
  gap: 0.55rem;
}

.voice-card-title {
  margin: 0;
  font-size: 0.88rem;
  font-weight: 600;
  color: var(--ink-700);
}

.voice-toolbar {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.voice-toolbar .hold {
  background: rgba(45, 89, 75, 0.9);
  color: #eef6f2;
  border-color: transparent;
}

.voice-toolbar .auto-speak-on {
  background: rgba(45, 89, 75, 0.88);
  color: #eef6f2;
  border-color: transparent;
}

.gen-composer {
  display: grid;
  gap: 0.45rem;
}

.gen-composer textarea {
  width: 100%;
  resize: vertical;
  border: 1px solid rgba(56, 92, 79, 0.22);
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.93);
  padding: 0.5rem 0.65rem;
  font-size: 0.86rem;
}

@media (max-width: 780px) {
  .info-row {
    flex-direction: column;
  }

  .actions-row {
    width: 100%;
  }

  .image-box {
    min-height: 300px;
  }
}
</style>
