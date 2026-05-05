<script setup>
defineProps({
  role: {
    type: String,
    default: 'assistant',
  },
  content: {
    type: String,
    default: '',
  },
})
</script>

<template>
  <div class="bubble" :class="role === 'user' ? 'bubble-user' : 'bubble-assistant'">
    <p>{{ content }}</p>
  </div>
</template>

<style scoped>
.bubble {
  max-width: min(76ch, 86%);
  padding: 0.72rem 0.84rem;
  border-radius: 14px;
  line-height: 1.55;
  animation: reveal 0.24s ease;
}

.bubble-user {
  margin-left: auto;
  background: linear-gradient(135deg, rgba(75, 115, 98, 0.92), rgba(104, 146, 128, 0.86));
  color: #f3f8f4;
}

.bubble-assistant {
  background: rgba(246, 249, 246, 0.95);
  border: 1px solid rgba(67, 97, 87, 0.18);
  color: var(--ink-900);
}

@keyframes reveal {
  from {
    opacity: 0;
    transform: translateY(4px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>
