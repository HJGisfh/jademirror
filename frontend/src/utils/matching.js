const DIMENSION_RULES = [
  { key: 'landscape', weight: 3.2, label: '山水气韵' },
  { key: 'color', weight: 3, label: '玉色偏好' },
  { key: 'symbol', weight: 3.2, label: '纹样意象' },
  { key: 'mood', weight: 1.4, label: '心境倾向' },
  { key: 'texture', weight: 1.2, label: '质地喜好' },
]

const RELATED_TRAITS = {
  landscape: {
    山: ['竹'],
    水: ['云'],
    竹: ['山'],
    云: ['水'],
  },
  color: {
    青: ['白'],
    白: ['青'],
    赤: ['黄'],
    黄: ['赤'],
  },
  symbol: {
    龙: ['璧'],
    凤: ['蝉'],
    蝉: ['凤'],
    璧: ['龙'],
  },
  mood: {
    静: ['雅'],
    雅: ['静'],
    烈: ['灵'],
    灵: ['烈'],
  },
  texture: {
    润: ['素'],
    透: ['雕'],
    雕: ['透'],
    素: ['润'],
  },
}

function scoreOneDimension({ key, weight, userValue, jadeValue }) {
  if (!userValue || !jadeValue) {
    return 0
  }

  if (userValue === jadeValue) {
    return weight
  }

  const relatedList = RELATED_TRAITS[key]?.[userValue] || []
  if (relatedList.includes(jadeValue)) {
    return weight * 0.45
  }

  return 0
}

function buildReason(answers, jade, details) {
  const top = [...details].sort((a, b) => b.score - a.score)[0]
  if (!top) {
    return `你与${jade.name}的整体气质接近，呈现出稳定的心性共鸣。`
  }

  const answer = answers[top.key]

  const reasonMap = {
    landscape: `你选择“${answer}”意象，与这件玉器的山水气韵同频，呈现出相近的精神节奏。`,
    color: `你偏好的“${answer}”色调，与该玉器的主色倾向高度一致，映照出温润而明确的审美取向。`,
    symbol: `你对“${answer}”纹样有明显偏好，与这件玉器的核心象征契合，因此匹配度最高。`,
    mood: `你当前追求“${answer}”心境，而这件玉器的人格特征恰好能承接这种心理状态。`,
    texture: `你偏好的“${answer}”触感，与此玉器的材质想象一致，形成了细腻的感官共鸣。`,
  }

  return reasonMap[top.key]
}

export function matchJadeByAnswers({ jades, answers }) {
  if (!Array.isArray(jades) || jades.length === 0) {
    throw new Error('玉器库为空，无法执行匹配。')
  }

  const totalWeight = DIMENSION_RULES.reduce((acc, rule) => acc + rule.weight, 0)

  let best = null

  for (const jade of jades) {
    const details = DIMENSION_RULES.map((rule) => {
      return {
        key: rule.key,
        label: rule.label,
        score: scoreOneDimension({
          key: rule.key,
          weight: rule.weight,
          userValue: answers[rule.key],
          jadeValue: jade.traits?.[rule.key],
        }),
      }
    })

    const scoreRaw = details.reduce((acc, item) => acc + item.score, 0)
    const scoreNormalized = scoreRaw / totalWeight

    if (!best || scoreNormalized > best.score) {
      best = {
        jade,
        score: scoreNormalized,
        details,
      }
    }
  }

  return {
    jade: best.jade,
    score: Number(best.score.toFixed(4)),
    reason: buildReason(answers, best.jade, best.details),
    details: best.details,
  }
}
