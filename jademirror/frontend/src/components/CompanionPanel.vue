<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
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

async function voiceInputOnce() {
  if (assistantStore.busy || assistantStore.companionMicSuppressed) return
  voiceStore.stopSpeaking()
  if (voiceStore.autoListening) {
    voiceStore.stopAutoListen()
    stopVADPoll()
  }
  await assistantStore.listenAndHandle(router)
  resumeAutoListenIfNeeded()
}

function beginHoldToTalk() {
  if (assistantStore.busy || assistantStore.companionMicSuppressed || voiceStore.holdListening || !voiceStore.recognitionSupported) {
    return
  }
  if (voiceStore.autoListening) {
    voiceStore.stopAutoListen()
    stopVADPoll()
  }
  voiceStore.startHoldListening()
}

async function endHoldToTalk() {
  if (!voiceStore.holdListening) {
    return
  }
  const transcript = await voiceStore.stopHoldListening()
  const text = String(transcript || '').trim()
  if (!text) {
    resumeAutoListenIfNeeded()
    return
  }
  await assistantStore.handleUserText(text, router)
  resumeAutoListenIfNeeded()
}

function stopAllListening() {
  voiceStore.stopAutoListen()
  stopVADPoll()
  voiceStore.stopListening()
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
})
</script>

<template>
  <aside class="companion">
    <Transition name="toast-fade">
      <div v-if="assistantStore.companionToast" class="companion-toast">
        {{ assistantStore.companionToast }}
      </div>
    </Transition>

    <div class="pet-dock">
      <div class="pet-dock-main" @click="openSettings">
        <SpiritPet :state="petState" :size="52" />
        <span class="pet-status">{{ statusText }}</span>
      </div>
      <button type="button" class="settings-btn" @click.stop="openSettings">设置</button>
    </div>

    <div class="voice-toolbar">
      <button
        type="button"
        class="tool-btn"
        :disabled="assistantStore.busy || !voiceStore.recognitionSupported || assistantStore.companionMicSuppressed"
        @click="voiceInputOnce"
      >
        语音输入
      </button>
      <button
        type="button"
        class="tool-btn"
        :class="{ active: voiceStore.holdListening }"
        :disabled="assistantStore.busy || !voiceStore.recognitionSupported || voiceStore.autoListening || assistantStore.companionMicSuppressed"
        @pointerdown.prevent="beginHoldToTalk"
        @pointerup.prevent="endHoldToTalk"
        @pointerleave.prevent="endHoldToTalk"
        @pointercancel.prevent="endHoldToTalk"
      >
        {{ voiceStore.holdListening ? '松开结束' : '按住说话' }}
      </button>
      <button type="button" class="tool-btn" :disabled="!voiceStore.listening && !voiceStore.autoListening" @click="stopAllListening">
        停止聆听
      </button>
      <button type="button" class="tool-btn" :disabled="!assistantStore.latestReply" @click="replayAssistantVoice">重播玉音</button>
      <button type="button" class="tool-btn" :disabled="!voiceStore.speaking" @click="voiceStore.stopSpeaking()">停止播报</button>
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

    <CompanionSettings v-if="showSettings" @close="closeSettings" />
  </aside>
</template>

<style scoped>
.companion {
  position: fixed;
  right: 1rem;
  bottom: 1rem;
  z-index: 40;
  width: min(440px, calc(100vw - 1.5rem));
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: 0.45rem;
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
}

.pet-dock-main {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  cursor: pointer;
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
}

.send-btn {
  justify-self: start;
}

.error-text {
  margin: 0;
  color: var(--danger);
  font-size: 0.8rem;
}

@media (max-width: 720px) {
  .companion {
    right: 0.6rem;
    bottom: 0.6rem;
  }
}
</style>
