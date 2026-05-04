<script setup>
const props = defineProps({
  question: {
    type: Object,
    required: true,
  },
  modelValue: {
    type: String,
    default: '',
  },
  showModule: {
    type: Boolean,
    default: false,
  },
})

const emit = defineEmits(['update:modelValue'])

function chooseOption(value) {
  emit('update:modelValue', value)
}
</script>

<template>
  <article class="question-card jade-card">
    <header class="question-header">
      <p v-if="showModule && question.moduleTitle" class="module-badge">
        {{ question.moduleTitle }}
      </p>
      <p class="question-subtitle">{{ question.subtitle }}</p>
      <h3>{{ question.title }}</h3>
    </header>

    <div class="option-grid">
      <button
        v-for="option in question.options"
        :key="option.value"
        type="button"
        class="option-card"
        :class="{ active: modelValue === option.value }"
        :style="{ '--option-tone': option.tone }"
        @click="chooseOption(option.value)"
      >
        <div class="option-title-row">
          <span class="option-title">{{ option.label }}</span>
          <span v-if="modelValue === option.value" class="picked-dot"></span>
        </div>
        <p>{{ option.description }}</p>
      </button>
    </div>
  </article>
</template>

<style scoped>
.question-card {
  padding: 1rem;
}

.question-header {
  margin-bottom: 0.9rem;
}

.module-badge {
  display: inline-block;
  font-size: 0.78rem;
  padding: 0.18rem 0.6rem;
  border-radius: 999px;
  background: linear-gradient(135deg, rgba(67, 112, 101, 0.18), rgba(82, 133, 114, 0.12));
  color: var(--ink-600);
  margin-bottom: 0.35rem;
  letter-spacing: 0.04em;
}

.question-subtitle {
  display: inline-block;
  font-size: 0.8rem;
  padding: 0.18rem 0.55rem;
  border-radius: 999px;
  background: rgba(75, 112, 98, 0.14);
  color: var(--ink-500);
}

.question-header h3 {
  margin-top: 0.42rem;
  font-size: 1.1rem;
}

.option-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.65rem;
}

.option-card {
  border: 1px solid rgba(63, 99, 86, 0.16);
  border-radius: var(--radius-md);
  background:
    linear-gradient(150deg, color-mix(in srgb, var(--option-tone), #ffffff 70%), rgba(255, 255, 255, 0.8));
  padding: 0.72rem 0.8rem;
  text-align: left;
  cursor: pointer;
  transition: transform 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease;
}

.option-card p {
  margin: 0.25rem 0 0;
  color: var(--ink-500);
  font-size: 0.86rem;
}

.option-card:hover {
  transform: translateY(-1px);
  border-color: rgba(66, 104, 91, 0.3);
}

.option-card.active {
  border-color: rgba(43, 85, 72, 0.6);
  box-shadow: 0 8px 16px rgba(46, 82, 72, 0.18);
}

.option-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.4rem;
}

.option-title {
  font-weight: 600;
  color: var(--ink-700);
}

.picked-dot {
  width: 0.65rem;
  height: 0.65rem;
  border-radius: 999px;
  background: linear-gradient(135deg, #356457, #89ae9b);
}

@media (max-width: 760px) {
  .option-grid {
    grid-template-columns: 1fr;
  }
}
</style>
