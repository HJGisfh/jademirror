import { defineStore } from 'pinia'

const SOUND_MUTE_KEY = 'jademirror-sound-muted-v1'

function readMuted() {
  try {
    return localStorage.getItem(SOUND_MUTE_KEY) === '1'
  } catch {
    return false
  }
}

const emotionModifiers = {
  happy: { freqFactor: 1.06, filterFactor: 1.2, waveform: 'triangle', gain: 1.08 },
  sad: { freqFactor: 0.94, filterFactor: 0.76, waveform: null, gain: 0.84 },
  angry: { freqFactor: 1.12, filterFactor: 0.9, waveform: 'sawtooth', gain: 1.2 },
  surprised: { freqFactor: 1.1, filterFactor: 1.35, waveform: 'square', gain: 1 },
  neutral: { freqFactor: 1, filterFactor: 1, waveform: null, gain: 1 },
}

export const useAudioStore = defineStore('audio', {
  state: () => ({
    audioContext: null,
    initialized: false,
    muted: readMuted(),
  }),
  actions: {
    setMuted(value) {
      this.muted = Boolean(value)
      try {
        localStorage.setItem(SOUND_MUTE_KEY, this.muted ? '1' : '0')
      } catch {
        // ignore localStorage failures in private mode
      }
    },
    async ensureContext() {
      if (!this.audioContext) {
        const Ctx = window.AudioContext || window.webkitAudioContext
        if (!Ctx) {
          throw new Error('当前浏览器不支持 Web Audio API')
        }
        this.audioContext = new Ctx()
      }

      if (this.audioContext.state === 'suspended') {
        await this.audioContext.resume()
      }

      this.initialized = true
      return this.audioContext
    },
    async primeContext() {
      const ctx = await this.ensureContext()
      if (ctx.state === 'running') {
        await ctx.suspend()
      }
    },
    async playDynamicSound({ jade, emotion = 'neutral', overrideAudioParams = null }) {
      if (this.muted) {
        return
      }

      const ctx = await this.ensureContext()
      const now = ctx.currentTime

      const params = overrideAudioParams || jade?.audioParams
      if (!params) {
        return
      }

      const modifier = emotionModifiers[emotion] || emotionModifiers.neutral
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()
      const filter = ctx.createBiquadFilter()

      const baseFreq = params.baseFreq || 440
      const filterFreq = params.filterFreq || 1200
      const waveform = modifier.waveform || params.waveform || 'sine'
      const attack = params.attack || 0.05
      const decay = params.decay || 1.5
      const peakGain = 0.22 * modifier.gain

      osc.type = waveform
      osc.frequency.setValueAtTime(baseFreq * modifier.freqFactor, now)

      filter.type = params.filterType || 'lowpass'
      filter.frequency.setValueAtTime(filterFreq * modifier.filterFactor, now)
      filter.Q.setValueAtTime(0.8, now)

      gain.gain.setValueAtTime(0.0001, now)
      gain.gain.exponentialRampToValueAtTime(peakGain, now + attack)
      gain.gain.exponentialRampToValueAtTime(0.0001, now + decay)

      osc.connect(filter)
      filter.connect(gain)
      gain.connect(ctx.destination)

      osc.start(now)
      osc.stop(now + decay)
    },
  },
})
