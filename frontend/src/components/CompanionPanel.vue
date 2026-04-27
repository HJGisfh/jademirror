<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAssistantStore } from '@/stores/assistantStore'
import { useVoiceStore } from '@/stores/voiceStore'

const route = useRoute()
const router = useRouter()
const assistantStore = useAssistantStore()
const voiceStore = useVoiceStore()
const draft = ref('')
const holdTalking = ref(false)

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
const toneLabel = computed(() => {
  const map = {
    calm: '平和',
    comforting: '安抚',
    cheerful: '轻快',
    energetic: '振奋',
    contemplative: '沉静',
  }
  return map[assistantStore.emotionalTone] || '平和'
})
const personaOptions = [
  { value: 'default', label: '默认声线' },
  { value: 'warm', label: '温润声线' },
  { value: 'bright', label: '清亮声线' },
  { value: 'deep', label: '低沉声线' },
]
const listeningLabel = computed(() => {
  if (assistantStore.busy) {
    return '思考中...'
  }
  if (holdTalking.value || voiceStore.holdListening || voiceStore.listening) {
    return '松开结束'
  }
  return '按住说话'
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
  if (assistantStore.busy || holdTalking.value || !voiceStore.recognitionSupported) {
    return
  }
  const started = voiceStore.startHoldListening()
  if (!started) {
    return
  }
  holdTalking.value = true
}

async function endHoldToTalk() {
  if (!holdTalking.value) {
    return
  }
  holdTalking.value = false
  const transcript = await voiceStore.stopHoldListening()
  const text = String(transcript || '').trim()
  if (!text) {
    return
  }
  await assistantStore.handleUserText(text, router)
}

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

onMounted(() => {
  window.addEventListener('pointerdown', handleGlobalActivity, true)
  window.addEventListener('keydown', handleGlobalActivity, true)
})

onBeforeUnmount(() => {
  window.removeEventListener('pointerdown', handleGlobalActivity, true)
  window.removeEventListener('keydown', handleGlobalActivity, true)
  holdTalking.value = false
  voiceStore.stopListening()
  assistantStore.teardown()
})
</script>

<template>
  <aside class="companion" :class="{ folded: !assistantStore.open }">
    <button type="button" class="fold-btn" @click="assistantStore.open = !assistantStore.open">
      {{ assistantStore.open ? '收起玉灵童子' : '展开玉灵童子' }}
    </button>

    <div v-if="assistantStore.open" class="panel">
      <header class="head">
        <p class="title">玉灵童子</p>
        <span class="stage">阶段：{{ assistantStore.stage }} · 语气：{{ toneLabel }}</span>
      </header>

      <div class="messages">
        <p v-for="item in latestMessages" :key="item.id" :class="['line', item.role]">
          {{ item.role === 'assistant' ? '童子：' : '你：' }}{{ item.content }}
        </p>
      </div>

      <div class="actions">
        <button
          type="button"
          class="jade-button secondary"
          :class="{ hold: holdTalking || voiceStore.holdListening }"
          :disabled="assistantStore.busy || !voiceStore.recognitionSupported"
          @pointerdown.prevent="beginHoldToTalk"
          @pointerup.prevent="endHoldToTalk"
          @pointerleave.prevent="endHoldToTalk"
          @pointercancel.prevent="endHoldToTalk"
        >
          {{ listeningLabel }}
        </button>
        <button type="button" class="jade-button secondary" :disabled="assistantStore.busy" @click="nudgeNow">
          主动关怀一下
        </button>
      </div>

      <div class="composer">
        <textarea
          v-model="draft"
          rows="2"
          placeholder="直接说：带我开始测试 / 去展厅 / 继续聊天..."
          @keydown.enter.exact.prevent="sendDraft"
        ></textarea>
        <button type="button" class="jade-button primary" :disabled="assistantStore.busy" @click="sendDraft">
          发送
        </button>
      </div>

      <label class="switch">
        <input v-model="assistantStore.autoGuide" type="checkbox" />
        自动跳转到下一步
      </label>
      <label class="switch">
        <input :checked="assistantStore.privacyMode" type="checkbox" @change="assistantStore.setPrivacyMode($event.target.checked)" />
        隐私模式（不保存记忆）
      </label>
      <label class="switch">
        <input v-model="assistantStore.autoSpeak" type="checkbox" />
        自动语音播报
      </label>
      <label class="switch">
        <input v-model="assistantStore.idleEnabled" type="checkbox" @change="assistantStore.touchActivity(router)" />
        空闲时主动闲聊
      </label>
      <div class="persona-row">
        <span class="persona-label">声线角色</span>
        <select class="persona-select" :value="assistantStore.voicePersona" @change="assistantStore.setVoicePersona($event.target.value)">
          <option v-for="item in personaOptions" :key="item.value" :value="item.value">{{ item.label }}</option>
        </select>
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
  </aside>
</template>

<style scoped>
.companion {
  position: fixed;
  right: 1rem;
  bottom: 1rem;
  z-index: 40;
  width: min(420px, calc(100vw - 1.5rem));
}

.fold-btn {
  width: 100%;
  border: 1px solid rgba(56, 90, 77, 0.25);
  background: rgba(247, 252, 248, 0.95);
  color: var(--ink-700);
  border-radius: 10px;
  padding: 0.55rem 0.8rem;
  cursor: pointer;
}

.panel {
  margin-top: 0.45rem;
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

.stage {
  font-size: 0.76rem;
  color: var(--ink-500);
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

.switch {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.82rem;
  color: var(--ink-600);
}

.switch input {
  accent-color: #2f6757;
}

.persona-row {
  display: flex;
  align-items: center;
  gap: 0.45rem;
}

.persona-label {
  font-size: 0.82rem;
  color: var(--ink-600);
}

.persona-select {
  border: 1px solid rgba(56, 90, 77, 0.24);
  border-radius: 8px;
  padding: 0.22rem 0.42rem;
  background: rgba(255, 255, 255, 0.94);
  color: var(--ink-700);
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
