import { defineStore } from 'pinia'
import { createZeroVector } from '@/data/questions'
import http from '@/api/http'

const USER_STATE_STORAGE_KEY = 'jademirror-user-state-v1'
const AUTH_USER_KEY = 'jademirror-auth-user-v1'
const AUTH_TOKEN_KEY = 'jademirror-auth-token-v1'
const WORK_STORAGE_PREFIX = 'jademirror-works-v2'

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

function readAuthUserId() {
  try {
    const raw = localStorage.getItem(AUTH_USER_KEY)
    if (!raw) return ''
    const parsed = JSON.parse(raw)
    return parsed && parsed.id ? String(parsed.id) : ''
  } catch {
    return ''
  }
}

function worksStorageKey(userId = '') {
  const key = userId || readAuthUserId() || 'guest'
  return `${WORK_STORAGE_PREFIX}:${key}`
}

function readAuthToken() {
  try {
    return localStorage.getItem(AUTH_TOKEN_KEY) || ''
  } catch {
    return ''
  }
}

function readWorks(userId = '') {
  try {
    const raw = localStorage.getItem(worksStorageKey(userId))
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
    persistWorks(userId = '') {
      localStorage.setItem(worksStorageKey(userId), JSON.stringify(this.works))
    },
    clearWorksCache(userId = '') {
      try {
        localStorage.removeItem(worksStorageKey(userId))
      } catch {
        // ignore storage failures
      }
    },
    async fetchWorks(options = {}) {
      const preferRemote = options.preferRemote ?? Boolean(readAuthToken())
      try {
        const { data } = await http.get('/works')
        this.works = Array.isArray(data)
          ? data.map((w) => ({
              ...w,
              imageDataURL: w.imageUrl || w.imageDataURL || '',
            }))
          : []
        this.persistWorks()
        return this.works
      } catch (error) {
        if (preferRemote) {
          throw error
        }
        this.works = readWorks()
        return this.works
      }
    },
    async saveCurrentWork(options = {}) {
      if (!this.generatedImageDataUrl || !this.matchedJade) {
        return null
      }

      const requireRemote = options.requireRemote ?? Boolean(readAuthToken())

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

      if (requireRemote) {
        const { data } = await http.post('/works', newWork)
        if (data?.imageUrl) {
          newWork.imageDataURL = data.imageUrl
        }
      } else {
        try {
          await http.post('/works', newWork)
        } catch {
          // ignore if not logged in
        }
      }

      this.works = [newWork, ...this.works]
      this.persistWorks()
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
