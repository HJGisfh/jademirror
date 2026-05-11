import { defineStore, getActivePinia } from 'pinia'
import { fetchHealth, synthesizeVoiceCloud } from '@/api/jadeApi'
import { useAudioStore } from './audioStore'

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
// 韵律：与系统 TTS 音色叠加；仅靠 rate/pitch 时中文差异小，故与 pickVoiceForPersona 配合使用
const PERSONA_SPEECH_MAP = {
  default: { rate: 0.9, pitch: 0.86, volume: 0.98 },
  warm: { rate: 1, pitch: 1, volume: 1 },
  bright: { rate: 1.1, pitch: 1.14, volume: 1 },
  deep: { rate: 0.74, pitch: 0.64, volume: 1 },
}
let holdSessionResolve = null
let holdSessionPromise = null
/** 云 TTS 当前正在播放的 audio + 资源 URL，用于 stopSpeaking 时清理 */
let cloudAudio = null
let cloudAudioUrl = ''
let cloudTtsProbePromise = null

/** 顶栏「音效关」同时静音 Web Audio 与语音播报 */
function isGlobalSoundMuted() {
  try {
    const pinia = getActivePinia()
    if (!pinia) {
      return false
    }
    return useAudioStore(pinia).muted
  } catch {
    return false
  }
}

function sleep(ms) {
  return new Promise((resolve) => {
    if (typeof window === 'undefined') {
      resolve()
      return
    }
    window.setTimeout(resolve, ms)
  })
}

/** 判断 Blob 是否为 mp3（ID3 头或帧同步），避免把 JSON 错误页当音频播放 */
async function blobLooksLikeMp3(blob) {
  if (!blob || typeof blob.slice !== 'function') {
    return false
  }
  const head = new Uint8Array(await blob.slice(0, 4).arrayBuffer())
  if (head.length < 2) {
    return false
  }
  if (head[0] === 0x49 && head[1] === 0x44 && head[2] === 0x33) {
    return true
  }
  if (head[0] === 0xff && (head[1] & 0xe0) === 0xe0) {
    return true
  }
  return false
}

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

/** 拼接本次事件中已 final 的片段；按住+continuous 时会有多段 */
function transcriptFromSpeechResultEvent(event) {
  const results = event?.results
  if (!results?.length) {
    return ''
  }
  let line = ''
  for (let i = 0; i < results.length; i += 1) {
    const r = results[i]
    if (r.isFinal) {
      line += r[0]?.transcript || ''
    }
  }
  if (!line.trim()) {
    const last = results[results.length - 1]
    line = last[0]?.transcript || ''
  }
  return line.trim()
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

/** 浏览器首次调用 getVoices 常为空，需等 voiceschanged */
function loadVoicesWhenReady() {
  return new Promise((resolve) => {
    if (typeof window === 'undefined' || !window.speechSynthesis) {
      resolve([])
      return
    }
    const synth = window.speechSynthesis
    let settled = false
    const finish = () => {
      if (settled) {
        return
      }
      settled = true
      resolve(synth.getVoices() || [])
    }
    if (synth.getVoices().length) {
      finish()
      return
    }
    synth.addEventListener('voiceschanged', finish, { once: true })
    window.setTimeout(finish, 750)
  })
}

function isZhFamilyVoice(voice) {
  const lang = String(voice.lang || '').toLowerCase()
  const blob = `${voice.name} ${voice.voiceURI}`.toLowerCase()
  return (
    lang.startsWith('zh') ||
    blob.includes('chinese') ||
    blob.includes('mandarin') ||
    blob.includes('中文')
  )
}

/**
 * 按 persona 在可用音色里打分选声（Edge/Chrome 常见：Kangkang/Yunyang 偏男低，Xiaoxiao/Yaoyao 偏女亮）
 */
function pickVoiceForPersona(persona, voices) {
  if (!voices || !voices.length) {
    return null
  }
  const zhPool = voices.filter(isZhFamilyVoice)
  const pool = zhPool.length ? zhPool : voices

  const nameBlob = (v) => `${v.name} ${v.voiceURI}`.toLowerCase()

  const score = (v) => {
    const n = nameBlob(v)
    let s = 0
    if (persona === 'deep') {
      if (/kangkang|yunyang|yunxi|yunjian|male|男|hong|hao|brian|david/.test(n)) {
        s += 120
      }
      if (/xiaoxiao|yaoyao|huihui|xiaoyi|晓|yan|女|female|zhiwei|xiaorui/.test(n)) {
        s -= 90
      }
    } else if (persona === 'bright') {
      if (/xiaoxiao|yaoyao|huihui|xiaoyi|晓|yan|女|female|zhiwei|xiaorui|young/.test(n)) {
        s += 120
      }
      if (/kangkang|yunyang|male|男|baritone/.test(n)) {
        s -= 70
      }
    } else if (persona === 'default') {
      if (/xiaoyi|xiaoxiao|huihui|yun|柔|warm|温和/.test(n)) {
        s += 90
      }
      if (/yaoyao|bright/.test(n)) {
        s += 40
      }
      if (/kangkang|yunyang/.test(n)) {
        s += 25
      }
    } else {
      s = 30
      if (v.default) {
        s += 40
      }
      if (isZhFamilyVoice(v)) {
        s += 20
      }
    }
    return s
  }

  let best = pool[0]
  let bestScore = score(best)
  for (let i = 1; i < pool.length; i += 1) {
    const v = pool[i]
    const sc = score(v)
    if (sc > bestScore) {
      best = v
      bestScore = sc
    }
  }
  return best
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
    /** 后端 /api/health 是否报告 volc_tts_configured；null = 未探测 */
    cloudTtsAvailable: null,
  }),
  actions: {
    /**
     * 修正语音识别常见错误
     * 优先将玉文化相关的误识别词汇修正为正确的"玉"字
     */
    correctTranscript(text) {
      if (!text) return ''
      
      let corrected = text
      
      // 玉文化相关的常见误识别修正
      // "域" → "玉" (最常见的误识别)
      corrected = corrected.replace(/与域对话/g, '与玉对话')
      corrected = corrected.replace(/和域对话/g, '和玉对话')
      corrected = corrected.replace(/跟域对话/g, '跟玉对话')
      corrected = corrected.replace(/域对话/g, '玉对话')
      corrected = corrected.replace(/开始与域/g, '开始与玉')
      corrected = corrected.replace(/开始和域/g, '开始和玉')
      
      // 其他可能的误识别
      corrected = corrected.replace(/遇见/g, '玉')  // 在"我的玉"等语境下
      corrected = corrected.replace(/预见/g, '玉')
      corrected = corrected.replace(/御/g, '玉')
      corrected = corrected.replace(/育/g, '玉')
      
      // 生成相关
      corrected = corrected.replace(/生成域/g, '生成玉')
      corrected = corrected.replace(/生域/g, '生玉')
      corrected = corrected.replace(/生成我的域/g, '生成我的玉')
      
      // 匹配相关
      corrected = corrected.replace(/匹配域/g, '匹配玉')
      corrected = corrected.replace(/匹配的域/g, '匹配的玉')
      
      // 古玉相关
      corrected = corrected.replace(/古域/g, '古玉')
      corrected = corrected.replace(/顾域/g, '古玉')
      
      console.log('🔧 语音识别修正:')
      console.log(`   原文: "${text}"`)
      console.log(`   修正: "${corrected}"`)
      
      return corrected
    },
    /** 绑定「按住说话」与默认识别回调（新建实例时必须调用） */
    attachBaseHandlers(rec) {
      if (!rec) {
        return
      }
      rec.lang = RECOGNITION_LANG
      rec.interimResults = false
      rec.continuous = false
      rec.maxAlternatives = 1

      rec.onstart = () => {
        this.listening = true
        this.recognizing = true
        this.lastError = ''
      }

      rec.onend = () => {
        this.listening = false
        this.recognizing = false
        this.holdListening = false
        if (holdSessionResolve) {
          holdSessionResolve(this.lastTranscript)
          holdSessionResolve = null
          holdSessionPromise = null
        }
      }

      rec.onerror = (event) => {
        this.lastError = this.mapRecognitionError(event?.error)
        this.listening = false
        this.recognizing = false
        this.holdListening = false
        if (holdSessionResolve) {
          holdSessionResolve('')
          holdSessionResolve = null
          holdSessionPromise = null
        }
      }

      rec.onresult = (event) => {
        const raw = transcriptFromSpeechResultEvent(event)
        this.lastTranscript = this.correctTranscript(raw)
      }
    },

    /** 结束上一轮识别并留出间隔，避免 Chrome 连续 start 抛 InvalidStateError */
    async settleRecognitionEngine() {
      if (!this.recognition || typeof window === 'undefined') {
        return
      }
      try {
        if (typeof this.recognition.abort === 'function') {
          this.recognition.abort()
        } else {
          this.recognition.stop()
        }
      } catch {
        try {
          this.recognition.stop()
        } catch {
          // ignore
        }
      }
      if (holdSessionResolve) {
        holdSessionResolve('')
        holdSessionResolve = null
        holdSessionPromise = null
      }
      this.holdListening = false
      this.listening = false
      this.recognizing = false
      await sleep(160)
      if (this.recognition) {
        try {
          this.recognition.continuous = false
        } catch {
          // ignore
        }
      }
    },

    /** 丢弃旧实例并新建（严重卡死时的恢复手段） */
    rebuildRecognition() {
      const support = readSupport()
      if (!support.RecognitionCtor) {
        return false
      }
      if (this.recognition) {
        try {
          if (typeof this.recognition.abort === 'function') {
            this.recognition.abort()
          } else {
            this.recognition.stop()
          }
        } catch {
          try {
            this.recognition.stop()
          } catch {
            // ignore
          }
        }
      }
      this.recognition = new support.RecognitionCtor()
      this.attachBaseHandlers(this.recognition)
      this.listening = false
      this.recognizing = false
      this.holdListening = false
      holdSessionResolve = null
      holdSessionPromise = null
      return true
    },

    init() {
      const support = readSupport()
      this.recognitionSupported = support.recognitionSupported
      this.synthesisSupported = support.synthesisSupported

      if (support.RecognitionCtor && !this.recognition) {
        this.recognition = new support.RecognitionCtor()
        this.attachBaseHandlers(this.recognition)
      }

      this.initialized = true
      this.probeCloudTts()
    },
    /** 探测后端是否配置了火山豆包 TTS；只查一次并缓存结果。 */
    probeCloudTts() {
      if (this.cloudTtsAvailable !== null || cloudTtsProbePromise) {
        return cloudTtsProbePromise || Promise.resolve(this.cloudTtsAvailable)
      }
      cloudTtsProbePromise = fetchHealth()
        .then((data) => {
          this.cloudTtsAvailable = Boolean(data?.volc_tts_configured)
          return this.cloudTtsAvailable
        })
        .catch(() => {
          this.cloudTtsAvailable = false
          return false
        })
        .finally(() => {
          cloudTtsProbePromise = null
        })
      return cloudTtsProbePromise
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

      await this.settleRecognitionEngine()

      this.lastError = ''
      this.lastTranscript = ''

      return new Promise((resolve) => {
        let settled = false
        let timeoutId = null

        const cleanup = () => {
          if (timeoutId) {
            window.clearTimeout(timeoutId)
            timeoutId = null
          }
          if (this.recognition) {
            this.attachBaseHandlers(this.recognition)
          }
        }

        const finalize = (value) => {
          if (settled) {
            return
          }
          settled = true
          cleanup()
          resolve(value)
        }

        const bindOnceHandlers = () => {
          if (!this.recognition) {
            return
          }
          const baseOnEnd = this.recognition.onend
          const baseOnError = this.recognition.onerror
          const baseOnResult = this.recognition.onresult

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
            const raw = transcriptFromSpeechResultEvent(event)
            this.lastTranscript = this.correctTranscript(raw)
            finalize(this.lastTranscript)
          }
        }

        bindOnceHandlers()

        const tryStart = async () => {
          if (!this.recognition) {
            return false
          }
          try {
            this.recognition.start()
            return true
          } catch {
            await sleep(220)
            this.rebuildRecognition()
            bindOnceHandlers()
            await sleep(120)
            try {
              this.recognition.start()
              return true
            } catch {
              return false
            }
          }
        }

        void tryStart().then((ok) => {
          if (!ok) {
            this.lastError = '语音识别启动失败，请稍后重试。'
            finalize('')
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
      })
    },
    async startHoldListening() {
      this.init()
      if (!this.recognitionSupported || !this.recognition) {
        this.lastError = '当前浏览器不支持语音识别，请使用文字输入。'
        return false
      }

      if (this.listening || this.holdListening) {
        return false
      }

      await this.settleRecognitionEngine()

      this.lastError = ''
      this.lastTranscript = ''
      this.holdListening = true
      holdSessionPromise = new Promise((resolve) => {
        holdSessionResolve = resolve
      })

      const tryStart = async () => {
        try {
          // 按住说话：保持会话直到松手 stop()；否则 continuous=false 会在用户停顿时提前 onend，导致松手时拿不到文本
          this.recognition.continuous = true
          this.recognition.start()
          return true
        } catch {
          await sleep(220)
          this.rebuildRecognition()
          await sleep(120)
          try {
            this.recognition.continuous = true
            this.recognition.start()
            return true
          } catch {
            return false
          }
        }
      }

      const ok = await tryStart()
      if (!ok) {
        this.holdListening = false
        holdSessionResolve = null
        holdSessionPromise = null
        this.lastError = '语音识别启动失败，请稍后重试。'
        return false
      }
      return true
    },
    async stopHoldListening() {
      if (!this.recognition) {
        return String(this.lastTranscript || '').trim()
      }
      const pending = holdSessionPromise
      if (this.holdListening) {
        this.stopListening()
      }
      let transcript = ''
      if (pending) {
        transcript = await pending
      }
      transcript = String(transcript || this.lastTranscript || '').trim()
      try {
        this.recognition.continuous = false
      } catch {
        // ignore
      }
      this.holdListening = false
      holdSessionResolve = null
      holdSessionPromise = null
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
      if (typeof window === 'undefined') {
        return
      }
      if (cloudAudio) {
        try {
          cloudAudio.pause()
          cloudAudio.src = ''
        } catch {
          // ignore
        }
        cloudAudio = null
      }
      if (cloudAudioUrl) {
        try {
          URL.revokeObjectURL(cloudAudioUrl)
        } catch {
          // ignore
        }
        cloudAudioUrl = ''
      }
      if (this.synthesisSupported && window.speechSynthesis) {
        try {
          window.speechSynthesis.cancel()
        } catch {
          // ignore
        }
      }
      this.speaking = false
    },
    /**
     * 使用火山豆包 TTS 播放。成功返回 true；失败/未配置返回 false 让调用方回退浏览器原生。
     */
    async _speakViaCloud(text, mood) {
      if (this.cloudTtsAvailable === null) {
        await this.probeCloudTts()
      }
      if (!this.cloudTtsAvailable) {
        return false
      }
      let blob
      try {
        blob = await synthesizeVoiceCloud({ text, persona: this.persona, mood })
      } catch (error) {
        let detail = error?.message || '云语音合成失败'
        const res = error?.response
        if (res?.data instanceof Blob) {
          try {
            const txt = await res.data.text()
            const parsed = JSON.parse(txt)
            detail = parsed.error || parsed.message || detail
          } catch {
            try {
              const txt = await res.data.text()
              if (txt && txt.length < 400) {
                detail = txt
              }
            } catch {
              // ignore
            }
          }
        }
        this.lastError = String(detail).slice(0, 240)
        // 单次失败：本次回退；503 一般是后端没配置，永久回退
        const status = error?.status
        if (status === 503 || status === 401 || status === 403) {
          this.cloudTtsAvailable = false
        }
        return false
      }
      if (!blob || (blob.size != null && blob.size < 64)) {
        this.lastError = '云语音返回数据过短，已改用本机播报。'
        return false
      }
      if (!(await blobLooksLikeMp3(blob))) {
        try {
          const txt = await blob.text()
          const parsed = JSON.parse(txt)
          this.lastError = String(parsed.error || parsed.message || txt).slice(0, 240)
        } catch {
          this.lastError = '云语音返回非音频，已改用本机播报。'
        }
        return false
      }
      try {
        if (cloudAudio) {
          cloudAudio.pause()
          cloudAudio = null
        }
        if (cloudAudioUrl) {
          URL.revokeObjectURL(cloudAudioUrl)
          cloudAudioUrl = ''
        }
        cloudAudioUrl = URL.createObjectURL(blob)
        const audio = new Audio(cloudAudioUrl)
        cloudAudio = audio
        audio.onplay = () => {
          this.speaking = true
        }
        const handleEnd = () => {
          this.speaking = false
          if (cloudAudio === audio) {
            cloudAudio = null
          }
          if (cloudAudioUrl) {
            try {
              URL.revokeObjectURL(cloudAudioUrl)
            } catch {
              // ignore
            }
            cloudAudioUrl = ''
          }
        }
        audio.onended = handleEnd
        audio.onerror = handleEnd
        await audio.play()
        return true
      } catch {
        // 播放失败（自动播放策略等），回退原生
        this.speaking = false
        if (cloudAudioUrl) {
          try {
            URL.revokeObjectURL(cloudAudioUrl)
          } catch {
            // ignore
          }
          cloudAudioUrl = ''
        }
        cloudAudio = null
        return false
      }
    },
    speak(text) {
      void this.speakWithMood(text, '')
    },
    setPersona(persona) {
      const key = String(persona || '').trim().toLowerCase()
      if (!PERSONA_SPEECH_MAP[key]) {
        this.persona = 'default'
        return
      }
      this.persona = key
    },
    async speakWithMood(text, mood = '') {
      this.init()
      if (typeof window === 'undefined') {
        return
      }

      const content = String(text || '').trim()
      if (!content) {
        return
      }

      if (isGlobalSoundMuted()) {
        return
      }

      this.stopSpeaking()

      const playedByCloud = await this._speakViaCloud(content, mood)
      if (playedByCloud) {
        return
      }

      if (!this.synthesisSupported) {
        return
      }

      const voices = await loadVoicesWhenReady()
      const picked = pickVoiceForPersona(this.persona, voices)

      const utter = new SpeechSynthesisUtterance(content)
      utter.lang = RECOGNITION_LANG
      if (picked) {
        utter.voice = picked
      }
      const profile = resolveSpeechProfile(mood)
      const personaProfile = PERSONA_SPEECH_MAP[this.persona] || PERSONA_SPEECH_MAP.default
      utter.rate = Math.max(0.55, Math.min(1.35, profile.rate * personaProfile.rate))
      utter.pitch = Math.max(0.55, Math.min(1.45, profile.pitch * personaProfile.pitch))
      utter.volume = Math.max(0.4, Math.min(1, personaProfile.volume ?? 1))

      utter.onstart = () => {
        this.speaking = true
      }

      utter.onend = () => {
        this.speaking = false
      }

      utter.onerror = () => {
        this.speaking = false
        this.lastError = '语音播报失败，请稍后重试。'
      }

      window.speechSynthesis.speak(utter)
    },
  },
})
