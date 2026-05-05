import { defineStore } from 'pinia'
import {
  clearAssistantMemories,
  deleteAssistantMemory,
  exportAssistantMemories,
  fetchAssistantMemories,
  pinAssistantMemory,
  requestAssistantProactive,
  requestAssistantTurn,
} from '@/api/jadeApi'
import { fetchJadeLibrary } from '@/api/jadeLibrary'
import { deepTestQuestions, quickTestQuestions } from '@/data/questions'
import { useApiStore } from '@/stores/apiStore'
import { useUserStore } from '@/stores/userStore'
import { useVoiceStore } from '@/stores/voiceStore'
import { createFallbackJadeDataURL, urlToDataURL } from '@/utils/image'
import { computeUserVector, matchJadeByVector, deriveFlowchartPath } from '@/utils/matching'
import { buildImagePrompt } from '@/utils/prompt'

const IDLE_NUDGE_MS = 1000 * 90

function normalizeStage(routeName) {
  const map = {
    Home: 'home',
    Test: 'test',
    Result: 'result',
    Chat: 'chat',
    Generate: 'generate',
    Gallery: 'gallery',
    Login: 'login',
  }
  return map[routeName] || 'home'
}

function optionHit(option, text) {
  const keywordList = [option.value, option.label, option.description]
    .map((item) => String(item || '').trim().toLowerCase())
    .filter(Boolean)
  const source = String(text || '').trim().toLowerCase()
  return keywordList.some((key) => key && source.includes(key))
}

function pickOption(question, text) {
  return question.options.find((option) => optionHit(option, text)) || null
}

function buildQuestionGuide(question, index) {
  const optionsText = question.options.map((option) => option.label).join('、')
  return `第${index + 1}题：${question.title}。你可以回答：${optionsText}。`
}

function clampWorkIndex(rawIndex, total) {
  const n = Number(rawIndex)
  if (!Number.isFinite(n) || total <= 0) {
    return 0
  }
  const idx = Math.max(1, Math.min(total, Math.floor(n)))
  return idx - 1
}

export const useAssistantStore = defineStore('assistant', {
  state: () => ({
    ready: false,
    busy: false,
    open: true,
    autoSpeak: true,
    autoGuide: true,
    privacyMode: false,
    voicePersona: 'default',
    stage: 'home',
    lastError: '',
    messages: [],
    idleEnabled: true,
    idleTimerId: 0,
    idleNudgeCount: 0,
    emotionalTone: 'calm',
    lastMemoryDigest: '',
    memories: [],
    memoryFilter: 'all',
    memoryExportText: '',
    memoryLoading: false,
    galleryTourWorks: [],
    galleryTourIndex: -1,
    galleryTourAuto: false,
    galleryTourTimerId: 0,
    guidedTestActive: false,
    guidedQuestionIndex: 0,
    guidedTestMode: 'deep',
    autoListen: false,
    silenceThreshold: 1500,
  }),
  getters: {
    latestReply: (state) => {
      for (let i = state.messages.length - 1; i >= 0; i -= 1) {
        if (state.messages[i].role === 'assistant') {
          return state.messages[i]
        }
      }
      return null
    },
    currentQuestion: (state) => {
      if (!state.guidedTestActive) return null
      const questions = state.guidedTestMode === 'quick' ? quickTestQuestions : deepTestQuestions
      return questions[state.guidedQuestionIndex] || null
    },
    filteredMemories: (state) => {
      if (state.memoryFilter === 'all') {
        return state.memories
      }
      return state.memories.filter((item) => item.memory_type === state.memoryFilter)
    },
    memoryTypeCounts: (state) => {
      const counts = { all: state.memories.length, preference: 0, emotion: 0 }
      for (const item of state.memories) {
        if (item.memory_type === 'preference') {
          counts.preference += 1
        } else if (item.memory_type === 'emotion') {
          counts.emotion += 1
        }
      }
      return counts
    },
  },
  actions: {
    setStage(routeName) {
      this.stage = normalizeStage(routeName)
      this.touchActivity()
    },
    buildContext() {
      const userStore = useUserStore()
      const workPreview = userStore.works.slice(0, 5).map((item, index) => ({
        index: index + 1,
        jadeName: item.jadeName,
        jadeDynasty: item.jadeDynasty,
        emotion: item.emotion,
      }))
      return {
        hasMatchedJade: Boolean(userStore.matchedJade),
        hasGeneratedImage: Boolean(userStore.generatedImageDataUrl),
        worksCount: userStore.works.length,
        workPreview,
        matchedJadeName: userStore.matchedJade?.name || '',
        currentEmotion: userStore.currentEmotion,
        idleNudgeCount: this.idleNudgeCount,
        privacy_mode: this.privacyMode,
        voice_persona: this.voicePersona,
      }
    },
    setPrivacyMode(enabled) {
      this.privacyMode = Boolean(enabled)
      if (this.privacyMode) {
        this.lastMemoryDigest = ''
        this.memories = []
      } else {
        this.loadMemories()
      }
    },
    setVoicePersona(persona) {
      const allow = new Set(['default', 'warm', 'bright', 'deep'])
      this.voicePersona = allow.has(persona) ? persona : 'default'
      const voiceStore = useVoiceStore()
      voiceStore.setPersona(this.voicePersona)
    },
    clearIdleTimer() {
      if (this.idleTimerId) {
        window.clearTimeout(this.idleTimerId)
        this.idleTimerId = 0
      }
    },
    touchActivity(router) {
      if (typeof window === 'undefined') {
        return
      }
      this.clearIdleTimer()
      if (!this.idleEnabled || this.busy || this.stage === 'login' || this.guidedTestActive) {
        return
      }
      this.idleTimerId = window.setTimeout(() => {
        this.triggerIdleNudge(router)
      }, IDLE_NUDGE_MS)
    },
    async triggerIdleNudge(router) {
      if (!this.idleEnabled || this.busy || this.guidedTestActive || this.stage === 'login') {
        this.touchActivity(router)
        return
      }
      this.busy = true
      this.lastError = ''
      try {
        const data = await requestAssistantProactive({
          stage: this.stage,
          context: this.buildContext(),
        })
        const reply = data.reply || '我在这里，想继续哪一步，我都陪你。'
        this.applyEmotionTone(data.emotion)
        this.appendMessage('assistant', reply)
        this.speak(reply)
        this.lastMemoryDigest = data.memory_digest || this.lastMemoryDigest
        this.idleNudgeCount += 1
        await this.executeAssistantAction(data.next_action, data.action_payload || {}, router)
        if (this.autoGuide && data.suggested_route && router) {
          router.push(data.suggested_route)
        }
      } catch (error) {
        this.lastError = error.message || '主动关怀触发失败。'
      } finally {
        this.busy = false
        this.touchActivity(router)
      }
    },
    appendMessage(role, content) {
      this.messages.push({
        id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
        role,
        content: String(content || ''),
      })
      if (this.messages.length > 50) {
        this.messages = this.messages.slice(-50)
      }
      this.touchActivity()
    },
    speak(text) {
      if (!this.autoSpeak) {
        return
      }
      const voiceStore = useVoiceStore()
      voiceStore.init()
      voiceStore.setPersona(this.voicePersona)
      if (voiceStore.synthesisSupported) {
        voiceStore.speakWithMood(text, this.emotionalTone)
      }
    },
    applyEmotionTone(emotion) {
      const normalized = String(emotion || '').trim().toLowerCase()
      if (!normalized) {
        return
      }
      const map = {
        calm: 'calm',
        neutral: 'calm',
        anxious: 'comforting',
        sad: 'comforting',
        worried: 'comforting',
        happy: 'cheerful',
        excited: 'energetic',
        curious: 'cheerful',
        reflective: 'contemplative',
      }
      this.emotionalTone = map[normalized] || 'calm'
    },
    welcomeIfNeeded() {
      if (this.ready) {
        return
      }
      const text =
        '我是玉灵童子。你可以直接和我说话，我会主动带你完成照心测试、古玉匹配、对话、生玉与藏室管理。'
      this.appendMessage('assistant', text)
      this.speak(text)
      this.ready = true
      this.loadMemories()
      this.touchActivity()
    },
    async listenAndHandle(router) {
      const voiceStore = useVoiceStore()
      voiceStore.init()
      this.lastError = ''
      const transcript = await voiceStore.recognizeOnce()
      if (!transcript) {
        if (voiceStore.lastError) {
          this.lastError = voiceStore.lastError
        }
        this.touchActivity(router)
        return
      }
      await this.handleUserText(transcript, router)
    },
    async handleUserText(text, router) {
      const input = String(text || '').trim()
      if (!input) {
        return
      }
      this.touchActivity(router)
      this.appendMessage('user', input)

      if (this.guidedTestActive) {
        await this.handleGuidedAnswer(input, router)
        return
      }

      await this.sendTurn(input, router)
    },
    async generateJadeByVoice(router) {
      const userStore = useUserStore()
      const apiStore = useApiStore()
      const jade = userStore.matchedJade
      if (!jade) {
        this.appendMessage('assistant', '我还没为你匹配到古玉，我们先完成照心测试。')
        this.speak('我还没为你匹配到古玉，我们先完成照心测试。')
        if (this.autoGuide && router) {
          router.push('/test')
        }
        return false
      }

      const prompt = buildImagePrompt({
        answers: userStore.testAnswers,
        jade,
        emotion: userStore.currentEmotion,
      })

      this.appendMessage('assistant', '我正在为你凝练专属玉意象，请稍候。')
      this.speak('我正在为你凝练专属玉意象，请稍候。')
      try {
        const imageUrl = await apiStore.generateImage({ prompt })
        let dataUrl = imageUrl
        try {
          dataUrl = await urlToDataURL(imageUrl)
        } catch {
          dataUrl = imageUrl
        }
        userStore.setGeneratedResult({ imageDataUrl: dataUrl, prompt, originalUrl: imageUrl })
        this.appendMessage('assistant', '专属玉已经生成完成。我可以继续帮你保存到藏室。')
        this.speak('专属玉已经生成完成。我可以继续帮你保存到藏室。')
        if (this.autoGuide && router) {
          router.push('/generate')
        }
        return true
      } catch {
        const fallback = createFallbackJadeDataURL(jade.name)
        userStore.setGeneratedResult({ imageDataUrl: fallback, prompt, originalUrl: '' })
        this.appendMessage('assistant', '网络有点拥挤，我先为你保留一版临时玉图，你可稍后再次生成。')
        this.speak('网络有点拥挤，我先为你保留一版临时玉图，你可稍后再次生成。')
        if (this.autoGuide && router) {
          router.push('/generate')
        }
        return false
      }
    },
    saveWorkByVoice(router) {
      const userStore = useUserStore()
      const work = userStore.saveCurrentWork()
      if (!work) {
        this.appendMessage('assistant', '还没有可保存的专属玉。你可以先让我为你生成。')
        this.speak('还没有可保存的专属玉。你可以先让我为你生成。')
        return false
      }
      this.appendMessage('assistant', `已帮你保存到藏室：${work.jadeDynasty}代意象的${work.jadeName}。`)
      this.speak(`已帮你保存到藏室：${work.jadeDynasty}代意象的${work.jadeName}。`)
      if (this.autoGuide && router) {
        router.push('/gallery')
      }
      return true
    },
    removeWorkByVoice(index, router) {
      const userStore = useUserStore()
      if (!userStore.works.length) {
        this.appendMessage('assistant', '藏室目前没有藏品可删除。')
        this.speak('藏室目前没有藏品可删除。')
        return false
      }
      const targetIndex = clampWorkIndex(index, userStore.works.length)
      const target = userStore.works[targetIndex]
      userStore.removeWork(target.id)
      this.appendMessage('assistant', `已删除第${targetIndex + 1}件作品：${target.jadeName}。`)
      this.speak(`已删除第${targetIndex + 1}件作品：${target.jadeName}。`)
      if (this.autoGuide && router) {
        router.push('/gallery')
      }
      return true
    },
    openWorkByVoice(index, router) {
      const userStore = useUserStore()
      if (!userStore.works.length) {
        this.appendMessage('assistant', '藏室还没有作品，先保存一件吧。')
        this.speak('藏室还没有作品，先保存一件吧。')
        return false
      }
      const targetIndex = clampWorkIndex(index, userStore.works.length)
      const work = userStore.works[targetIndex]
      const text = this.composeWorkNarration(work, targetIndex, userStore.works.length)
      this.appendMessage('assistant', text)
      this.speak(text)
      if (this.autoGuide && router) {
        router.push('/gallery')
      }
      return true
    },
    async executeAssistantAction(nextAction, actionPayload = {}, router) {
      const action = String(nextAction || '').trim().toLowerCase()
      if (!action) {
        return
      }

      if (action === 'generate_jade') {
        await this.generateJadeByVoice(router)
        return
      }
      if (action === 'save_work') {
        this.saveWorkByVoice(router)
        return
      }
      if (action === 'delete_work') {
        this.removeWorkByVoice(actionPayload.index, router)
        return
      }
      if (action === 'open_work') {
        this.openWorkByVoice(actionPayload.index, router)
        return
      }
      if (action === 'start_gallery_tour') {
        const userStore = useUserStore()
        this.guideGalleryTour(userStore.works)
        if (this.autoGuide && router) {
          router.push('/gallery')
        }
        return
      }
      if (action === 'next_gallery_item') {
        this.nextGalleryWork()
        return
      }
      if (action === 'prev_gallery_item') {
        this.prevGalleryWork()
        return
      }
      if (action === 'stop_gallery_tour') {
        this.stopGalleryTour()
      }
    },
    async sendTurn(text, router) {
      this.busy = true
      this.lastError = ''
      try {
        const data = await requestAssistantTurn({
          text,
          stage: this.stage,
          context: this.buildContext(),
        })

        const reply = data.reply || '我在，继续和我说说。'
        this.applyEmotionTone(data.emotion)
        this.appendMessage('assistant', reply)
        this.speak(reply)
        this.lastMemoryDigest = data.memory_digest || this.lastMemoryDigest
        await this.executeAssistantAction(data.next_action, data.action_payload || {}, router)

        if (data.next_action === 'start_test' || data.next_action === 'continue_test') {
          this.startGuidedTest()
          if (this.autoGuide) {
            router.push('/test')
          }
          return
        }

        const route = data.suggested_route || ''
        if (this.autoGuide && route) {
          router.push(route)
        }
      } catch (error) {
        this.lastError = error.message || '玉灵童子暂时无法回应。'
        const fallback = '我刚刚有些分神了。你可以再说一次，我会继续带着你前行。'
        this.appendMessage('assistant', fallback)
        this.speak(fallback)
      } finally {
        this.busy = false
        this.touchActivity(router)
      }
    },
    startGuidedTest(mode = 'deep') {
      this.guidedTestActive = true
      this.guidedQuestionIndex = 0
      this.guidedTestMode = mode
      const questions = mode === 'quick' ? quickTestQuestions : deepTestQuestions
      const question = questions[0]
      const guide = buildQuestionGuide(question, 0)
      this.appendMessage('assistant', `我们开始照心测试。${guide}`)
      this.speak(`我们开始照心测试。${guide}`)
    },
    async handleGuidedAnswer(answerText, router) {
      const userStore = useUserStore()
      const questions = this.guidedTestMode === 'quick' ? quickTestQuestions : deepTestQuestions
      const question = questions[this.guidedQuestionIndex]
      if (!question) {
        this.guidedTestActive = false
        return
      }

      const option = pickOption(question, answerText)
      if (!option) {
        const retry = `我还没听懂你的选择。${buildQuestionGuide(question, this.guidedQuestionIndex)}`
        this.appendMessage('assistant', retry)
        this.speak(retry)
        return
      }

      userStore.setAnswer(question.id, option.value)
      const confirmed = `收到，这一题你选择了${option.label}。`
      this.appendMessage('assistant', confirmed)
      this.speak(confirmed)

      this.guidedQuestionIndex += 1
      if (this.guidedQuestionIndex < questions.length) {
        const nextQuestion = questions[this.guidedQuestionIndex]
        const guide = buildQuestionGuide(nextQuestion, this.guidedQuestionIndex)
        this.appendMessage('assistant', guide)
        this.speak(guide)
        return
      }

      await this.finishGuidedTest(router)
    },
    async finishGuidedTest(router) {
      this.guidedTestActive = false
      const userStore = useUserStore()

      try {
        const jadeLib = await fetchJadeLibrary()
        const questions = this.guidedTestMode === 'quick' ? quickTestQuestions : deepTestQuestions
        const userVector = computeUserVector(questions, userStore.testAnswers)
        userStore.setUserVector(userVector)

        const result = matchJadeByVector({ jades: jadeLib, userVector })
        const flowPath = deriveFlowchartPath(questions, userStore.testAnswers, userVector, result.profile)

        userStore.setMatchResult({
          jade: result.jade,
          profile: result.profile,
          reason: result.profile.verdict,
          score: result.score,
          mbtiType: result.mbtiType,
          archetype: result.archetype,
          dimensionScores: result.dimensionScores,
          shadowJade: result.shadowJade,
          shadowProfile: result.shadowProfile,
          flowchartPath: flowPath,
        })
        userStore.clearGeneratedResult()

        const msg = `照心测试完成！你与${result.jade.dynasty}代${result.jade.name}最为契合，你的MBTI类型是${result.mbtiType}，原型是${result.archetype.label}。`
        this.appendMessage('assistant', msg)
        this.speak(msg)

        if (router) router.push('/result')
      } catch (err) {
        const msg = `匹配过程中遇到了一些问题：${err.message}。你可以手动前往测试页面完成匹配。`
        this.appendMessage('assistant', msg)
        this.speak(msg)
      }
    },
    async loadMemories() {
      if (this.privacyMode) {
        this.memories = []
        this.lastMemoryDigest = ''
        this.memoryLoading = false
        return
      }
      this.memoryLoading = true
      this.lastError = ''
      try {
        const data = await fetchAssistantMemories()
        this.memories = Array.isArray(data.memories) ? data.memories : []
        this.lastMemoryDigest = data.digest || this.lastMemoryDigest
      } catch (error) {
        this.lastError = error.message || '记忆加载失败。'
      } finally {
        this.memoryLoading = false
      }
    },
    setMemoryFilter(type) {
      const allow = new Set(['all', 'preference', 'emotion'])
      this.memoryFilter = allow.has(type) ? type : 'all'
    },
    async setMemoryPinned(memoryId, pinned) {
      if (this.privacyMode) {
        return
      }
      this.lastError = ''
      try {
        const data = await pinAssistantMemory(memoryId, pinned)
        this.memories = Array.isArray(data.memories) ? data.memories : this.memories
        this.lastMemoryDigest = data.digest || this.lastMemoryDigest
      } catch (error) {
        this.lastError = error.message || '记忆置顶操作失败。'
      }
    },
    async removeMemory(memoryId) {
      if (this.privacyMode) {
        return
      }
      this.lastError = ''
      try {
        const data = await deleteAssistantMemory(memoryId)
        this.memories = Array.isArray(data.memories) ? data.memories : this.memories
        this.lastMemoryDigest = data.digest || this.lastMemoryDigest
      } catch (error) {
        this.lastError = error.message || '记忆删除失败。'
      }
    },
    async clearAllMemories() {
      if (this.privacyMode) {
        this.memories = []
        this.lastMemoryDigest = ''
        this.memoryExportText = ''
        return
      }
      this.lastError = ''
      try {
        const data = await clearAssistantMemories()
        this.memories = Array.isArray(data.memories) ? data.memories : []
        this.lastMemoryDigest = data.digest || ''
        this.memoryExportText = ''
      } catch (error) {
        this.lastError = error.message || '记忆清空失败。'
      }
    },
    async exportMemories() {
      if (this.privacyMode) {
        this.memoryExportText = ''
        return
      }
      this.lastError = ''
      try {
        const data = await exportAssistantMemories()
        this.memoryExportText = JSON.stringify(data, null, 2)
      } catch (error) {
        this.lastError = error.message || '记忆导出失败。'
      }
    },
    composeWorkNarration(work, index, total) {
      const order = `第${index + 1}件，共${total}件。`
      const title = `${work.jadeDynasty}代意象，${work.jadeName}。`
      const emotion = `情绪基调：${work.emotion || '平和'}。`
      const prompt = work.prompt
        ? `生成意图：${String(work.prompt).slice(0, 80)}。`
        : '它承载了你当时的心境与偏好。'
      return `${order}${title}${emotion}${prompt}`
    },
    speakCurrentGalleryWork() {
      if (!this.galleryTourWorks.length || this.galleryTourIndex < 0) {
        return
      }
      const current = this.galleryTourWorks[this.galleryTourIndex]
      const text = this.composeWorkNarration(current, this.galleryTourIndex, this.galleryTourWorks.length)
      this.appendMessage('assistant', text)
      this.speak(text)
    },
    nextGalleryWork() {
      if (!this.galleryTourWorks.length) {
        return
      }
      this.galleryTourIndex = (this.galleryTourIndex + 1) % this.galleryTourWorks.length
      this.speakCurrentGalleryWork()
    },
    prevGalleryWork() {
      if (!this.galleryTourWorks.length) {
        return
      }
      this.galleryTourIndex = (this.galleryTourIndex - 1 + this.galleryTourWorks.length) % this.galleryTourWorks.length
      this.speakCurrentGalleryWork()
    },
    stopGalleryTour() {
      this.galleryTourAuto = false
      if (this.galleryTourTimerId) {
        window.clearInterval(this.galleryTourTimerId)
        this.galleryTourTimerId = 0
      }
      this.galleryTourWorks = []
      this.galleryTourIndex = -1
      const voiceStore = useVoiceStore()
      voiceStore.stopSpeaking()
    },
    startAutoGalleryTour() {
      if (!this.galleryTourWorks.length) {
        return
      }
      this.galleryTourAuto = true
      if (this.galleryTourTimerId) {
        window.clearInterval(this.galleryTourTimerId)
      }
      this.galleryTourTimerId = window.setInterval(() => {
        this.nextGalleryWork()
      }, 10000)
    },
    pauseAutoGalleryTour() {
      this.galleryTourAuto = false
      if (this.galleryTourTimerId) {
        window.clearInterval(this.galleryTourTimerId)
        this.galleryTourTimerId = 0
      }
    },
    guideGalleryTour(works = []) {
      if (!Array.isArray(works) || works.length === 0) {
        const emptyText = '你的藏室还没有藏品。等你生成第一件专属玉后，我会为你做语音导览。'
        this.appendMessage('assistant', emptyText)
        this.speak(emptyText)
        return
      }
      this.galleryTourWorks = [...works]
      this.galleryTourIndex = 0
      const open = `欢迎来到你的个人藏室。你目前收藏了${works.length}件玉作。现在我为你逐件讲解。`
      this.appendMessage('assistant', open)
      this.speak(open)
      this.speakCurrentGalleryWork()
      this.startAutoGalleryTour()
    },
    teardown() {
      this.clearIdleTimer()
      this.pauseAutoGalleryTour()
    },
  },
})
