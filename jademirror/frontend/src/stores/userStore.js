import { defineStore } from 'pinia'
import { createZeroVector } from '@/data/questions'

const WORK_STORAGE_KEY = 'jademirror-works-v1'

function readWorks() {
  try {
    const raw = localStorage.getItem(WORK_STORAGE_KEY)
    return raw ? JSON.parse(raw) : []
  } catch {
    return []
  }
}

function createWorkId() {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID()
  }
  return `work-${Date.now()}-${Math.random().toString(16).slice(2)}`
}

export const useUserStore = defineStore('user', {
  state: () => ({
    testMode: '',
    testAnswers: {},
    userVector: createZeroVector(),
    matchedJade: null,
    matchProfile: null,
    matchReason: '',
    matchScore: 0,
    mbtiType: '',
    archetype: null,
    dimensionScores: null,
    shadowJade: null,
    shadowProfile: null,
    flowchartPath: [],
    currentEmotion: 'neutral',
    generatedImageDataUrl: '',
    generatedImageOriginalUrl: '',
    generatedModelUrl: '',
    generatedMultiViews: [],
    lastPrompt: '',
    works: readWorks(),
  }),
  getters: {
    hasRequiredAnswers: (state) => {
      return Object.keys(state.testAnswers).length > 0
    },
  },
  actions: {
    setTestMode(mode) {
      this.testMode = mode
    },
    setAnswer(questionId, value) {
      this.testAnswers[questionId] = value
    },
    setAllAnswers(payload) {
      this.testAnswers = { ...payload }
    },
    setUserVector(vector) {
      this.userVector = { ...vector }
    },
    setMatchResult({
      jade,
      profile,
      reason,
      score,
      mbtiType,
      archetype,
      dimensionScores,
      shadowJade,
      shadowProfile,
      flowchartPath,
    }) {
      this.matchedJade = jade
      this.matchProfile = profile
      this.matchReason = reason
      this.matchScore = score
      this.mbtiType = mbtiType
      this.archetype = archetype
      this.dimensionScores = dimensionScores
      this.shadowJade = shadowJade
      this.shadowProfile = shadowProfile
      this.flowchartPath = flowchartPath || []
    },
    setEmotion(emotion) {
      this.currentEmotion = emotion || 'neutral'
    },
    setGeneratedResult({ imageDataUrl, prompt, modelUrl, originalUrl }) {
      this.generatedImageDataUrl = imageDataUrl || ''
      this.lastPrompt = prompt || ''
      if (modelUrl !== undefined) this.generatedModelUrl = modelUrl
      if (originalUrl !== undefined) this.generatedImageOriginalUrl = originalUrl
    },
    setGeneratedModelUrl(url) {
      this.generatedModelUrl = url || ''
    },
    setMultiViews(views) {
      this.generatedMultiViews = views || []
    },
    clearGeneratedResult() {
      this.generatedImageDataUrl = ''
      this.generatedImageOriginalUrl = ''
      this.generatedModelUrl = ''
      this.generatedMultiViews = []
      this.lastPrompt = ''
    },
    persistWorks() {
      localStorage.setItem(WORK_STORAGE_KEY, JSON.stringify(this.works))
    },
    saveCurrentWork() {
      if (!this.generatedImageDataUrl || !this.matchedJade) {
        return null
      }

      const newWork = {
        id: createWorkId(),
        imageDataURL: this.generatedImageDataUrl,
        jadeName: this.matchedJade.name,
        jadeDynasty: this.matchedJade.dynasty,
        jadeDescription: this.matchedJade.description || '',
        jadePersonality: this.matchedJade.personality || '',
        jadeTraits: this.matchedJade.traits || {},
        prompt: this.lastPrompt,
        date: new Date().toISOString(),
        emotion: this.currentEmotion,
        audioParams: this.matchedJade.audioParams,
      }

      this.works = [newWork, ...this.works]
      this.persistWorks()
      return newWork
    },
    removeWork(workId) {
      this.works = this.works.filter((work) => work.id !== workId)
      this.persistWorks()
    },
    resetTest() {
      this.testMode = ''
      this.testAnswers = {}
      this.userVector = createZeroVector()
      this.matchedJade = null
      this.matchProfile = null
      this.matchReason = ''
      this.matchScore = 0
      this.mbtiType = ''
      this.archetype = null
      this.dimensionScores = null
      this.shadowJade = null
      this.shadowProfile = null
      this.flowchartPath = []
      this.currentEmotion = 'neutral'
      this.clearGeneratedResult()
    },
  },
})
