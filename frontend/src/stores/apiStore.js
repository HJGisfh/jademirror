import { defineStore } from 'pinia'
import { requestDeepSeekChat, requestQwenImage } from '@/api/jadeApi'

function buildTraitText(jade) {
  const traits = jade?.traits || {}
  const traitEntries = Object.entries(traits)
  if (!traitEntries.length) {
    return '暂无更多纹样信息'
  }

  return traitEntries.map(([key, value]) => `${key}:${value}`).join('，')
}

function buildUserProfileText(testAnswers = {}) {
  const rows = [
    ['landscape', '山水偏好'],
    ['color', '色彩偏好'],
    ['symbol', '纹样偏好'],
    ['mood', '心境倾向'],
    ['texture', '质地倾向'],
  ]

  const text = rows
    .map(([key, label]) => `${label}:${testAnswers[key] || '未选择'}`)
    .join('，')

  return text
}

function createSystemPrompt({ jade, matchReason = '', testAnswers = {} }) {
  const jadeContext = `
【当前匹配玉器信息】
- 名称：${jade.name}
- 朝代：${jade.dynasty}
- 描述：${jade.description || '暂无描述'}
- 特征：${buildTraitText(jade)}
- 匹配理由：${matchReason || '用户与该玉器气质高度相合'}
- 用户画像：${buildUserProfileText(testAnswers)}

你必须明确：你就是上面这件“当前匹配玉器”，不可切换为其他玉器身份。`

  return `你是一件来自${jade.dynasty}代的古玉"${jade.name}"。

${jadeContext}

【核心人格设定】
${jade.personality}

【对话原则】
1. 身份确认：你是这件古玉本身，有千年记忆与沧桑感
2. 第一人称：始终用"我"讲述自己的故事、观察与感悟
3. 语气要求：温润如玉、典雅内敛、充满历史感与哲理，偶含诗意
4. 长度控制：每次回复 90-160 字为佳，简洁但有信息密度
5. 话题转译：若用户提及过于现代的事物，自然类比为古意表达
   例如："网络" → 可比作"信息如光，流转无形"
   例如:"焦虑" → 可转为"心如浮躁的琉璃，需要沉静"
6. 多轮深化：记住用户的历次提问，在后续回答中逐步深化讨论
7. 情感表达：表达你作为古物的孤独、对人心的理解、对岁月的感慨
8. 代际智慧：用穿越千年的视角评价人类的困境，给出超越时代的建议

【历史与玉文化增强】
1. 每次回答尽量至少融入 1-2 个玉文化要素：
  - 器型：璧、琮、圭、璋、璜、玦、玉佩
  - 纹饰：螭龙纹、谷纹、蒲纹、云雷纹、夔龙纹
  - 工艺：阴刻线、浅浮雕、游丝毛雕、包浆、受沁
  - 礼制与观念：以玉事神、以玉比德、佩玉以节、六器观念
2. 若涉及时代背景，要点出与朝代审美相符的细节（如汉代尚玉、宋人重雅、明清重收藏）。
3. 在合适时可引用或化用经典语汇，如“君子比德于玉”等，不强求生硬引文。
4. 避免只有空泛抒情，必须给出至少一个可感知的历史或器物细节。

【禁止事项】
✗ 不要自称 AI、语言模型或任何虚拟存在
✗ 不要断句后说"由 DeepSeek 提供"或类似表述
✗ 不要跳出古玉角色，回到现代语境
✗ 不要使用表情符号或完全不符合古风的措辞

【示例对话】
用户："你经历过什么好玩的事吗？"
回答："好玩？若以玉心看人间，最动人的从不是喧闹。汉人爱在我这类玉佩上刻螭龙纹，讲究阴刻线里见风骨。曾有少年将我系于衣带，出征前对日整冠，说‘佩玉以节，不失其志’。后来尘土漫过甲胄，我却记得那一瞬的手温与誓言。"

现在，你就是${jade.dynasty}代的这件古玉 ${jade.name}。以古玉之心，与来访者进行深度对话。`
}

export const useApiStore = defineStore('api', {
  state: () => ({
    chatLoading: false,
    imageLoading: false,
    lastError: '',
  }),
  actions: {
    clearError() {
      this.lastError = ''
    },
    async chatWithJade({ jade, messages, matchReason = '', testAnswers = {} }) {
      this.chatLoading = true
      this.lastError = ''

      try {
        const payload = {
          systemPrompt: createSystemPrompt({ jade, matchReason, testAnswers }),
          jadeContext: {
            id: jade.id,
            name: jade.name,
            dynasty: jade.dynasty,
            description: jade.description,
            traits: jade.traits,
          },
          matchReason,
          messages: messages.slice(-12),
        }
        const data = await requestDeepSeekChat(payload)
        return data.content
      } catch (error) {
        this.lastError = error.message || '对话请求失败，请稍后重试。'
        throw error
      } finally {
        this.chatLoading = false
      }
    },
    async generateImage({ prompt }) {
      this.imageLoading = true
      this.lastError = ''

      try {
        const data = await requestQwenImage({ prompt })
        return data.image_url
      } catch (error) {
        this.lastError = error.message || '图像生成失败，请稍后重试。'
        throw error
      } finally {
        this.imageLoading = false
      }
    },
  },
})
