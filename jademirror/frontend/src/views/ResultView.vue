<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/userStore'
import { VECTOR_LABELS, MBTI_DIMS, BIG5_DIMS, ARCHETYPE_DIMS } from '@/data/questions'

const userStore = useUserStore()
const router = useRouter()

const jade = computed(() => userStore.matchedJade)
const profile = computed(() => userStore.matchProfile)
const mbtiType = computed(() => userStore.mbtiType)
const archetype = computed(() => userStore.archetype)
const dimensionScores = computed(() => userStore.dimensionScores)

const scorePercent = computed(() => Math.round((userStore.matchScore || 0) * 100))

const showRadar = ref(false)

const radarAxes = computed(() => {
  if (!dimensionScores.value) return []
  const axes = []
  for (const key of MBTI_DIMS) {
    const dim = dimensionScores.value.mbti[key]
    if (!dim) continue
    axes.push({
      label: dim.dominant,
      percent: dim.percent,
      color: '#437065',
    })
  }
  for (const key of BIG5_DIMS) {
    const dim = dimensionScores.value.big5[key]
    if (!dim) continue
    axes.push({
      label: VECTOR_LABELS[key] || key,
      percent: dim.percent,
      color: '#7ca493',
    })
  }
  return axes
})

const radarPoints = computed(() => {
  const axes = radarAxes.value
  if (axes.length === 0) return ''
  const cx = 120
  const cy = 120
  const r = 90
  return axes
    .map((axis, i) => {
      const angle = (Math.PI * 2 * i) / axes.length - Math.PI / 2
      const pr = r * (axis.percent / 100)
      const x = cx + pr * Math.cos(angle)
      const y = cy + pr * Math.sin(angle)
      return `${x},${y}`
    })
    .join(' ')
})

const radarGridLines = computed(() => {
  const axes = radarAxes.value
  const cx = 120
  const cy = 120
  const r = 90
  const levels = [0.25, 0.5, 0.75, 1]
  return levels.map((level) => {
    const points = axes
      .map((_, i) => {
        const angle = (Math.PI * 2 * i) / axes.length - Math.PI / 2
        const x = cx + r * level * Math.cos(angle)
        const y = cy + r * level * Math.sin(angle)
        return `${x},${y}`
      })
      .join(' ')
    return { points, level }
  })
})

const radarAxisLines = computed(() => {
  const axes = radarAxes.value
  const cx = 120
  const cy = 120
  const r = 90
  return axes.map((axis, i) => {
    const angle = (Math.PI * 2 * i) / axes.length - Math.PI / 2
    const x = cx + r * Math.cos(angle)
    const y = cy + r * Math.sin(angle)
    const lx = cx + (r + 18) * Math.cos(angle)
    const ly = cy + (r + 18) * Math.sin(angle)
    return { x1: cx, y1: cy, x2: x, y2: y, lx, ly, label: axis.label }
  })
})

const topArchetypes = computed(() => {
  if (!dimensionScores.value) return []
  const entries = Object.entries(dimensionScores.value.archetypes)
    .map(([key, val]) => ({ key, label: VECTOR_LABELS[key] || key, percent: val.percent }))
    .sort((a, b) => b.percent - a.percent)
  return entries.slice(0, 3)
})

onMounted(() => {
  setTimeout(() => { showRadar.value = true }, 300)
})
</script>

<template>
  <section class="result section-grid">
    <article v-if="jade" class="result-core jade-card">
      <div class="core-identity">
        <img :src="jade.image" :alt="jade.name" class="jade-image" />
        <div class="identity-text">
          <div class="identity-badges">
            <span v-if="mbtiType" class="badge mbti-badge">{{ mbtiType }}</span>
            <span v-if="archetype" class="badge archetype-badge">{{ archetype.label }}</span>
          </div>
          <h2 class="jade-name">{{ jade.dynasty }}代 · {{ jade.name }}</h2>
          <p v-if="profile" class="archetype-label">{{ profile.archetypeLabel }}</p>
          <p class="text-muted">{{ jade.description }}</p>
          <div class="score-ring-wrap">
            <div class="score-ring" :style="{ '--score': scorePercent }">
              <span class="score-num">{{ scorePercent }}%</span>
            </div>
            <span class="score-label">向量相似度</span>
          </div>
        </div>
      </div>
    </article>

    <article v-if="profile" class="verdict-card jade-card">
      <h3 class="section-title">专属判词</h3>
      <p class="verdict-text">{{ profile.verdict }}</p>
      <div class="psychology-box">
        <h4>心理学侧写</h4>
        <div class="psychology-item">
          <span class="psy-label">核心能量</span>
          <span class="psy-value">{{ profile.psychology.coreEnergy }}</span>
        </div>
        <div class="psychology-item">
          <span class="psy-label">性格底色</span>
          <span class="psy-value">{{ profile.psychology.baseColor }}</span>
        </div>
      </div>
    </article>

    <article v-if="showRadar && radarAxes.length" class="radar-card jade-card">
      <h3 class="section-title">维度图谱</h3>
      <div class="radar-wrap">
        <svg viewBox="0 0 240 240" class="radar-svg">
          <polygon
            v-for="grid in radarGridLines"
            :key="grid.level"
            :points="grid.points"
            fill="none"
            stroke="rgba(67, 112, 101, 0.15)"
            stroke-width="1"
          />
          <line
            v-for="(axis, i) in radarAxisLines"
            :key="i"
            :x1="axis.x1" :y1="axis.y1"
            :x2="axis.x2" :y2="axis.y2"
            stroke="rgba(67, 112, 101, 0.2)"
            stroke-width="1"
          />
          <text
            v-for="(axis, i) in radarAxisLines"
            :key="'l'+i"
            :x="axis.lx" :y="axis.ly"
            text-anchor="middle"
            dominant-baseline="central"
            fill="var(--ink-600)"
            font-size="10"
          >{{ axis.label }}</text>
          <polygon
            :points="radarPoints"
            fill="rgba(67, 112, 101, 0.18)"
            stroke="#437065"
            stroke-width="2"
          />
        </svg>
      </div>
      <div v-if="topArchetypes.length" class="archetype-bars">
        <h4>主导原型</h4>
        <div v-for="ar in topArchetypes" :key="ar.key" class="arch-bar-row">
          <span class="arch-bar-label">{{ ar.label }}</span>
          <div class="arch-bar-track">
            <div class="arch-bar-fill" :style="{ width: `${ar.percent}%` }"></div>
          </div>
          <span class="arch-bar-pct">{{ ar.percent }}%</span>
        </div>
      </div>
    </article>

    <article v-if="jade" class="actions-card jade-card">
      <div class="actions-row">
        <button type="button" class="jade-button primary" @click="router.push('/chat')">
          与玉对话
        </button>
        <button type="button" class="jade-button secondary" @click="router.push('/generate')">
          生成专属玉
        </button>
        <button type="button" class="jade-button secondary" @click="router.push('/test')">
          重新测试
        </button>
      </div>
    </article>

    <article v-else class="jade-card fallback">
      <p class="text-muted">暂无匹配结果，请先完成心理测试。</p>
      <button type="button" class="jade-button primary" @click="router.push('/test')">前往测试</button>
    </article>
  </section>
</template>

<style scoped>
.result-core {
  padding: 1.2rem;
}

.core-identity {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 1.2rem;
  align-items: start;
}

.jade-image {
  width: 180px;
  border-radius: var(--radius-md);
  aspect-ratio: 1 / 1;
  object-fit: cover;
  border: 1px solid rgba(65, 99, 86, 0.18);
}

.identity-text {
  display: grid;
  gap: 0.4rem;
  align-content: flex-start;
}

.identity-badges {
  display: flex;
  gap: 0.45rem;
  flex-wrap: wrap;
}

.badge {
  display: inline-flex;
  padding: 0.2rem 0.6rem;
  border-radius: 999px;
  font-size: 0.78rem;
  font-weight: 600;
  letter-spacing: 0.04em;
}

.mbti-badge {
  background: linear-gradient(135deg, rgba(46, 87, 73, 0.88), rgba(67, 112, 101, 0.72));
  color: #eff6f3;
}

.archetype-badge {
  background: rgba(149, 97, 45, 0.18);
  color: var(--amber);
  border: 1px solid rgba(149, 97, 45, 0.28);
}

.jade-name {
  font-size: 1.3rem;
  margin: 0;
}

.archetype-label {
  font-size: 0.92rem;
  color: var(--ink-600);
  font-weight: 500;
}

.score-ring-wrap {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  margin-top: 0.3rem;
}

.score-ring {
  width: 52px;
  height: 52px;
  border-radius: 999px;
  display: grid;
  place-items: center;
  background: conic-gradient(#2d6d59 calc(var(--score) * 3.6deg), rgba(117, 157, 139, 0.22) 0);
  box-shadow: inset 0 0 0 1px rgba(45, 94, 77, 0.18);
}

.score-ring::before {
  content: '';
  width: 40px;
  height: 40px;
  border-radius: 999px;
  background: rgba(248, 252, 250, 0.95);
  position: absolute;
}

.score-num {
  position: relative;
  z-index: 1;
  font-size: 0.82rem;
  font-weight: 700;
  color: var(--ink-700);
}

.score-label {
  font-size: 0.8rem;
  color: var(--ink-500);
}

.section-title {
  font-size: 1.05rem;
  margin-bottom: 0.7rem;
  padding-bottom: 0.4rem;
  border-bottom: 1px solid rgba(64, 98, 86, 0.12);
}

.verdict-card {
  padding: 1rem;
}

.verdict-text {
  font-size: 0.95rem;
  line-height: 1.75;
  color: var(--ink-700);
  margin-bottom: 0.8rem;
}

.psychology-box {
  padding: 0.75rem;
  border-radius: var(--radius-md);
  background: rgba(231, 241, 234, 0.62);
  border: 1px solid rgba(64, 98, 86, 0.16);
}

.psychology-box h4 {
  font-size: 0.9rem;
  margin-bottom: 0.5rem;
}

.psychology-item {
  display: grid;
  gap: 0.2rem;
  margin-bottom: 0.5rem;
}

.psychology-item:last-child {
  margin-bottom: 0;
}

.psy-label {
  font-size: 0.78rem;
  font-weight: 600;
  color: var(--ink-600);
}

.psy-value {
  font-size: 0.86rem;
  color: var(--ink-500);
  line-height: 1.6;
}

.radar-card {
  padding: 1rem;
}

.radar-wrap {
  display: flex;
  justify-content: center;
  margin-bottom: 0.8rem;
}

.radar-svg {
  width: 240px;
  height: 240px;
}

.archetype-bars h4 {
  font-size: 0.9rem;
  margin-bottom: 0.5rem;
}

.arch-bar-row {
  display: grid;
  grid-template-columns: 4rem 1fr 3rem;
  gap: 0.4rem;
  align-items: center;
  margin-bottom: 0.35rem;
}

.arch-bar-label {
  font-size: 0.82rem;
  color: var(--ink-600);
}

.arch-bar-track {
  height: 8px;
  border-radius: 999px;
  background: rgba(205, 221, 212, 0.72);
  overflow: hidden;
}

.arch-bar-fill {
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(135deg, #437065, #7ca493);
  transition: width 0.8s var(--ease-soft);
}

.arch-bar-pct {
  font-size: 0.78rem;
  color: var(--ink-500);
  text-align: right;
}

.actions-card {
  padding: 1rem;
}

.fallback {
  padding: 1rem;
  display: grid;
  gap: 0.8rem;
}

@media (max-width: 820px) {
  .core-identity {
    grid-template-columns: 1fr;
    justify-items: center;
    text-align: center;
  }

  .jade-image {
    width: 140px;
  }

  .identity-badges {
    justify-content: center;
  }

  .score-ring-wrap {
    justify-content: center;
  }
}
</style>
