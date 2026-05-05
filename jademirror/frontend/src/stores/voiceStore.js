import { defineStore } from 'pinia'

const RECOGNITION_LANG = 'zh-CN'
const SPEECH_RATE = 0.96
const SPEECH_PITCH = 1
const MOOD_SPEECH_MAP = {
  calm: { rate: 0.9, pitch: 0.95 },
  comforting: { rate: 0.88, pitch: 0.92 },
  cheerful: { rate: 1.02, pitch: 1.08 },
  energetic: { rate: 1.05, pitch: 1.1 },
  contemplative: { rate: 0.86, pitch: 0.9 },
}
const PERSONA_SPEECH_MAP = {
  default: { rate: 1, pitch: 1 },
  warm: { rate: 0.96, pitch: 0.94 },
  bright: { rate: 1.03, pitch: 1.06 },
  deep: { rate: 0.9, pitch: 0.88 },
}
let holdSessionResolve = null
let holdSessionPromise = null

function readSupport() {
  if (typeof window === 'undefined') {
    return {
      recognitionSupported: false,
      synthesisSupported: false,
      RecognitionCtor: null,
    }
  }

  const RecognitionCtor = window.SpeechRecognition || window.webkitSpeechRecognition || null
  return {
    recognitionSupported: Boolean(RecognitionCtor),
    synthesisSupported: typeof window.speechSynthesis !== 'undefined',
    RecognitionCtor,
  }
}

function resolveSpeechProfile(mood) {
  const key = String(mood || '').trim().toLowerCase()
  if (!key) {
    return { rate: SPEECH_RATE, pitch: SPEECH_PITCH }
  }

  if (MOOD_SPEECH_MAP[key]) {
    return MOOD_SPEECH_MAP[key]
  }

  if (['anxious', 'sad', 'tired'].includes(key)) {
    return MOOD_SPEECH_MAP.comforting
  }

  if (['happy', 'curious', 'excited'].includes(key)) {
    return MOOD_SPEECH_MAP.cheerful
  }

  return { rate: SPEECH_RATE, pitch: SPEECH_PITCH }
}

export const useVoiceStore = defineStore('voice', {
  state: () => ({
    recognition: null,
    listening: false,
    recognizing: false,
    speaking: false,
    lastTranscript: '',
    lastError: '',
    recognitionSupported: false,
    synthesisSupported: false,
    initialized: false,
    holdListening: false,
    persona: 'default',
    autoListening: false,
    autoListenSilenceTimer: 0,
    autoListenAccumulated: '',
    vadSpeechDetected: false,
  }),
  actions: {
    init() {
      if (this.initialized) {
        return
      }

      const support = readSupport()
      this.recognitionSupported = support.recognitionSupported
      this.synthesisSupported = support.synthesisSupported

      if (support.RecognitionCtor) {
        this.recognition = new support.RecognitionCtor()
        this.recognition.lang = RECOGNITION_LANG
        this.recognition.interimResults = true
        this.recognition.maxAlternatives = 1
        this.recognition.continuous = true

        this.recognition.onstart = () => {
          this.listening = true
          this.recognizing = true
          this.lastError = ''
        }

        this.recognition.onend = () => {
          this.listening = false
          this.recognizing = false
          this.holdListening = false
          if (holdSessionResolve) {
            holdSessionResolve(this.lastTranscript)
            holdSessionResolve = null
            holdSessionPromise = null
          }
          if (this.autoListening) {
            this.restartAutoListen()
          }
        }

        this.recognition.onerror = (event) => {
          const errorCode = event?.error
          if (errorCode === 'no-speech' && this.autoListening) {
            this.restartAutoListen()
            return
          }
          this.lastError = this.mapRecognitionError(errorCode)
          this.listening = false
          this.recognizing = false
          this.holdListening = false
          if (holdSessionResolve) {
            holdSessionResolve('')
            holdSessionResolve = null
            holdSessionPromise = null
          }
          if (this.autoListening && errorCode !== 'not-allowed' && errorCode !== 'audio-capture') {
            this.restartAutoListen()
          }
        }

        this.recognition.onresult = (event) => {
          let finalTranscript = ''
          let interimTranscript = ''

          for (let i = event.resultIndex; i < event.results.length; i++) {
            const result = event.results[i]
            const text = result[0]?.transcript || ''
            if (result.isFinal) {
              finalTranscript += text
            } else {
              interimTranscript += text
            }
          }

          if (finalTranscript) {
            this.lastTranscript = finalTranscript.trim()
            this.autoListenAccumulated += finalTranscript
          }

          if (interimTranscript && this.autoListening) {
            this.vadSpeechDetected = true
            this.resetAutoListenSilenceTimer()
          }

          if (finalTranscript && this.autoListening) {
            this.vadSpeechDetected = true
            this.resetAutoListenSilenceTimer()
          }
        }
      }

      this.initialized = true
    },
    mapRecognitionError(errorCode) {
      const map = {
        'no-speech': '没有识别到语音，请再试一次。',
        'audio-capture': '未检测到麦克风设备。',
        'not-allowed': '麦克风权限被拒绝，请在浏览器中允许权限。',
        network: '语音识别网络异常，请稍后重试。',
        aborted: '语音识别已中断。',
      }
      return map[errorCode] || '语音识别失败，请改用文字输入。'
    },
    async recognizeOnce() {
      this.init()
      if (!this.recognitionSupported || !this.recognition) {
        this.lastError = '当前浏览器不支持语音识别，请使用文字输入。'
        return ''
      }

      this.lastError = ''
      this.lastTranscript = ''

      const savedInterim = this.recognition.interimResults
      const savedContinuous = this.recognition.continuous
      this.recognition.interimResults = false
      this.recognition.continuous = false

      return new Promise((resolve) => {
        let settled = false
        const baseOnEnd = this.recognition.onend
        const baseOnError = this.recognition.onerror
        const baseOnResult = this.recognition.onresult
        let timeoutId = null

        const cleanup = () => {
          if (timeoutId) {
            window.clearTimeout(timeoutId)
            timeoutId = null
          }
          if (!this.recognition) {
            return
          }
          this.recognition.onend = baseOnEnd
          this.recognition.onerror = baseOnError
          this.recognition.onresult = baseOnResult
          this.recognition.interimResults = savedInterim
          this.recognition.continuous = savedContinuous
        }

        const finalize = (value) => {
          if (settled) {
            return
          }
          settled = true
          cleanup()
          resolve(value)
        }

        this.recognition.onerror = (event) => {
          if (baseOnError) {
            baseOnError(event)
          }
          finalize('')
        }

        this.recognition.onend = (event) => {
          if (baseOnEnd) {
            baseOnEnd(event)
          }
          finalize(this.lastTranscript)
        }

        this.recognition.onresult = (event) => {
          const transcript = event?.results?.[0]?.[0]?.transcript || ''
          this.lastTranscript = transcript.trim()
          finalize(this.lastTranscript)
        }

        try {
          this.recognition.start()
        } catch {
          this.lastError = '语音识别启动失败，请稍后重试。'
          cleanup()
          resolve('')
          return
        }

        timeoutId = window.setTimeout(() => {
          if (settled) {
            return
          }
          this.stopListening()
          if (!this.lastTranscript) {
            this.lastError = '识别超时，请点击麦克风重试。'
          }
          finalize(this.lastTranscript)
        }, 9000)
      })
    },
    startHoldListening() {
      this.init()
      if (!this.recognitionSupported || !this.recognition) {
        this.lastError = '当前浏览器不支持语音识别，请使用文字输入。'
        return false
      }

      if (this.listening || this.holdListening) {
        return false
      }

      this.lastError = ''
      this.lastTranscript = ''
      this.holdListening = true
      holdSessionPromise = new Promise((resolve) => {
        holdSessionResolve = resolve
      })

      try {
        this.recognition.start()
        return true
      } catch {
        this.holdListening = false
        holdSessionResolve = null
        holdSessionPromise = null
        this.lastError = '语音识别启动失败，请稍后重试。'
        return false
      }
    },
    async stopHoldListening() {
      if (!this.holdListening || !this.recognition) {
        return ''
      }

      const pending = holdSessionPromise || Promise.resolve(this.lastTranscript)
      this.stopListening()
      const transcript = await pending
      this.holdListening = false
      return transcript
    },
    stopListening() {
      if (!this.recognition) {
        return
      }
      try {
        this.recognition.stop()
      } catch {
        // ignore stop race
      }
    },
    stopSpeaking() {
      if (!this.synthesisSupported || typeof window === 'undefined') {
        return
      }
      window.speechSynthesis.cancel()
      this.speaking = false
    },
    ensureVoicesLoaded() {
      if (typeof window === 'undefined' || !window.speechSynthesis) return
      window.speechSynthesis.getVoices()
    },
    speak(text) {
      this.speakWithMood(text, '')
    },
    setPersona(persona) {
      const key = String(persona || '').trim().toLowerCase()
      if (!PERSONA_SPEECH_MAP[key]) {
        this.persona = 'default'
        return
      }
      this.persona = key
    },
    speakWithMood(text, mood = '') {
      this.init()
      if (!this.synthesisSupported || typeof window === 'undefined') {
        return
      }

      const content = String(text || '').trim()
      if (!content) {
        return
      }

      this.stopSpeaking()
      this.ensureVoicesLoaded()

      const utter = new SpeechSynthesisUtterance(content)
      utter.lang = RECOGNITION_LANG
      const profile = resolveSpeechProfile(mood)
      const personaProfile = PERSONA_SPEECH_MAP[this.persona] || PERSONA_SPEECH_MAP.default
      utter.rate = Math.max(0.6, Math.min(1.3, profile.rate * personaProfile.rate))
      utter.pitch = Math.max(0.6, Math.min(1.4, profile.pitch * personaProfile.pitch))

      utter.onstart = () => {
        this.speaking = true
        this.lastError = ''
      }

      utter.onend = () => {
        this.speaking = false
      }

      utter.onerror = (event) => {
        this.speaking = false
        const code = event?.error || ''
        if (code === 'interrupted' || code === 'canceled') {
          return
        }
        if (code === 'not-allowed') {
          this.lastError = '语音播报需要与页面交互后才能播放，请点击页面后再试。'
          return
        }
        if (code === 'audio-busy' || code === 'network') {
          this.lastError = '语音引擎繁忙或网络异常，请稍后重试。'
          return
        }
        if (code === 'synthesis-unavailable') {
          this.lastError = '当前环境不支持语音合成。'
          return
        }
        this.lastError = '语音播报失败，请稍后重试。'
      }

      let started = false
      const run = () => {
        if (started) return
        started = true
        window.speechSynthesis.speak(utter)
      }
      if (window.speechSynthesis.getVoices().length === 0) {
        const once = () => {
          window.speechSynthesis.removeEventListener('voiceschanged', once)
          run()
        }
        window.speechSynthesis.addEventListener('voiceschanged', once)
        window.setTimeout(() => {
          window.speechSynthesis.removeEventListener('voiceschanged', once)
          run()
        }, 400)
      } else {
        run()
      }
    },
    startAutoListen(silenceThreshold = 1500) {
      this.init()
      if (!this.recognitionSupported || !this.recognition) {
        this.lastError = '当前浏览器不支持语音识别，无法开启自动监听。'
        return false
      }

      if (this.autoListening) {
        return true
      }

      this.autoListening = true
      this.autoListenAccumulated = ''
      this.vadSpeechDetected = false
      this.lastError = ''

      try {
        this.recognition.start()
        return true
      } catch {
        this.autoListening = false
        this.lastError = '自动监听启动失败，请稍后重试。'
        return false
      }
    },
    stopAutoListen() {
      this.autoListening = false
      this.clearAutoListenSilenceTimer()
      this.stopListening()
      const result = this.autoListenAccumulated.trim()
      this.autoListenAccumulated = ''
      this.vadSpeechDetected = false
      return result
    },
    resetAutoListenSilenceTimer() {
      this.clearAutoListenSilenceTimer()
    },
    clearAutoListenSilenceTimer() {
      if (this.autoListenSilenceTimer) {
        window.clearTimeout(this.autoListenSilenceTimer)
        this.autoListenSilenceTimer = 0
      }
    },
    restartAutoListen() {
      if (!this.autoListening) return
      this.clearAutoListenSilenceTimer()
      try {
        if (!this.recognizing) {
          this.recognition.start()
        }
      } catch {
        // ignore restart race
      }
    },
    checkAutoListenSilence(silenceThreshold = 1500) {
      if (!this.autoListening) return
      this.clearAutoListenSilenceTimer()
      if (this.vadSpeechDetected) {
        this.autoListenSilenceTimer = window.setTimeout(() => {
          this.autoListenSilenceTimer = 0
        }, silenceThreshold)
      }
    },
    isAutoListenSilenceTimedOut() {
      return this.autoListening && this.vadSpeechDetected && !this.autoListenSilenceTimer && this.autoListenAccumulated.trim().length > 0
    },
  },
})
