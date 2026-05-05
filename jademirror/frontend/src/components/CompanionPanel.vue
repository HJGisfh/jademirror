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

const latestMessages = computed(() => assistantStore.messages.slice(-8))
const memoryPreview = computed(() => assistantStore.filteredMemories.slice(0, 6))
const memoryCounts = computed(() => assistantStore.memoryTypeCounts)

const petState = computed(() => {
  if (assistantStore.busy) return 'thinking'
  if (voiceStore.speaking) return 'speaking'
  if (voiceStore.autoListening || voiceStore.holdListening || voiceStore.listening) return 'listening'
  return 'idle'
})

const statusText = computed(() => {
  if (assistantStore.busy) return '思考中...'
  if (voiceStore.speaking) return '播报中...'
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

function beginHoldToTalk() {
  if (assistantStore.busy || voiceStore.holdListening || !voiceStore.recognitionSupported) {
    return
  }
  if (voiceStore.autoListening) {
    voiceStore.stopAutoListen()
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
    return
  }
  await assistantStore.handleUserText(text, router)
}

function toggleAutoListen() {
  if (voiceStore.autoListening) {
    voiceStore.stopAutoListen()
    return
  }
  const started = voiceStore.startAutoListen(assistantStore.silenceThreshold)
  if (started) {
    startVADPoll()
  }
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
      if (assistantStore.autoListen) {
        setTimeout(() => {
          if (assistantStore.autoListen && !assistantStore.busy && !voiceStore.speaking) {
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

watch(() => voiceStore.speaking, (speaking) => {
  if (!speaking && assistantStore.autoListen && !voiceStore.autoListening && !assistantStore.busy) {
    setTimeout(() => {
      if (assistantStore.autoListen && !assistantStore.busy && !voiceStore.speaking) {
        voiceStore.startAutoListen(assistantStore.silenceThreshold)
        startVADPoll()
      }
    }, 600)
  }
})

watch(() => assistantStore.busy, (busy) => {
  if (!busy && assistantStore.autoListen && !voiceStore.autoListening && !voiceStore.speaking) {
    setTimeout(() => {
      if (assistantStore.autoListen && !assistantStore.busy && !voiceStore.speaking) {
        voiceStore.startAutoListen(assistantStore.silenceThreshold)
        startVADPoll()
      }
    }, 400)
  }
})

async function nudgeNow() {
  await assistantStore.triggerIdleNudge(router)
}

async function refreshMemories() {
  await assistantStore.loadMemories()
}

async function togglePin(memory) {
  await assistantStore.setMemoryPinned(memory.id, !memory.pinned)
}

async function removeMemoryItem(memory) {
  await assistantStore.removeMemory(memory.id)
}

async function clearAll() {
  await assistantStore.clearAllMemories()
}

async function exportAll() {
  await assistantStore.exportMemories()
}

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
  <aside class="companion" :class="{ folded: !assistantStore.open }">
    <div class="pet-dock" @click="openSettings">
      <SpiritPet :state="petState" :size="56" />
      <span class="pet-status">{{ statusText }}</span>
    </div>

    <button type="button" class="fold-btn" @click="assistantStore.open = !assistantStore.open">
      {{ assistantStore.open ? '收起' : '展开' }}
    </button>

    <div v-if="assistantStore.open" class="panel">
      <header class="head">
        <p class="title">玉灵童子</p>
        <button type="button" class="settings-btn" @click="openSettings">设置</button>
      </header>

      <div class="pet-bar">
        <SpiritPet :state="petState" :size="40" />
        <span class="pet-bar-status">{{ statusText }}</span>
        <button
          type="button"
          class="jade-button secondary auto-listen-btn"
          :class="{ active: voiceStore.autoListening }"
          :disabled="!voiceStore.recognitionSupported || assistantStore.busy"
          @click="toggleAutoListen"
        >
          {{ voiceStore.autoListening ? '停止监听' : '自动监听' }}
        </button>
      </div>

      <div class="messages">
        <p v-for="item in latestMessages" :key="item.id" :class="['line', item.role]">
          {{ item.role === 'assistant' ? '童子：' : '你：' }}{{ item.content }}
        </p>
      </div>

      <div class="actions">
        <button
          type="button"
          class="jade-button secondary"
          :class="{ hold: voiceStore.holdListening }"
          :disabled="assistantStore.busy || !voiceStore.recognitionSupported || voiceStore.autoListening"
          @pointerdown.prevent="beginHoldToTalk"
          @pointerup.prevent="endHoldToTalk"
          @pointerleave.prevent="endHoldToTalk"
          @pointercancel.prevent="endHoldToTalk"
        >
          {{ voiceStore.holdListening ? '松开结束' : '按住说话' }}
        </button>
        <button type="button" class="jade-button secondary" :disabled="assistantStore.busy" @click="nudgeNow">
          主动关怀
        </button>
      </div>

      <div class="composer">
        <textarea
          v-model="draft"
          rows="2"
          placeholder="直接说：带我开始测试 / 去藏室 / 继续聊天..."
          @keydown.enter.exact.prevent="sendDraft"
        ></textarea>
        <button type="button" class="jade-button primary" :disabled="assistantStore.busy" @click="sendDraft">
          发送
        </button>
      </div>

      <div class="memory-head">
        <p class="memory-title">长期记忆</p>
        <div class="memory-head-actions">
          <button type="button" class="tiny-btn" :disabled="assistantStore.memoryLoading" @click="refreshMemories">刷新</button>
          <button type="button" class="tiny-btn" :disabled="assistantStore.memoryLoading" @click="exportAll">导出</button>
          <button type="button" class="tiny-btn warn" :disabled="assistantStore.memoryLoading" @click="clearAll">清空</button>
        </div>
      </div>
      <div class="memory-filters">
        <button type="button" class="tiny-btn" :class="{ active: assistantStore.memoryFilter === 'all' }" @click="assistantStore.setMemoryFilter('all')">
          全部({{ memoryCounts.all }})
        </button>
        <button type="button" class="tiny-btn" :class="{ active: assistantStore.memoryFilter === 'preference' }" @click="assistantStore.setMemoryFilter('preference')">
          偏好({{ memoryCounts.preference }})
        </button>
        <button type="button" class="tiny-btn" :class="{ active: assistantStore.memoryFilter === 'emotion' }" @click="assistantStore.setMemoryFilter('emotion')">
          情绪({{ memoryCounts.emotion }})
        </button>
      </div>
      <div class="memory-list">
        <p v-if="!memoryPreview.length" class="memory-empty text-muted">暂无记忆片段</p>
        <div v-for="memory in memoryPreview" :key="memory.id" class="memory-row">
          <p class="memory-text">{{ memory.content }}</p>
          <div class="memory-actions">
            <button type="button" class="tiny-btn" @click="togglePin(memory)">
              {{ memory.pinned ? '取消置顶' : '置顶' }}
            </button>
            <button type="button" class="tiny-btn warn" @click="removeMemoryItem(memory)">删除</button>
          </div>
        </div>
      </div>
      <textarea
        v-if="assistantStore.memoryExportText"
        class="export-box"
        readonly
        rows="5"
        :value="assistantStore.memoryExportText"
      ></textarea>
      <p v-if="assistantStore.lastMemoryDigest" class="digest">记忆摘要：{{ assistantStore.lastMemoryDigest }}</p>

      <p v-if="assistantStore.lastError" class="error-text">{{ assistantStore.lastError }}</p>
    </div>

    <CompanionSettings v-if="showSettings" @close="closeSettings" />
  </aside>
</template>

<style scoped>
.companion {
  position: fixed;
  right: 1rem;
  bottom: 1rem;
  z-index: 40;
  width: min(420px, calc(100vw - 1.5rem));
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.4rem;
}

.pet-dock {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 0.8rem;
  border-radius: 999px;
  background: rgba(247, 252, 248, 0.95);
  border: 1px solid rgba(56, 90, 77, 0.2);
  box-shadow: 0 6px 18px rgba(34, 69, 56, 0.12);
  cursor: pointer;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.pet-dock:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 24px rgba(34, 69, 56, 0.18);
}

.pet-status {
  font-size: 0.82rem;
  color: var(--ink-600);
  white-space: nowrap;
}

.fold-btn {
  border: 1px solid rgba(56, 90, 77, 0.2);
  background: rgba(247, 252, 248, 0.9);
  color: var(--ink-600);
  border-radius: 999px;
  padding: 0.3rem 0.7rem;
  font-size: 0.78rem;
  cursor: pointer;
  transition: background 0.2s ease;
}

.fold-btn:hover {
  background: rgba(220, 234, 225, 0.9);
}

.panel {
  width: 100%;
  border-radius: 14px;
  border: 1px solid rgba(57, 96, 82, 0.24);
  background: rgba(252, 254, 253, 0.97);
  box-shadow: 0 14px 30px rgba(34, 69, 56, 0.16);
  padding: 0.75rem;
  display: grid;
  gap: 0.55rem;
}

.head {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.title {
  margin: 0;
  font-weight: 700;
}

.settings-btn {
  border: 1px solid rgba(56, 90, 77, 0.2);
  background: rgba(248, 252, 249, 0.9);
  color: var(--ink-600);
  border-radius: 999px;
  padding: 0.2rem 0.6rem;
  font-size: 0.78rem;
  cursor: pointer;
  transition: background 0.2s ease;
}

.settings-btn:hover {
  background: rgba(220, 234, 225, 0.9);
}

.pet-bar {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 0.6rem;
  border-radius: var(--radius-md);
  background: rgba(239, 247, 242, 0.5);
  border: 1px solid rgba(58, 91, 79, 0.1);
}

.pet-bar-status {
  flex: 1;
  font-size: 0.82rem;
  color: var(--ink-600);
}

.auto-listen-btn {
  font-size: 0.78rem;
  padding: 0.25rem 0.6rem;
}

.auto-listen-btn.active {
  background: rgba(45, 89, 75, 0.9);
  color: #eef6f2;
  border-color: transparent;
}

.messages {
  max-height: 180px;
  overflow: auto;
  border-radius: 10px;
  border: 1px solid rgba(58, 91, 79, 0.16);
  background: rgba(239, 247, 242, 0.65);
  padding: 0.5rem;
  display: grid;
  gap: 0.4rem;
}

.line {
  margin: 0;
  font-size: 0.86rem;
  line-height: 1.5;
}

.line.user {
  color: var(--ink-700);
}

.line.assistant {
  color: #285946;
}

.actions {
  display: flex;
  gap: 0.45rem;
}

.actions .hold {
  background: rgba(45, 89, 75, 0.9);
  color: #eef6f2;
  border-color: transparent;
}

.composer {
  display: grid;
  gap: 0.45rem;
}

.composer textarea {
  width: 100%;
  resize: vertical;
  border: 1px solid rgba(56, 92, 79, 0.22);
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.93);
  padding: 0.55rem 0.65rem;
}

.error-text {
  margin: 0;
  color: var(--danger);
  font-size: 0.82rem;
}

.digest {
  margin: 0;
  font-size: 0.78rem;
  color: var(--ink-500);
  line-height: 1.45;
}

.memory-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.memory-head-actions {
  display: flex;
  gap: 0.3rem;
}

.memory-title {
  margin: 0;
  font-size: 0.82rem;
  color: var(--ink-600);
}

.memory-list {
  max-height: 180px;
  overflow: auto;
  display: grid;
  gap: 0.45rem;
}

.memory-filters {
  display: flex;
  gap: 0.3rem;
}

.memory-empty {
  margin: 0;
  font-size: 0.8rem;
}

.memory-row {
  border: 1px solid rgba(58, 91, 79, 0.16);
  border-radius: 9px;
  background: rgba(247, 252, 249, 0.9);
  padding: 0.45rem;
  display: grid;
  gap: 0.35rem;
}

.memory-text {
  margin: 0;
  font-size: 0.8rem;
  line-height: 1.45;
  color: var(--ink-700);
}

.memory-actions {
  display: flex;
  gap: 0.35rem;
}

.tiny-btn {
  border: 1px solid rgba(56, 90, 77, 0.24);
  background: rgba(252, 255, 253, 0.95);
  color: var(--ink-600);
  border-radius: 999px;
  font-size: 0.74rem;
  padding: 0.2rem 0.55rem;
  cursor: pointer;
}

.tiny-btn.warn {
  color: #9f3f3f;
}

.tiny-btn.active {
  background: rgba(45, 89, 75, 0.9);
  color: #eef6f2;
  border-color: transparent;
}

.export-box {
  width: 100%;
  border: 1px solid rgba(56, 92, 79, 0.22);
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.93);
  padding: 0.5rem 0.62rem;
  resize: vertical;
  font-size: 0.75rem;
  color: var(--ink-600);
}

@media (max-width: 720px) {
  .companion {
    right: 0.6rem;
    bottom: 0.6rem;
  }
}
</style>
