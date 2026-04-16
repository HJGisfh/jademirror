import { defineStore } from 'pinia'

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
    testAnswers: {
      landscape: '',
      color: '',
      symbol: '',
      mood: '',
      texture: '',
    },
    matchedJade: null,
    matchReason: '',
    matchScore: 0,
    currentEmotion: 'neutral',
    generatedImageDataUrl: '',
    lastPrompt: '',
    works: readWorks(),
  }),
  getters: {
    hasRequiredAnswers: (state) => {
      return ['landscape', 'color', 'symbol'].every((key) => !!state.testAnswers[key])
    },
  },
  actions: {
    setAnswer(dimension, value) {
      this.testAnswers[dimension] = value
    },
    setAllAnswers(payload) {
      this.testAnswers = {
        ...this.testAnswers,
        ...payload,
      }
    },
    setMatchResult({ jade, reason, score }) {
      this.matchedJade = jade
      this.matchReason = reason
      this.matchScore = score
    },
    setEmotion(emotion) {
      this.currentEmotion = emotion || 'neutral'
    },
    setGeneratedResult({ imageDataUrl, prompt }) {
      this.generatedImageDataUrl = imageDataUrl || ''
      this.lastPrompt = prompt || ''
    },
    clearGeneratedResult() {
      this.generatedImageDataUrl = ''
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
      this.testAnswers = {
        landscape: '',
        color: '',
        symbol: '',
        mood: '',
        texture: '',
      }
      this.matchedJade = null
      this.matchReason = ''
      this.matchScore = 0
      this.currentEmotion = 'neutral'
      this.clearGeneratedResult()
    },
  },
})
