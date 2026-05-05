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
    activeNodes: [],
    melodyEndAt: 0,
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

      this.activeNodes.push({ osc, gain, filter })
      osc.onended = () => {
        this.activeNodes = this.activeNodes.filter((item) => item.osc !== osc)
      }
    },
    stopAllSounds() {
      if (!this.audioContext) {
        return
      }

      const now = this.audioContext.currentTime
      for (const item of this.activeNodes) {
        try {
          item.gain.gain.cancelScheduledValues(now)
          item.gain.gain.setValueAtTime(Math.max(item.gain.gain.value, 0.0001), now)
          item.gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.04)
          item.osc.stop(now + 0.05)
        } catch {
          // ignore nodes already stopped
        }
      }

      this.activeNodes = []
      this.melodyEndAt = now
    },
    createMelodyPattern({ emotion = 'neutral', baseFreq = 330, intensity = 'short' }) {
      const base = {
        neutral: [0, 3, 5, 7, 5, 3],
        happy: [0, 4, 7, 9, 7, 4],
        sad: [0, 2, 3, 5, 3, 2],
        angry: [0, 1, 5, 6, 4, 1],
        surprised: [0, 7, 12, 7, 10, 5],
      }

      const semitones = base[emotion] || base.neutral
      const duration = intensity === 'extended' ? 0.22 : 0.16
      const gap = intensity === 'extended' ? 0.03 : 0.02
      const targetSeconds = intensity === 'extended' ? 7.2 : 6

      const notes = []
      let elapsed = 0

      while (elapsed < targetSeconds) {
        for (const semi of semitones) {
          if (elapsed >= targetSeconds) {
            break
          }

          const remaining = targetSeconds - elapsed
          const noteDuration = Math.max(Math.min(duration, remaining), 0.08)

          notes.push({
            freq: baseFreq * Math.pow(2, semi / 12),
            duration: noteDuration,
            gap,
          })

          elapsed += noteDuration + gap
        }
      }

      return notes
    },
    async playJadeMelody({ jade, emotion = 'neutral', mode = 'touch', overrideAudioParams = null }) {
      if (this.muted) {
        return
      }

      const ctx = await this.ensureContext()
      const params = overrideAudioParams || jade?.audioParams || {}
      const modifier = emotionModifiers[emotion] || emotionModifiers.neutral
      const baseFreq = (params.baseFreq || 330) * modifier.freqFactor
      const filterFreq = (params.filterFreq || 1200) * modifier.filterFactor
      const waveform = modifier.waveform || params.waveform || 'sine'
      const filterType = params.filterType || 'lowpass'
      const now = ctx.currentTime
      const startAt = Math.max(now + 0.02, this.melodyEndAt)
      const notes = this.createMelodyPattern({
        emotion,
        baseFreq,
        intensity: mode === 'hold' ? 'extended' : 'short',
      })

      let cursor = startAt
      for (const note of notes) {
        const osc = ctx.createOscillator()
        const gain = ctx.createGain()
        const filter = ctx.createBiquadFilter()

        osc.type = waveform
        osc.frequency.setValueAtTime(note.freq, cursor)

        filter.type = filterType
        filter.frequency.setValueAtTime(filterFreq, cursor)
        filter.Q.setValueAtTime(0.75, cursor)

        const peakGain = mode === 'hold' ? 0.12 * modifier.gain : 0.09 * modifier.gain
        gain.gain.setValueAtTime(0.0001, cursor)
        gain.gain.exponentialRampToValueAtTime(peakGain, cursor + 0.03)
        gain.gain.exponentialRampToValueAtTime(0.0001, cursor + note.duration)

        osc.connect(filter)
        filter.connect(gain)
        gain.connect(ctx.destination)

        osc.start(cursor)
        osc.stop(cursor + note.duration)

        this.activeNodes.push({ osc, gain, filter })
        osc.onended = () => {
          this.activeNodes = this.activeNodes.filter((item) => item.osc !== osc)
        }

        cursor += note.duration + note.gap
      }

      this.melodyEndAt = cursor
    },
  },
})
