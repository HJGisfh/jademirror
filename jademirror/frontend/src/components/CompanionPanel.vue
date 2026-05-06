<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import CompanionSettings from '@/components/CompanionSettings.vue'
import SpiritPet from '@/components/SpiritPet.vue'
import { useAssistantStore } from '@/stores/assistantStore'
import { useVoiceStore } from '@/stores/voiceStore'

const route = useRoute()
const router = useRouter()
const assistantStore = useAssistantStore()
const voiceStore = useVoiceStore()
const draft = ref('')
const showSettings = ref(false)
let vadPollId = 0

// ── expand / collapse ──
const isExpanded = ref(false)

// ── drag ──
const isDragging = ref(false)
const hasDragged = ref(false)
const panelLeft = ref(NaN)
const panelTop = ref(NaN)
const dragStartMouseX = ref(0)
const dragStartMouseY = ref(0)
const dragStartLeft = ref(0)
const dragStartTop = ref(0)
const panelEl = ref(null)

function clampToViewport() {
  if (!panelEl.value) return
  const rect = panelEl.value.getBoundingClientRect()
  if (!isNaN(panelLeft.value)) {
    panelLeft.value = Math.max(0, Math.min(window.innerWidth - rect.width, panelLeft.value))
  }
  if (!isNaN(panelTop.value)) {
    panelTop.value = Math.max(0, Math.min(window.innerHeight - rect.height, panelTop.value))
  }
}

function onDragPointerDown(e) {
  if (e.target.closest('button, textarea, input, a, label')) return
  e.preventDefault()
  isDragging.value = true
  hasDragged.value = false
  dragStartMouseX.value = e.clientX
  dragStartMouseY.value = e.clientY
  if (!panelEl.value) return
  const rect = panelEl.value.getBoundingClientRect()
  if (isNaN(panelLeft.value)) panelLeft.value = rect.left
  if (isNaN(panelTop.value)) panelTop.value = rect.top
  dragStartLeft.value = panelLeft.value
  dragStartTop.value = panelTop.value
  window.addEventListener('pointermove', onDragPointerMove)
  window.addEventListener('pointerup', onDragPointerUp)
}

function onDragPointerMove(e) {
  if (!isDragging.value) return
  const dx = e.clientX - dragStartMouseX.value
  const dy = e.clientY - dragStartMouseY.value
  if (Math.abs(dx) > 3 || Math.abs(dy) > 3) hasDragged.value = true
  if (!panelEl.value) return
  const rect = panelEl.value.getBoundingClientRect()
  panelLeft.value = Math.max(0, Math.min(window.innerWidth - rect.width, dragStartLeft.value + dx))
  panelTop.value = Math.max(0, Math.min(window.innerHeight - rect.height, dragStartTop.value + dy))
}

function onDragPointerUp() {
  isDragging.value = false
  window.removeEventListener('pointermove', onDragPointerMove)
  window.removeEventListener('pointerup', onDragPointerUp)
}

function onPetInteraction() {
  if (hasDragged.value) return
  isExpanded.value = !isExpanded.value
  if (isExpanded.value) {
    nextTick(() => clampToViewport())
  }
}

const positionStyle = computed(() => {
  const style = {}
  if (!isNaN(panelLeft.value)) {
    style.left = panelLeft.value + 'px'
    style.right = 'auto'
  }
  if (!isNaN(panelTop.value)) {
    style.top = panelTop.value + 'px'
    style.bottom = 'auto'
  }
  return style
})

assistantStore.welcomeIfNeeded()
assistantStore.setStage(route.name)
voiceStore.init()
assistantStore.touchActivity(router)

watch(
  () => route.name,
  (name) => {
    assistantStore.setStage(name)
    assistantStore.touchActivity(router)
  },
)

const petState = computed(() => {
  if (assistantStore.busy) return 'thinking'
  if (voiceStore.speaking) return 'speaking'
  if (voiceStore.autoListening || voiceStore.holdListening || voiceStore.listening) return 'listening'
  return 'idle'
})

const statusText = computed(() => {
  if (assistantStore.busy) return '思考中...'
  if (voiceStore.speaking) return '播报中...'
  if (assistantStore.companionMicSuppressed) return '生玉页优先麦克风'
  if (voiceStore.autoListening) {
    return voiceStore.vadSpeechDetected ? '听到你在说话...' : '正在监听...'
  }
  if (voiceStore.holdListening || voiceStore.listening) return '聆听中...'
  return '玉灵童子'
})

async function sendDraft() {
  const text = draft.value.trim()
  if (!text || assistantStore.busy) {
    return
  }
  draft.value = ''
  await assistantStore.handleUserText(text, router)
}

function replayAssistantVoice() {
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

function toggleAutoSpeakReplies() {
  assistantStore.autoSpeak = !assistantStore.autoSpeak
}

function startVADPoll() {
  stopVADPoll()
  vadPollId = window.setInterval(() => {
    if (!voiceStore.autoListening) {
      stopVADPoll()
      return
    }
    if (voiceStore.vadSpeechDetected && !voiceStore.autoListenSilenceTimer) {
      voiceStore.checkAutoListenSilence(assistantStore.silenceThreshold)
    }
    if (voiceStore.isAutoListenSilenceTimedOut()) {
      const text = voiceStore.stopAutoListen()
      if (text) {
        assistantStore.handleUserText(text, router)
      }
      stopVADPoll()
      if (assistantStore.autoListen && !assistantStore.companionMicSuppressed) {
        setTimeout(() => {
          if (assistantStore.autoListen && !assistantStore.busy && !voiceStore.speaking && !assistantStore.companionMicSuppressed) {
            voiceStore.startAutoListen(assistantStore.silenceThreshold)
            startVADPoll()
          }
        }, 500)
      }
    }
  }, 300)
}

function stopVADPoll() {
  if (vadPollId) {
    window.clearInterval(vadPollId)
    vadPollId = 0
  }
}

function tryStartCompanionAutoListen() {
  if (assistantStore.companionMicSuppressed || !assistantStore.autoListen || assistantStore.busy) {
    return
  }
  const started = voiceStore.startAutoListen(assistantStore.silenceThreshold)
  if (started) {
    startVADPoll()
  }
}

function resumeAutoListenIfNeeded() {
  if (!assistantStore.autoListen || assistantStore.companionMicSuppressed || assistantStore.busy) {
    return
  }
  setTimeout(() => {
    tryStartCompanionAutoListen()
  }, 400)
}

watch(
  () => assistantStore.companionMicSuppressed,
  (suppressed) => {
    if (suppressed) {
      voiceStore.stopAutoListen()
      stopVADPoll()
      voiceStore.stopListening()
    } else {
      tryStartCompanionAutoListen()
    }
  },
)

watch(
  () => assistantStore.autoListen,
  (on) => {
    if (!on) {
      voiceStore.stopAutoListen()
      stopVADPoll()
      return
    }
    tryStartCompanionAutoListen()
  },
)

watch(() => voiceStore.speaking, (speaking) => {
  if (!speaking && assistantStore.autoListen && !voiceStore.autoListening && !assistantStore.busy && !assistantStore.companionMicSuppressed) {
    setTimeout(() => {
      tryStartCompanionAutoListen()
    }, 600)
  }
})

watch(() => assistantStore.busy, (busy) => {
  if (!busy && assistantStore.autoListen && !voiceStore.autoListening && !voiceStore.speaking && !assistantStore.companionMicSuppressed) {
    setTimeout(() => {
      tryStartCompanionAutoListen()
    }, 400)
  }
})

function handleGlobalActivity() {
  assistantStore.touchActivity(router)
}

function openSettings() {
  showSettings.value = true
}

function closeSettings() {
  showSettings.value = false
}

function cleanDragListeners() {
  window.removeEventListener('pointermove', onDragPointerMove)
  window.removeEventListener('pointerup', onDragPointerUp)
}

onMounted(() => {
  window.addEventListener('pointerdown', handleGlobalActivity, true)
  window.addEventListener('keydown', handleGlobalActivity, true)
  tryStartCompanionAutoListen()
})

onBeforeUnmount(() => {
  window.removeEventListener('pointerdown', handleGlobalActivity, true)
  window.removeEventListener('keydown', handleGlobalActivity, true)
  voiceStore.stopAutoListen()
  stopVADPoll()
  voiceStore.stopListening()
  assistantStore.teardown()
  cleanDragListeners()
})
</script>

<template>
  <aside
    ref="panelEl"
    class="companion"
    :class="{ collapsed: !isExpanded, dragging: isDragging }"
    :style="positionStyle"
  >
    <Transition name="toast-fade">
      <div v-if="assistantStore.companionToast" class="companion-toast">
        {{ assistantStore.companionToast }}
      </div>
    </Transition>

    <!-- collapsed: floating pet only -->
    <div
      v-if="!isExpanded"
      class="collapsed-pet"
      @pointerdown="onDragPointerDown"
      @click="onPetInteraction"
    >
      <SpiritPet :state="petState" :size="44" />
    </div>

    <!-- expanded: full panel -->
    <template v-if="isExpanded">
      <div class="pet-dock" @pointerdown="onDragPointerDown" @click="onPetInteraction">
        <div class="pet-dock-main">
          <SpiritPet :state="petState" :size="52" />
          <span class="pet-status">{{ statusText }}</span>
        </div>
        <button type="button" class="settings-btn" @click.stop="openSettings">设置</button>
      </div>

      <div class="voice-toolbar">
        <button
          type="button"
          class="tool-btn toggle"
          :class="{ on: assistantStore.autoListen }"
          @click="assistantStore.autoListen = !assistantStore.autoListen"
        >
          {{ assistantStore.autoListen ? '关闭监听' : '开启监听' }}
        </button>
        <button
          type="button"
          class="tool-btn"
          :disabled="!assistantStore.latestReply"
          @click="replayAssistantVoice"
        >
          重播玉音
        </button>
        <button
          type="button"
          class="tool-btn"
          :disabled="!voiceStore.speaking"
          @click="voiceStore.stopSpeaking()"
        >
          停止播报
        </button>
        <button
          type="button"
          class="tool-btn toggle"
          :class="{ on: assistantStore.autoSpeak }"
          @click="toggleAutoSpeakReplies"
        >
          自动播报回复
        </button>
      </div>

      <div class="composer">
        <textarea
          v-model="draft"
          rows="2"
          placeholder="文字输入：带我去测试 / 去藏室 / 继续聊天..."
          @keydown.enter.exact.prevent="sendDraft"
        ></textarea>
        <button type="button" class="jade-button primary send-btn" :disabled="assistantStore.busy" @click="sendDraft">发送</button>
      </div>

      <p v-if="assistantStore.lastError" class="error-text">{{ assistantStore.lastError }}</p>
      <p v-if="voiceStore.lastError" class="error-text">{{ voiceStore.lastError }}</p>
    </template>

    <CompanionSettings v-if="showSettings" @close="closeSettings" />
  </aside>
</template>

<style scoped>
.companion {
  position: fixed;
  right: 1rem;
  bottom: 1rem;
  z-index: 40;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: 0.45rem;
  user-select: none;
}

.companion.collapsed {
  width: auto;
}

.companion:not(.collapsed) {
  width: min(440px, calc(100vw - 1.5rem));
}

.companion.dragging {
  transition: none;
}

.companion-toast {
  max-height: 7.5rem;
  overflow: auto;
  padding: 0.55rem 0.65rem;
  border-radius: 12px;
  border: 1px solid rgba(46, 97, 79, 0.28);
  background: rgba(252, 254, 253, 0.97);
  box-shadow: 0 10px 28px rgba(34, 69, 56, 0.18);
  font-size: 0.84rem;
  line-height: 1.55;
  color: #285946;
  user-select: text;
}

.toast-fade-enter-active,
.toast-fade-leave-active {
  transition: opacity 0.25s ease, transform 0.25s ease;
}
.toast-fade-enter-from,
.toast-fade-leave-to {
  opacity: 0;
  transform: translateY(6px);
}

/* ── collapsed pet ── */
.collapsed-pet {
  cursor: grab;
  display: grid;
  place-items: center;
  width: 56px;
  height: 56px;
  border-radius: 999px;
  background: rgba(247, 252, 248, 0.95);
  border: 1px solid rgba(56, 90, 77, 0.2);
  box-shadow: 0 6px 18px rgba(34, 69, 56, 0.12);
  transition: box-shadow 0.2s ease, transform 0.2s ease;
}

.collapsed-pet:hover {
  box-shadow: 0 8px 24px rgba(34, 69, 56, 0.22);
  transform: scale(1.06);
}

.collapsed-pet:active,
.companion.dragging .collapsed-pet {
  cursor: grabbing;
}

/* ── expanded dock ── */
.pet-dock {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  padding: 0.35rem 0.65rem;
  border-radius: 999px;
  background: rgba(247, 252, 248, 0.95);
  border: 1px solid rgba(56, 90, 77, 0.2);
  box-shadow: 0 6px 18px rgba(34, 69, 56, 0.12);
  cursor: grab;
}

.companion.dragging .pet-dock {
  cursor: grabbing;
}

.pet-dock-main {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  flex: 1;
  min-width: 0;
}

.pet-dock-main:hover .pet-status {
  color: var(--ink-700);
}

.pet-status {
  font-size: 0.8rem;
  color: var(--ink-600);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.settings-btn {
  flex-shrink: 0;
  border: 1px solid rgba(56, 90, 77, 0.22);
  background: rgba(248, 252, 249, 0.95);
  color: var(--ink-600);
  border-radius: 999px;
  padding: 0.28rem 0.65rem;
  font-size: 0.78rem;
  cursor: pointer;
  transition: background 0.2s ease;
}

.settings-btn:hover {
  background: rgba(220, 234, 225, 0.95);
}

/* ── voice toolbar ── */
.voice-toolbar {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
}

.tool-btn {
  border: 1px solid rgba(56, 90, 77, 0.22);
  background: rgba(252, 255, 253, 0.95);
  color: var(--ink-600);
  border-radius: 999px;
  padding: 0.28rem 0.55rem;
  font-size: 0.74rem;
  cursor: pointer;
  transition: background 0.2s ease, border-color 0.2s ease;
}

.tool-btn:hover:not(:disabled) {
  background: rgba(230, 242, 235, 0.95);
}

.tool-btn:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.tool-btn.active {
  background: rgba(45, 89, 75, 0.92);
  color: #eef6f2;
  border-color: transparent;
}

.tool-btn.toggle.on {
  background: rgba(45, 89, 75, 0.88);
  color: #eef6f2;
  border-color: transparent;
}

/* ── composer ── */
.composer {
  display: grid;
  gap: 0.4rem;
}

.composer textarea {
  width: 100%;
  resize: vertical;
  border: 1px solid rgba(56, 92, 79, 0.22);
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.93);
  padding: 0.5rem 0.6rem;
  font-size: 0.84rem;
  user-select: text;
}

.send-btn {
  justify-self: start;
}

.error-text {
  margin: 0;
  color: var(--danger);
  font-size: 0.8rem;
  user-select: text;
}

@media (max-width: 720px) {
  .companion:not(.collapsed) {
    right: 0.6rem;
    bottom: 0.6rem;
  }
}
</style>
