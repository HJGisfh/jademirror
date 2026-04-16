<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import ChatBubble from '@/components/ChatBubble.vue'
import { useApiStore } from '@/stores/apiStore'
import { useUserStore } from '@/stores/userStore'

const userStore = useUserStore()
const apiStore = useApiStore()
const router = useRouter()

const jade = computed(() => userStore.matchedJade)
const messages = ref([])
const draft = ref('')
const listRef = ref(null)

const suggestedQuestions = [
  '你经历过什么？',
  '你如何理解人心？',
  '你对当下有什么看法？',
  '你见过最美的时刻是什么？',
  '如何在浮躁中找到自己？',
]

const chatStorageKey = computed(() => {
  if (!jade.value) {
    return ''
  }
  return `jademirror-chat-${jade.value.id}`
})

const openingIntroPrompt =
  '请先用第一人称做一段简短自我介绍：你是哪一件玉、来自哪个朝代、你的性格与经历，并邀请我继续提问。'

function createAssistantGreeting() {
  if (!jade.value) {
    return '你好，我在这里。'
  }
  return `我是${jade.value.dynasty}代${jade.value.name}。请将你的问题交给我，我会以玉之记忆回应。`
}

function persistMessages() {
  if (!chatStorageKey.value) {
    return
  }
  sessionStorage.setItem(chatStorageKey.value, JSON.stringify(messages.value))
}

function scrollToBottom() {
  nextTick(() => {
    if (listRef.value) {
      listRef.value.scrollTop = listRef.value.scrollHeight
    }
  })
}

async function createOpeningMessage() {
  if (!jade.value) {
    return
  }

  const fallback = createAssistantGreeting()

  try {
    const intro = await apiStore.chatWithJade({
      jade: jade.value,
      matchReason: userStore.matchReason,
      testAnswers: userStore.testAnswers,
      messages: [
        {
          role: 'user',
          content: openingIntroPrompt,
        },
      ],
    })

    messages.value = [
      {
        id: Date.now(),
        role: 'assistant',
        content: intro || fallback,
      },
    ]
  } catch {
    messages.value = [
      {
        id: Date.now(),
        role: 'assistant',
        content: fallback,
      },
    ]
  }

  persistMessages()
  scrollToBottom()
}

async function loadMessages(forceNew = false) {
  if (!chatStorageKey.value) {
    messages.value = []
    return
  }

  if (!forceNew) {
    try {
      const raw = sessionStorage.getItem(chatStorageKey.value)
      if (raw) {
        messages.value = JSON.parse(raw)
        scrollToBottom()
        return
      }
    } catch {
      // Ignore broken session cache and recreate opening message
    }
  }

  await createOpeningMessage()
}

async function restartConversation() {
  if (!chatStorageKey.value) {
    return
  }

  sessionStorage.removeItem(chatStorageKey.value)
  messages.value = []
  await loadMessages(true)
}

async function sendMessage() {
  const text = draft.value.trim()
  if (!text || apiStore.chatLoading || !jade.value) {
    return
  }

  messages.value.push({
    id: Date.now(),
    role: 'user',
    content: text,
  })

  draft.value = ''
  persistMessages()
  scrollToBottom()

  try {
    const content = await apiStore.chatWithJade({
      jade: jade.value,
      matchReason: userStore.matchReason,
      testAnswers: userStore.testAnswers,
      messages: messages.value.map((item) => ({
        role: item.role,
        content: item.content,
      })),
    })

    messages.value.push({
      id: Date.now() + 1,
      role: 'assistant',
      content,
    })
  } catch {
    messages.value.push({
      id: Date.now() + 2,
      role: 'assistant',
      content: '我暂时听不清风声，请稍后再问。',
    })
  }

  persistMessages()
  scrollToBottom()
}

watch(
  () => jade.value?.id,
  () => {
    loadMessages()
  },
)

onMounted(() => {
  if (!jade.value) {
    router.push('/test')
    return
  }
  loadMessages()
})
</script>

<template>
  <section class="chat section-grid">
    <article v-if="jade" class="chat-card jade-card">
      <header class="chat-head">
        <div>
          <h2>{{ jade.name }}</h2>
          <p class="text-muted">{{ jade.dynasty }}代人格对话中</p>
        </div>
        <div class="head-actions">
          <button type="button" class="jade-button secondary" @click="restartConversation">重新开场</button>
          <button type="button" class="jade-button secondary" @click="router.push('/generate')">
            前往生成页
          </button>
        </div>
      </header>

      <div ref="listRef" class="chat-list">
        <ChatBubble
          v-for="message in messages"
          :key="message.id"
          :role="message.role"
          :content="message.content"
        />
      </div>

      <div v-if="messages.length <= 1" class="suggestions">
        <p class="text-muted">建议话题：</p>
        <div class="suggestion-buttons">
          <button
            v-for="(q, idx) in suggestedQuestions"
            :key="idx"
            type="button"
            class="suggestion-btn"
            @click="draft = q"
          >
            {{ q }}
          </button>
        </div>
      </div>

      <footer class="composer">
        <textarea
          v-model="draft"
          class="composer-input"
          rows="2"
          placeholder="向这件古玉提问..."
          @keydown.enter.exact.prevent="sendMessage"
        ></textarea>
        <button type="button" class="jade-button primary" :disabled="apiStore.chatLoading" @click="sendMessage">
          {{ apiStore.chatLoading ? '回复生成中...' : '发送' }}
        </button>
      </footer>

      <p v-if="apiStore.lastError" class="error-text">{{ apiStore.lastError }}</p>
    </article>
  </section>
</template>

<style scoped>
.chat-card {
  padding: 1rem;
  display: grid;
  gap: 0.8rem;
}

.chat-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.8rem;
  flex-wrap: wrap;
}

.head-actions {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.chat-list {
  min-height: 320px;
  max-height: 56vh;
  overflow: auto;
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
  padding: 0.3rem;
  border-radius: var(--radius-md);
  background: rgba(232, 241, 235, 0.45);
  border: 1px solid rgba(69, 100, 90, 0.18);
}

.composer {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 0.65rem;
}

.composer-input {
  resize: vertical;
  min-height: 70px;
  border: 1px solid rgba(55, 90, 77, 0.24);
  border-radius: var(--radius-md);
  padding: 0.65rem 0.72rem;
  background: rgba(252, 253, 252, 0.92);
}

.suggestions {
  padding: 0.8rem 0.65rem;
  background: rgba(236, 244, 239, 0.4);
  border-radius: var(--radius-md);
  border: 1px dashed rgba(63, 88, 75, 0.24);
}

.suggestions p {
  margin-bottom: 0.5rem;
  font-size: 0.9rem;
}

.suggestion-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.suggestion-btn {
  border: 1px solid rgba(45, 82, 68, 0.32);
  background: rgba(255, 255, 255, 0.88);
  border-radius: 999px;
  padding: 0.35rem 0.72rem;
  font-size: 0.85rem;
  color: var(--ink-700);
  cursor: pointer;
  transition: all 0.2s ease;
}

.suggestion-btn:hover {
  background: rgba(220, 234, 225, 0.96);
  border-color: rgba(45, 82, 68, 0.5);
  transform: translateY(-1px);
}

.error-text {
  color: var(--danger);
}

@media (max-width: 780px) {
  .composer {
    grid-template-columns: 1fr;
  }
}
</style>
