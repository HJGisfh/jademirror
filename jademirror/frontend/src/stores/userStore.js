import { defineStore } from 'pinia'
import { createZeroVector } from '@/data/questions'
import http from '@/api/http'

const USER_STATE_STORAGE_KEY = 'jademirror-user-state-v1'
const WORK_STORAGE_KEY = 'jademirror-works-v1'

function createDefaultUserState() {
  return {
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
  }
}

function readUserState() {
  try {
    const raw = localStorage.getItem(USER_STATE_STORAGE_KEY)
    if (!raw) {
      return createDefaultUserState()
    }
    const parsed = JSON.parse(raw)
    return { ...createDefaultUserState(), ...parsed }
  } catch {
    return createDefaultUserState()
  }
}

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
    ...readUserState(),
    works: readWorks(),
  }),
  getters: {
    hasRequiredAnswers: (state) => {
      return Object.keys(state.testAnswers).length > 0
    },
  },
  actions: {
    persistUserState() {
      const {
        works,
        ...stateToPersist
      } = this.$state
      localStorage.setItem(USER_STATE_STORAGE_KEY, JSON.stringify(stateToPersist))
    },
    setTestMode(mode) {
      this.testMode = mode
      this.persistUserState()
    },
    setAnswer(questionId, value) {
      this.testAnswers[questionId] = value
      this.persistUserState()
    },
    setAllAnswers(payload) {
      this.testAnswers = { ...payload }
      this.persistUserState()
    },
    setUserVector(vector) {
      this.userVector = { ...vector }
      this.persistUserState()
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
      this.persistUserState()
    },
    setEmotion(emotion) {
      this.currentEmotion = emotion || 'neutral'
      this.persistUserState()
    },
    setGeneratedResult({ imageDataUrl, prompt, modelUrl, originalUrl }) {
      this.generatedImageDataUrl = imageDataUrl || ''
      this.lastPrompt = prompt || ''
      if (modelUrl !== undefined) this.generatedModelUrl = modelUrl
      if (originalUrl !== undefined) this.generatedImageOriginalUrl = originalUrl
      this.persistUserState()
    },
    setGeneratedModelUrl(url) {
      this.generatedModelUrl = url || ''
      this.persistUserState()
    },
    setMultiViews(views) {
      this.generatedMultiViews = views || []
      this.persistUserState()
    },
    clearGeneratedResult() {
      this.generatedImageDataUrl = ''
      this.generatedImageOriginalUrl = ''
      this.generatedModelUrl = ''
      this.generatedMultiViews = []
      this.lastPrompt = ''
      this.persistUserState()
    },
    persistWorks() {
      localStorage.setItem(WORK_STORAGE_KEY, JSON.stringify(this.works))
    },
    async fetchWorks() {
      try {
        const { data } = await http.get('/works')
        this.works = Array.isArray(data) ? data : []
      } catch {
        this.works = readWorks()
      }
    },
    async saveCurrentWork() {
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

      try {
        await http.post('/works', newWork)
      } catch {
        // server save failed, keep local copy
      }
      return newWork
    },
    async removeWork(workId) {
      this.works = this.works.filter((work) => work.id !== workId)
      this.persistWorks()

      try {
        await http.delete(`/works/${workId}`)
      } catch {
        // server delete failed, local copy already removed
      }
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
      this.persistUserState()
    },
  },
})
