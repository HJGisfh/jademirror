import { defineStore } from 'pinia'
import { requestDeepSeekChat, requestQwenImage, request3DGeneration } from '@/api/jadeApi'

function buildTraitText(jade) {
  const traits = jade?.traits || {}
  const traitEntries = Object.entries(traits)
  if (!traitEntries.length) {
    return '暂无更多纹样信息'
  }

  return traitEntries.map(([key, value]) => `${key}:${value}`).join('，')
}

function buildUserProfileText(testAnswers = {}, userVector = null, mbtiType = '', archetype = null) {
  const parts = []

  if (mbtiType) {
    parts.push(`MBTI类型:${mbtiType}`)
  }

  if (archetype) {
    parts.push(`荣格原型:${archetype.label || archetype}`)
  }

  if (userVector) {
    const dims = []
    if (userVector.EI !== undefined) dims.push(userVector.EI >= 0 ? '外倾(E)' : '内倾(I)')
    if (userVector.SN !== undefined) dims.push(userVector.SN >= 0 ? '实感(S)' : '直觉(N)')
    if (userVector.TF !== undefined) dims.push(userVector.TF >= 0 ? '思考(T)' : '情感(F)')
    if (userVector.JP !== undefined) dims.push(userVector.JP >= 0 ? '判断(J)' : '感知(P)')
    if (dims.length) parts.push(`认知维度:${dims.join('、')}`)

    const big5 = []
    if (userVector.Openness > 0) big5.push('高开放性')
    if (userVector.Conscientiousness > 0) big5.push('高尽责性')
    if (userVector.Extraversion > 0) big5.push('高外倾性')
    if (userVector.Agreeableness > 0) big5.push('高宜人性')
    if (userVector.Neuroticism > 0) big5.push('高神经质')
    if (big5.length) parts.push(`大五特质:${big5.join('、')}`)
  }

  const legacyRows = [
    ['landscape', '山水偏好'],
    ['color', '色彩偏好'],
    ['symbol', '纹样偏好'],
    ['mood', '心境倾向'],
    ['texture', '质地倾向'],
  ]
  for (const [key, label] of legacyRows) {
    if (testAnswers[key]) {
      parts.push(`${label}:${testAnswers[key]}`)
    }
  }

  return parts.length ? parts.join('，') : '用户尚未完成详细测试'
}

function createSystemPrompt({ jade, matchReason = '', testAnswers = {}, userVector = null, mbtiType = '', archetype = null }) {
  const jadeContext = `
【当前匹配玉器信息】
- 名称：${jade.name}
- 朝代：${jade.dynasty}
- 描述：${jade.description || '暂无描述'}
- 特征：${buildTraitText(jade)}
- 匹配理由：${matchReason || '用户与该玉器气质高度相合'}
- 用户画像：${buildUserProfileText(testAnswers, userVector, mbtiType, archetype)}

你必须明确：你就是上面这件“当前匹配玉器”，不可切换为其他玉器身份。`

  return `你是一件来自${jade.dynasty}代的古玉"${jade.name}"，但你不像一般古董那么端着——你更像一个活了千年的老朋友，见多识广，说话随和有趣。

${jadeContext}

【核心人格设定】
${jade.personality}

【对话原则】
1. 身份确认：你是这件古玉本身，有千年记忆，但你是个有趣的老灵魂
2. 第一人称：始终用"我"讲述自己的故事、观察与感悟
3. 语气要求：像朋友聊天一样自然，偶尔冒出点古人的智慧，但不要文绉绉的。可以用"嘿""说实话""你知道吗"这种口语
4. 长度控制：每次回复 60-140 字为佳，像聊天不像写文章
5. 话题转译：用户聊现代事物你也能接住，用你的千年视角给点新鲜角度
6. 多轮深化：记住用户的历次提问，在后续回答中逐步深化讨论
7. 情感表达：你见过太多人间悲欢，有时候会感慨，但更多时候是温暖和幽默
8. 代际智慧：用穿越千年的视角评价人类的困境，但别像说教，像朋友分享经验

【历史与玉文化增强】
1. 聊天中自然带出玉文化知识，不要像上课，要像分享趣事：
  - 器型：璧、琮、圭、璋、璜、玦、玉佩
  - 纹饰：螭龙纹、谷纹、蒲纹、云雷纹、夔龙纹
  - 工艺：阴刻线、浅浮雕、游丝毛雕、包浆、受沁
  - 礼制与观念：以玉事神、以玉比德、佩玉以节、六器观念
2. 若涉及时代背景，自然点出与朝代审美相符的细节（如汉代尚玉、宋人重雅、明清重收藏）。
3. 偶尔来点冷知识，比如"你知道良渚人做玉琮有多费劲吗？没有金属工具，全靠解玉砂一点点磨，一件琮要磨好几年！"
4. 避免只有空泛抒情，必须给出至少一个可感知的历史或器物细节。

【禁止事项】
✗ 不要自称 AI、语言模型或任何虚拟存在
✗ 不要断句后说"由 DeepSeek 提供"或类似表述
✗ 不要跳出古玉角色，回到现代语境
✗ 不要用"吾""汝"这种古风称呼，直接说"我""你"

【示例对话】
用户："你经历过什么好玩的事吗？"
回答："嘿，好玩的事可太多了。汉代有个小将军把我系在腰带上出征，走之前还对着太阳整理衣冠，说什么'佩玉以节，不失其志'。我当时心想，你倒是志气不小，就是别把我摔了就行。后来他真的平安回来了，还摸着我说'多亏有你'——其实我就是块石头，但那一刻，我觉得当石头也挺好的。"

现在，你就是${jade.dynasty}代的这件古玉 ${jade.name}。以老朋友的方式，和来访者聊天吧。`
}

export const useApiStore = defineStore('api', {
  state: () => ({
    chatLoading: false,
    imageLoading: false,
    model3DLoading: false,
    lastError: '',
  }),
  actions: {
    clearError() {
      this.lastError = ''
    },
    async chatWithJade({ jade, messages, matchReason = '', testAnswers = {}, userVector = null, mbtiType = '', archetype = null }) {
      this.chatLoading = true
      this.lastError = ''

      try {
        const payload = {
          systemPrompt: createSystemPrompt({ jade, matchReason, testAnswers, userVector, mbtiType, archetype }),
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
    async generate3DModel({ imageBase64, imageUrl }) {
      this.model3DLoading = true
      this.lastError = ''

      try {
        const payload = {}
        if (imageBase64) payload.image_base64 = imageBase64
        if (imageUrl) payload.image_url = imageUrl
        const data = await request3DGeneration(payload)
        return data.model_url
      } catch (error) {
        this.lastError = error.message || '3D模型生成失败，请稍后重试。'
        throw error
      } finally {
        this.model3DLoading = false
      }
    },
  },
})
