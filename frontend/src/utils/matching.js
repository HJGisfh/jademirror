import { VECTOR_KEYS, MBTI_DIMS, BIG5_DIMS, ARCHETYPE_DIMS, createZeroVector } from '@/data/questions'
import { jadeProfiles, getJadeProfile } from '@/data/jadeProfiles'

function addVectors(base, delta) {
  const result = { ...base }
  for (const key of Object.keys(delta)) {
    result[key] = (result[key] || 0) + delta[key]
  }
  return result
}

function cosineSimilarity(a, b) {
  let dotProduct = 0
  let normA = 0
  let normB = 0

  for (const key of VECTOR_KEYS) {
    const va = a[key] || 0
    const vb = b[key] || 0
    dotProduct += va * vb
    normA += va * va
    normB += vb * vb
  }

  if (normA === 0 || normB === 0) {
    return 0
  }

  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB))
}

export function computeUserVector(questions, answers) {
  let vector = createZeroVector()

  for (const question of questions) {
    const answerValue = answers[question.id]
    if (!answerValue) continue

    const option = question.options.find((o) => o.value === answerValue)
    if (!option || !option.vector) continue

    vector = addVectors(vector, option.vector)
  }

  return vector
}

export function deriveMbtiType(vector) {
  const letters = [
    vector.EI >= 0 ? 'E' : 'I',
    vector.SN >= 0 ? 'S' : 'N',
    vector.TF >= 0 ? 'T' : 'F',
    vector.JP >= 0 ? 'J' : 'P',
  ]
  return letters.join('')
}

function getDominantArchetype(vector) {
  let best = 'Sage'
  let bestVal = -Infinity
  for (const key of ARCHETYPE_DIMS) {
    const val = vector[key] || 0
    if (val > bestVal) {
      bestVal = val
      best = key
    }
  }
  const labelMap = {
    Warrior: '战士',
    Sage: '智者',
    Explorer: '探索者',
    Mediator: '调停者',
    Creator: '创造者',
    Ruler: '统治者',
    Healer: '治愈者',
  }
  return { key: best, label: labelMap[best] || best, score: bestVal }
}

function computeDimensionScores(vector) {
  const mbti = {}
  for (const key of MBTI_DIMS) {
    const val = vector[key] || 0
    const absVal = Math.abs(val)
    const maxPossible = 8
    const percent = Math.min(100, Math.round((absVal / maxPossible) * 100))
    const labels = {
      EI: val >= 0 ? 'E' : 'I',
      SN: val >= 0 ? 'S' : 'N',
      TF: val >= 0 ? 'T' : 'F',
      JP: val >= 0 ? 'J' : 'P',
    }
    mbti[key] = { value: val, percent, dominant: labels[key] }
  }

  const big5 = {}
  for (const key of BIG5_DIMS) {
    const val = vector[key] || 0
    const maxPossible = 8
    const normalized = (val + maxPossible) / (2 * maxPossible)
    const percent = Math.min(100, Math.max(0, Math.round(normalized * 100)))
    big5[key] = { value: val, percent }
  }

  const archetypes = {}
  for (const key of ARCHETYPE_DIMS) {
    const val = vector[key] || 0
    const maxPossible = 8
    const percent = Math.min(100, Math.max(0, Math.round((val / maxPossible) * 100)))
    archetypes[key] = { value: val, percent }
  }

  return { mbti, big5, archetypes }
}

function deriveFlowchartPath(questions, answers, vector, profile) {
  const steps = []
  const moduleAnswers = {}

  for (const question of questions) {
    const answerValue = answers[question.id]
    if (!answerValue) continue
    const option = question.options.find((o) => o.value === answerValue)
    if (!option) continue

    if (!moduleAnswers[question.module]) {
      moduleAnswers[question.module] = []
    }
    moduleAnswers[question.module].push({
      questionId: question.id,
      label: option.label,
      moduleTitle: question.moduleTitle,
    })
  }

  for (const [moduleKey, items] of Object.entries(moduleAnswers)) {
    steps.push({
      type: 'module',
      moduleKey,
      moduleTitle: items[0]?.moduleTitle || moduleKey,
      choices: items.map((i) => i.label),
    })
  }

  const mbtiType = deriveMbtiType(vector)
  steps.push({
    type: 'mbti',
    label: mbtiType,
  })

  const archetype = getDominantArchetype(vector)
  steps.push({
    type: 'archetype',
    label: archetype.label,
  })

  steps.push({
    type: 'jade',
    label: profile ? `${profile.archetypeLabel}` : '古玉',
  })

  return steps
}

export function matchJadeByVector({ jades, userVector }) {
  if (!Array.isArray(jades) || jades.length === 0) {
    throw new Error('玉器库为空，无法执行匹配。')
  }

  const scores = []

  for (const jade of jades) {
    const profile = getJadeProfile(jade.id)
    if (!profile) continue

    const similarity = cosineSimilarity(userVector, profile.vector)
    scores.push({ jade, profile, similarity })
  }

  scores.sort((a, b) => b.similarity - a.similarity)

  const best = scores[0]
  if (!best) {
    throw new Error('未找到匹配的玉器。')
  }

  const worst = scores[scores.length - 1]

  const mbtiType = deriveMbtiType(userVector)
  const archetype = getDominantArchetype(userVector)
  const dimensionScores = computeDimensionScores(userVector)

  return {
    jade: best.jade,
    profile: best.profile,
    score: best.similarity,
    mbtiType,
    archetype,
    dimensionScores,
    shadowJade: worst.jade,
    shadowProfile: worst.profile,
    allScores: scores.map((s) => ({
      jadeId: s.jade.id,
      jadeName: s.jade.name,
      similarity: s.similarity,
    })),
  }
}

export function matchJadeByAnswers({ jades, answers }) {
  throw new Error('请使用 matchJadeByVector 进行向量匹配。')
}

export { computeDimensionScores, getDominantArchetype, deriveFlowchartPath, cosineSimilarity }
