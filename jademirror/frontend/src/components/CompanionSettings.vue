<script setup>
import { computed, onMounted } from 'vue'
import { useAssistantStore } from '@/stores/assistantStore'

const assistantStore = useAssistantStore()

const memoryPreview = computed(() => assistantStore.filteredMemories.slice(0, 12))
const memoryCounts = computed(() => assistantStore.memoryTypeCounts)

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

onMounted(() => {
  assistantStore.loadMemories()
})

const personaOptions = [
  { value: 'default', label: '默认声线' },
  { value: 'warm', label: '温润声线' },
  { value: 'bright', label: '清亮声线' },
  { value: 'deep', label: '低沉声线' },
]

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

const emit = defineEmits(['close'])

function close() {
  emit('close')
}
</script>

<template>
  <div class="settings-overlay" @click.self="close">
    <article class="settings-card jade-card">
      <header class="settings-head">
        <h3>玉灵童子设置</h3>
        <button type="button" class="close-btn" @click="close">✕</button>
      </header>

      <div class="settings-body">
        <section class="setting-group">
          <h4>语音交互</h4>
          <label class="switch">
            <input v-model="assistantStore.autoListen" type="checkbox" />
            自动监听模式
          </label>
          <p class="hint">开启后，玉灵童子会自动监听你说话，检测到沉默后自动识别为说完。</p>
          <label class="switch">
            <input v-model="assistantStore.autoSpeak" type="checkbox" />
            自动语音播报
          </label>
          <label class="switch">
            <input v-model="assistantStore.autoGuide" type="checkbox" />
            自动跳转到下一步
          </label>
        </section>

        <section class="setting-group">
          <h4>声线角色</h4>
          <div class="persona-grid">
            <button
              v-for="item in personaOptions"
              :key="item.value"
              type="button"
              class="persona-chip"
              :class="{ active: assistantStore.voicePersona === item.value }"
              @click="assistantStore.setVoicePersona(item.value)"
            >
              {{ item.label }}
            </button>
          </div>
        </section>

        <section class="setting-group">
          <h4>当前状态</h4>
          <div class="status-row">
            <span class="status-label">情绪基调</span>
            <span class="status-value">{{ toneLabel }}</span>
          </div>
          <div class="status-row">
            <span class="status-label">当前阶段</span>
            <span class="status-value">{{ assistantStore.stage }}</span>
          </div>
        </section>

        <section class="setting-group">
          <h4>隐私与记忆</h4>
          <label class="switch">
            <input :checked="assistantStore.privacyMode" type="checkbox" @change="assistantStore.setPrivacyMode($event.target.checked)" />
            隐私模式（不保存记忆）
          </label>
          <label class="switch">
            <input v-model="assistantStore.idleEnabled" type="checkbox" />
            空闲时主动闲聊
          </label>
        </section>

        <section class="setting-group">
          <h4>监听参数</h4>
          <label class="range-row">
            <span class="range-label">静音判定时长</span>
            <input
              type="range"
              min="800"
              max="3000"
              step="100"
              :value="assistantStore.silenceThreshold"
              @input="assistantStore.silenceThreshold = Number($event.target.value)"
            />
            <span class="range-val">{{ (assistantStore.silenceThreshold / 1000).toFixed(1) }}s</span>
          </label>
          <p class="hint">超过此时长没有声音，即判定用户说完了。建议 1.2 ~ 2.0 秒。</p>
        </section>

        <section class="setting-group memory-section">
          <h4>长期记忆</h4>
          <div class="memory-head-actions">
            <button type="button" class="tiny-btn" :disabled="assistantStore.memoryLoading" @click="refreshMemories">刷新</button>
            <button type="button" class="tiny-btn" :disabled="assistantStore.memoryLoading" @click="exportAll">导出</button>
            <button type="button" class="tiny-btn warn" :disabled="assistantStore.memoryLoading" @click="clearAll">清空</button>
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
            rows="4"
            :value="assistantStore.memoryExportText"
          ></textarea>
          <p v-if="assistantStore.lastMemoryDigest" class="digest">记忆摘要：{{ assistantStore.lastMemoryDigest }}</p>
        </section>
      </div>
    </article>
  </div>
</template>

<style scoped>
.settings-overlay {
  position: fixed;
  inset: 0;
  background: rgba(16, 33, 30, 0.36);
  display: grid;
  place-items: center;
  padding: 1rem;
  z-index: 50;
}

.settings-card {
  width: min(420px, 100%);
  max-height: 85vh;
  overflow-y: auto;
  padding: 1rem;
  display: grid;
  gap: 0.8rem;
}

.settings-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.settings-head h3 {
  margin: 0;
  font-size: 1.1rem;
}

.close-btn {
  width: 2rem;
  height: 2rem;
  border-radius: 999px;
  border: 1px solid rgba(56, 90, 77, 0.2);
  background: rgba(248, 252, 249, 0.9);
  color: var(--ink-600);
  cursor: pointer;
  display: grid;
  place-items: center;
  font-size: 0.9rem;
  transition: background 0.2s ease;
}

.close-btn:hover {
  background: rgba(220, 234, 225, 0.9);
}

.settings-body {
  display: grid;
  gap: 0.8rem;
}

.setting-group {
  padding: 0.6rem;
  border-radius: var(--radius-md);
  border: 1px solid rgba(58, 91, 79, 0.12);
  background: rgba(242, 248, 244, 0.5);
  display: grid;
  gap: 0.45rem;
}

.setting-group h4 {
  margin: 0;
  font-size: 0.9rem;
  color: var(--ink-700);
  padding-bottom: 0.3rem;
  border-bottom: 1px solid rgba(58, 91, 79, 0.1);
}

.switch {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.84rem;
  color: var(--ink-600);
  cursor: pointer;
}

.switch input {
  accent-color: #2f6757;
}

.hint {
  margin: 0;
  font-size: 0.76rem;
  color: var(--ink-400);
  line-height: 1.4;
}

.persona-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
}

.persona-chip {
  border: 1px solid rgba(56, 90, 77, 0.22);
  background: rgba(248, 252, 249, 0.85);
  color: var(--ink-600);
  padding: 0.3rem 0.7rem;
  border-radius: 999px;
  font-size: 0.82rem;
  cursor: pointer;
  transition: all 0.2s ease;
}

.persona-chip:hover {
  background: rgba(220, 234, 225, 0.9);
}

.persona-chip.active {
  background: rgba(45, 89, 75, 0.88);
  color: #eff6f3;
  border-color: transparent;
}

.status-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.84rem;
}

.status-label {
  color: var(--ink-500);
}

.status-value {
  color: var(--ink-700);
  font-weight: 500;
}

.range-row {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 0.5rem;
  align-items: center;
  font-size: 0.84rem;
  color: var(--ink-600);
  cursor: pointer;
}

.range-label {
  white-space: nowrap;
}

.range-row input[type="range"] {
  width: 100%;
  accent-color: #2f6757;
}

.range-val {
  font-size: 0.8rem;
  color: var(--ink-500);
  min-width: 2.5rem;
  text-align: right;
}

.memory-section .memory-head-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
}

.memory-filters {
  display: flex;
  flex-wrap: wrap;
  gap: 0.3rem;
}

.memory-list {
  max-height: 200px;
  overflow: auto;
  display: grid;
  gap: 0.4rem;
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

.digest {
  margin: 0;
  font-size: 0.76rem;
  color: var(--ink-500);
  line-height: 1.45;
}
</style>
