<script setup>
import { computed } from 'vue'

const props = defineProps({
  state: {
    type: String,
    default: 'idle',
    validator: (v) => ['idle', 'listening', 'thinking', 'speaking'].includes(v),
  },
  size: {
    type: Number,
    default: 64,
  },
})

const bodyColor = computed(() => {
  const map = {
    idle: '#a8d5c4',
    listening: '#7ec8a8',
    thinking: '#d4c47a',
    speaking: '#8dd4b8',
  }
  return map[props.state] || map.idle
})

const cheekColor = computed(() => {
  const map = {
    idle: '#f0b8a8',
    listening: '#f5a89a',
    thinking: '#e8c878',
    speaking: '#f0b8a8',
  }
  return map[props.state] || map.idle
})

const glowColor = computed(() => {
  const map = {
    idle: 'rgba(168, 213, 196, 0.3)',
    listening: 'rgba(126, 200, 168, 0.5)',
    thinking: 'rgba(212, 196, 122, 0.4)',
    speaking: 'rgba(141, 212, 184, 0.45)',
  }
  return map[props.state] || map.idle
})
</script>

<template>
  <div class="spirit-pet" :class="state" :style="{ '--pet-size': `${size}px` }">
    <svg
      :width="size"
      :height="size"
      viewBox="0 0 100 100"
      class="pet-svg"
    >
      <defs>
        <radialGradient id="pet-body-grad" cx="45%" cy="40%" r="55%">
          <stop offset="0%" :stop-color="bodyColor" stop-opacity="1" />
          <stop offset="70%" :stop-color="bodyColor" stop-opacity="0.85" />
          <stop offset="100%" :stop-color="bodyColor" stop-opacity="0.6" />
        </radialGradient>
        <radialGradient id="pet-glow-grad" cx="50%" cy="50%" r="50%">
          <stop offset="0%" :stop-color="bodyColor" stop-opacity="0.25" />
          <stop offset="100%" :stop-color="bodyColor" stop-opacity="0" />
        </radialGradient>
        <radialGradient id="pet-cheek-grad" cx="50%" cy="50%" r="50%">
          <stop offset="0%" :stop-color="cheekColor" stop-opacity="0.7" />
          <stop offset="100%" :stop-color="cheekColor" stop-opacity="0" />
        </radialGradient>
      </defs>

      <circle cx="50" cy="52" r="46" fill="url(#pet-glow-grad)" class="outer-glow" />

      <ellipse cx="50" cy="54" rx="28" ry="26" fill="url(#pet-body-grad)" class="body" />

      <ellipse cx="50" cy="42" rx="18" ry="16" fill="url(#pet-body-grad)" class="head" />

      <ellipse cx="36" cy="30" rx="6" ry="10" :fill="bodyColor" fill-opacity="0.8" class="ear ear-left" />
      <ellipse cx="36" cy="30" rx="3" ry="6" :fill="cheekColor" fill-opacity="0.3" class="ear-inner ear-left" />
      <ellipse cx="64" cy="30" rx="6" ry="10" :fill="bodyColor" fill-opacity="0.8" class="ear ear-right" />
      <ellipse cx="64" cy="30" rx="3" ry="6" :fill="cheekColor" fill-opacity="0.3" class="ear-inner ear-right" />

      <g class="face" :class="state">
        <template v-if="state === 'idle'">
          <ellipse cx="42" cy="42" rx="4" ry="4.5" fill="#2d4a3e" />
          <ellipse cx="58" cy="42" rx="4" ry="4.5" fill="#2d4a3e" />
          <ellipse cx="43.5" cy="40.5" rx="1.5" ry="1.8" fill="#fff" fill-opacity="0.8" />
          <ellipse cx="59.5" cy="40.5" rx="1.5" ry="1.8" fill="#fff" fill-opacity="0.8" />
          <path d="M44 49 Q50 53 56 49" fill="none" stroke="#2d4a3e" stroke-width="1.5" stroke-linecap="round" />
          <circle cx="34" cy="46" r="4" fill="url(#pet-cheek-grad)" />
          <circle cx="66" cy="46" r="4" fill="url(#pet-cheek-grad)" />
        </template>

        <template v-else-if="state === 'listening'">
          <ellipse cx="42" cy="41" rx="5" ry="5.5" fill="#2d4a3e" />
          <ellipse cx="58" cy="41" rx="5" ry="5.5" fill="#2d4a3e" />
          <ellipse cx="43.5" cy="39.5" rx="2" ry="2.2" fill="#fff" fill-opacity="0.85" />
          <ellipse cx="59.5" cy="39.5" rx="2" ry="2.2" fill="#fff" fill-opacity="0.85" />
          <ellipse cx="50" cy="50" rx="3" ry="2.5" fill="#2d4a3e" fill-opacity="0.6" />
          <circle cx="33" cy="45" r="5" fill="url(#pet-cheek-grad)" />
          <circle cx="67" cy="45" r="5" fill="url(#pet-cheek-grad)" />
          <path d="M28 36 Q24 30 30 26" fill="none" :stroke="bodyColor" stroke-opacity="0.5" stroke-width="1.5" stroke-linecap="round" class="listen-wave lw1" />
          <path d="M72 36 Q76 30 70 26" fill="none" :stroke="bodyColor" stroke-opacity="0.5" stroke-width="1.5" stroke-linecap="round" class="listen-wave lw2" />
        </template>

        <template v-else-if="state === 'thinking'">
          <line x1="38" y1="42" x2="46" y2="42" stroke="#2d4a3e" stroke-width="2" stroke-linecap="round" class="think-eye" />
          <line x1="54" y1="42" x2="62" y2="42" stroke="#2d4a3e" stroke-width="2" stroke-linecap="round" class="think-eye" />
          <circle cx="50" cy="51" r="1.5" fill="#2d4a3e" fill-opacity="0.5" class="think-dot" />
          <circle cx="34" cy="46" r="3.5" fill="url(#pet-cheek-grad)" />
          <circle cx="66" cy="46" r="3.5" fill="url(#pet-cheek-grad)" />
          <g class="think-bubbles">
            <circle cx="72" cy="28" r="2.5" :fill="bodyColor" fill-opacity="0.5" />
            <circle cx="78" cy="22" r="1.8" :fill="bodyColor" fill-opacity="0.4" />
            <circle cx="82" cy="17" r="1.2" :fill="bodyColor" fill-opacity="0.3" />
          </g>
        </template>

        <template v-else-if="state === 'speaking'">
          <ellipse cx="42" cy="42" rx="4" ry="4.5" fill="#2d4a3e" />
          <ellipse cx="58" cy="42" rx="4" ry="4.5" fill="#2d4a3e" />
          <ellipse cx="43.5" cy="40.5" rx="1.5" ry="1.8" fill="#fff" fill-opacity="0.8" />
          <ellipse cx="59.5" cy="40.5" rx="1.5" ry="1.8" fill="#fff" fill-opacity="0.8" />
          <ellipse cx="50" cy="51" rx="4" ry="3" fill="#2d4a3e" fill-opacity="0.5" class="speak-mouth" />
          <circle cx="34" cy="46" r="4" fill="url(#pet-cheek-grad)" />
          <circle cx="66" cy="46" r="4" fill="url(#pet-cheek-grad)" />
        </template>
      </g>

      <g class="limbs">
        <ellipse cx="30" cy="62" rx="5" ry="3.5" :fill="bodyColor" fill-opacity="0.7" class="arm arm-left" />
        <ellipse cx="70" cy="62" rx="5" ry="3.5" :fill="bodyColor" fill-opacity="0.7" class="arm arm-right" />
        <ellipse cx="40" cy="78" rx="6" ry="4" :fill="bodyColor" fill-opacity="0.75" class="foot foot-left" />
        <ellipse cx="60" cy="78" rx="6" ry="4" :fill="bodyColor" fill-opacity="0.75" class="foot foot-right" />
      </g>

      <g class="jade-gem">
        <ellipse cx="50" cy="60" rx="4" ry="3.5" fill="#5a9b82" fill-opacity="0.6" class="gem" />
        <ellipse cx="50" cy="59" rx="2" ry="1.5" fill="#8dd4b8" fill-opacity="0.5" class="gem-shine" />
      </g>
    </svg>

    <div v-if="state === 'listening'" class="pulse-ring" :style="{ '--pulse-color': bodyColor }"></div>
    <div v-if="state === 'speaking'" class="sound-bars">
      <span v-for="i in 4" :key="i" class="bar" :style="{ animationDelay: `${i * 0.1}s` }"></span>
    </div>
  </div>
</template>

<style scoped>
.spirit-pet {
  position: relative;
  width: var(--pet-size);
  height: var(--pet-size);
  cursor: pointer;
  transition: transform 0.3s ease;
}

.spirit-pet:hover {
  transform: scale(1.08);
}

.pet-svg {
  display: block;
  filter: drop-shadow(0 3px 10px v-bind(glowColor));
}

.outer-glow {
  animation: glow-pulse 3s ease-in-out infinite;
}

.body {
  animation: body-breathe 2.5s ease-in-out infinite;
  transform-origin: 50px 54px;
}

.head {
  animation: head-bob 3s ease-in-out infinite;
  transform-origin: 50px 42px;
}

.ear {
  animation: ear-twitch 4s ease-in-out infinite;
  transform-origin: 50px 42px;
}

.ear-inner {
  animation: ear-twitch 4s ease-in-out infinite;
  transform-origin: 50px 42px;
}

.ear-right {
  animation-delay: -2s;
}

.arm {
  animation: arm-sway 2.5s ease-in-out infinite;
  transform-origin: 50px 54px;
}

.arm-right {
  animation-delay: -1.2s;
}

.foot {
  animation: foot-tap 3s ease-in-out infinite;
  transform-origin: 50px 78px;
}

.foot-right {
  animation-delay: -1.5s;
}

.gem {
  animation: gem-glow 2s ease-in-out infinite;
}

.gem-shine {
  animation: gem-shine 2s ease-in-out infinite;
}

.listen-wave {
  animation: wave-appear 1s ease-in-out infinite;
}

.lw2 {
  animation-delay: 0.25s;
}

.think-eye {
  animation: think-blink 2.5s ease-in-out infinite;
}

.think-dot {
  animation: think-bob 1.5s ease-in-out infinite;
}

.think-bubbles {
  animation: bubble-float 2s ease-in-out infinite;
}

.speak-mouth {
  animation: speak-open 0.35s ease-in-out infinite alternate;
}

.pulse-ring {
  position: absolute;
  inset: -8px;
  border-radius: 999px;
  border: 2px solid var(--pulse-color);
  opacity: 0;
  animation: ring-expand 1.5s ease-out infinite;
  pointer-events: none;
}

.sound-bars {
  position: absolute;
  bottom: -4px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  gap: 2px;
  align-items: flex-end;
  height: 10px;
}

.bar {
  width: 3px;
  border-radius: 999px;
  background: linear-gradient(180deg, #6bb5a0, #a8d5c4);
  animation: bar-bounce 0.5s ease-in-out infinite alternate;
}

@keyframes glow-pulse {
  0%, 100% { opacity: 0.5; }
  50% { opacity: 0.9; }
}

@keyframes body-breathe {
  0%, 100% { transform: scaleY(1); }
  50% { transform: scaleY(1.03); }
}

@keyframes head-bob {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-1px); }
}

@keyframes ear-twitch {
  0%, 85%, 100% { transform: rotate(0deg); }
  90% { transform: rotate(-3deg); }
  95% { transform: rotate(2deg); }
}

@keyframes arm-sway {
  0%, 100% { transform: rotate(0deg); }
  50% { transform: rotate(3deg); }
}

@keyframes foot-tap {
  0%, 70%, 100% { transform: rotate(0deg); }
  80% { transform: rotate(-2deg); }
}

@keyframes gem-glow {
  0%, 100% { fill-opacity: 0.5; }
  50% { fill-opacity: 0.8; }
}

@keyframes gem-shine {
  0%, 100% { fill-opacity: 0.3; transform: scale(1); }
  50% { fill-opacity: 0.7; transform: scale(1.1); }
}

@keyframes wave-appear {
  0%, 100% { opacity: 0; transform: scale(0.8); }
  50% { opacity: 0.7; transform: scale(1.2); }
}

@keyframes think-blink {
  0%, 42%, 48%, 100% { opacity: 1; }
  45% { opacity: 0.1; }
}

@keyframes think-bob {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-2px); }
}

@keyframes bubble-float {
  0%, 100% { transform: translateY(0); opacity: 0.6; }
  50% { transform: translateY(-3px); opacity: 1; }
}

@keyframes speak-open {
  from { ry: 2; rx: 3; }
  to { ry: 4; rx: 5; }
}

@keyframes ring-expand {
  0% { transform: scale(0.9); opacity: 0.5; }
  100% { transform: scale(1.4); opacity: 0; }
}

@keyframes bar-bounce {
  from { height: 2px; }
  to { height: 8px; }
}

.spirit-pet.listening .pet-svg {
  filter: drop-shadow(0 3px 14px rgba(126, 200, 168, 0.5));
}

.spirit-pet.listening .ear {
  animation: ear-perk 0.6s ease-in-out infinite alternate;
}

.spirit-pet.thinking .pet-svg {
  filter: drop-shadow(0 3px 12px rgba(212, 196, 122, 0.4));
}

.spirit-pet.speaking .pet-svg {
  filter: drop-shadow(0 3px 14px rgba(141, 212, 184, 0.45));
}

.spirit-pet.speaking .arm {
  animation: arm-wave 0.6s ease-in-out infinite alternate;
}

@keyframes ear-perk {
  from { transform: rotate(0deg); }
  to { transform: rotate(-5deg); }
}

@keyframes arm-wave {
  from { transform: rotate(0deg); }
  to { transform: rotate(8deg); }
}
</style>
