<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import QuestionCard from '@/components/QuestionCard.vue'
import { fetchJadeLibrary } from '@/api/jadeLibrary'
import { testQuestions } from '@/data/questions'
import { useUserStore } from '@/stores/userStore'
import { matchJadeByAnswers } from '@/utils/matching'

const userStore = useUserStore()
const router = useRouter()

const answers = reactive({ ...userStore.testAnswers })
const jades = ref([])
const libraryLoading = ref(false)
const submitting = ref(false)
const errorText = ref('')
const currentIndex = ref(0)

const requiredCompleted = computed(() => {
  return ['landscape', 'color', 'symbol'].every((key) => !!answers[key])
})

const allCompleted = computed(() => {
  return testQuestions.every((question) => !!answers[question.id])
})

const answeredCount = computed(() => {
  return testQuestions.filter((question) => answers[question.id]).length
})

const currentQuestion = computed(() => testQuestions[currentIndex.value])
const isFirstQuestion = computed(() => currentIndex.value === 0)
const isLastQuestion = computed(() => currentIndex.value === testQuestions.length - 1)
const currentAnswered = computed(() => !!answers[currentQuestion.value.id])

const progressPercent = computed(() => {
  return Math.round(((currentIndex.value + 1) / testQuestions.length) * 100)
})

async function loadJades() {
  if (jades.value.length) {
    return
  }

  libraryLoading.value = true
  errorText.value = ''

  try {
    jades.value = await fetchJadeLibrary()
  } catch (error) {
    errorText.value = error.message || '玉器库加载失败。'
  } finally {
    libraryLoading.value = false
  }
}

function resetAnswers() {
  for (const question of testQuestions) {
    answers[question.id] = ''
  }
  currentIndex.value = 0
  errorText.value = ''
}

function goToQuestion(index) {
  if (index < 0 || index >= testQuestions.length) {
    return
  }
  currentIndex.value = index
  errorText.value = ''
}

function goToPrev() {
  if (isFirstQuestion.value) {
    return
  }
  goToQuestion(currentIndex.value - 1)
}

function goToNext() {
  if (!currentAnswered.value) {
    errorText.value = '请先完成当前题目后再进入下一题。'
    return
  }

  if (isLastQuestion.value) {
    return
  }

  goToQuestion(currentIndex.value + 1)
}

async function submitMatch() {
  if (!allCompleted.value) {
    errorText.value = '请先完成全部题目，再提交匹配。'
    return
  }

  if (!requiredCompleted.value) {
    errorText.value = '请至少完成山水、色彩、纹样三个核心问题。'
    return
  }

  if (!jades.value.length) {
    await loadJades()
  }

  if (!jades.value.length) {
    return
  }

  submitting.value = true
  errorText.value = ''

  try {
    const result = matchJadeByAnswers({
      jades: jades.value,
      answers,
    })

    userStore.setAllAnswers({ ...answers })
    userStore.setMatchResult({
      jade: result.jade,
      reason: result.reason,
      score: result.score,
    })
    userStore.clearGeneratedResult()

    router.push('/result')
  } catch (error) {
    errorText.value = error.message || '匹配失败，请稍后重试。'
  } finally {
    submitting.value = false
  }
}

onMounted(() => {
  loadJades()

  const firstUnanswered = testQuestions.findIndex((question) => !answers[question.id])
  if (firstUnanswered >= 0) {
    currentIndex.value = firstUnanswered
  } else {
    currentIndex.value = testQuestions.length - 1
  }
})
</script>

<template>
  <section class="test section-grid">
    <article class="meta jade-card">
      <p class="text-muted">
        当前第 {{ currentIndex + 1 }} / {{ testQuestions.length }} 题，已完成 {{ answeredCount }} 题。
      </p>

      <div class="progress-wrap" aria-label="测试进度">
        <div class="progress-bar" :style="{ width: `${progressPercent}%` }"></div>
      </div>

      <div class="step-row">
        <button
          v-for="(question, index) in testQuestions"
          :key="question.id"
          type="button"
          class="step-dot"
          :class="{
            active: currentIndex === index,
            done: !!answers[question.id],
          }"
          @click="goToQuestion(index)"
        >
          {{ index + 1 }}
        </button>
      </div>

      <div class="actions-row">
        <button type="button" class="jade-button secondary" :disabled="isFirstQuestion" @click="goToPrev">
          上一题
        </button>
        <button
          v-if="!isLastQuestion"
          type="button"
          class="jade-button secondary"
          @click="goToNext"
        >
          下一题
        </button>
        <button type="button" class="jade-button secondary" @click="resetAnswers">重置答案</button>
        <button
          v-if="isLastQuestion"
          type="button"
          class="jade-button primary"
          :disabled="submitting || libraryLoading"
          @click="submitMatch"
        >
          {{ submitting ? '匹配中...' : '提交并匹配古玉' }}
        </button>
      </div>
      <p v-if="errorText" class="error-text">{{ errorText }}</p>
    </article>

    <article v-if="libraryLoading" class="jade-card loading-card">
      <span class="loading-dot"></span>
      <p>正在加载玉器库...</p>
    </article>

    <QuestionCard v-model="answers[currentQuestion.id]" :question="currentQuestion" />
  </section>
</template>

<style scoped>
.meta {
  padding: 1rem;
  display: grid;
  gap: 0.75rem;
}

.loading-card {
  padding: 1rem;
  display: flex;
  align-items: center;
  gap: 0.6rem;
}

.progress-wrap {
  width: 100%;
  height: 8px;
  border-radius: 999px;
  background: rgba(205, 221, 212, 0.72);
  overflow: hidden;
}

.progress-bar {
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(135deg, #437065, #7ca493);
  transition: width 0.3s ease;
}

.step-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
}

.step-dot {
  width: 1.9rem;
  height: 1.9rem;
  border-radius: 999px;
  border: 1px solid rgba(58, 93, 80, 0.22);
  background: rgba(248, 252, 249, 0.85);
  color: var(--ink-500);
  cursor: pointer;
}

.step-dot.done {
  background: rgba(206, 226, 214, 0.8);
  color: var(--ink-700);
}

.step-dot.active {
  border-color: transparent;
  background: rgba(46, 87, 73, 0.88);
  color: #eff6f3;
}

.error-text {
  color: var(--danger);
}
</style>
