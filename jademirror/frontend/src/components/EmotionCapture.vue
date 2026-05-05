<script setup>
import { onBeforeUnmount, ref } from 'vue'

const emit = defineEmits(['emotion-change'])

const videoRef = ref(null)
const activeEmotion = ref('neutral')
const running = ref(false)
const statusText = ref('未启动检测，默认情绪为平和。')

let stream = null
let timer = null
let faceapi = null

const emotions = ['happy', 'sad', 'angry', 'surprised', 'neutral']

function updateEmotion(emotion) {
  activeEmotion.value = emotion
  emit('emotion-change', emotion)
}

async function loadFaceModels() {
  if (!faceapi) {
    await import('@tensorflow/tfjs')
    faceapi = await import('face-api.js')
  }

  await faceapi.nets.tinyFaceDetector.loadFromUri('/models')
  await faceapi.nets.faceExpressionNet.loadFromUri('/models')
}

async function detectEmotion() {
  if (!videoRef.value || !faceapi) {
    return
  }

  try {
    const result = await faceapi
      .detectSingleFace(videoRef.value, new faceapi.TinyFaceDetectorOptions())
      .withFaceExpressions()

    if (!result || !result.expressions) {
      return
    }

    const dominant = Object.entries(result.expressions).sort((a, b) => b[1] - a[1])[0][0]
    const mapped = emotions.includes(dominant) ? dominant : 'neutral'
    updateEmotion(mapped)
    statusText.value = `识别中：当前主导情绪为 ${mapped}`
  } catch {
    statusText.value = '识别暂时中断，已回退至手动情绪。'
  }
}

async function startCapture() {
  if (running.value) {
    return
  }

  try {
    statusText.value = '请求摄像头权限中...'
    stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false })
    videoRef.value.srcObject = stream

    statusText.value = '加载表情模型中...'
    await loadFaceModels()

    timer = window.setInterval(detectEmotion, 1700)
    running.value = true
    statusText.value = '表情检测已开启。'
  } catch {
    running.value = false
    statusText.value = '无法使用摄像头或模型未就绪，已使用默认情绪。'
    updateEmotion('neutral')
    stopCapture()
  }
}

function stopCapture() {
  if (timer) {
    window.clearInterval(timer)
    timer = null
  }

  if (stream) {
    stream.getTracks().forEach((track) => track.stop())
    stream = null
  }

  if (videoRef.value) {
    videoRef.value.srcObject = null
  }

  running.value = false
}

function setManualEmotion(emotion) {
  updateEmotion(emotion)
  statusText.value = `手动设置情绪为 ${emotion}`
}

onBeforeUnmount(() => {
  stopCapture()
})
</script>

<template>
  <section class="capture jade-card">
    <div class="capture-head">
      <h3>表情识别</h3>
      <span class="status-pill">当前：{{ activeEmotion }}</span>
    </div>

    <p class="text-muted">{{ statusText }}</p>

    <video ref="videoRef" class="capture-video" autoplay muted playsinline></video>

    <div class="actions-row">
      <button type="button" class="jade-button secondary" @click="startCapture">
        开启摄像头检测
      </button>
      <button type="button" class="jade-button secondary" @click="stopCapture">
        关闭检测
      </button>
    </div>

    <div class="manual-row">
      <p class="text-muted">手动选择情绪：</p>
      <div class="chips">
        <button
          v-for="emotion in emotions"
          :key="emotion"
          type="button"
          class="chip"
          :class="{ active: activeEmotion === emotion }"
          @click="setManualEmotion(emotion)"
        >
          {{ emotion }}
        </button>
      </div>
    </div>
  </section>
</template>

<style scoped>
.capture {
  padding: 1rem;
  display: grid;
  gap: 0.8rem;
}

.capture-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.6rem;
  flex-wrap: wrap;
}

.capture-video {
  width: 100%;
  border-radius: var(--radius-md);
  border: 1px solid rgba(57, 93, 79, 0.18);
  background: #d8dfdb;
  min-height: 180px;
  object-fit: cover;
}

.manual-row {
  display: grid;
  gap: 0.45rem;
}

.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
}

.chip {
  border: 1px solid rgba(48, 83, 71, 0.25);
  background: rgba(236, 244, 239, 0.88);
  border-radius: 999px;
  padding: 0.3rem 0.72rem;
  cursor: pointer;
}

.chip.active {
  background: rgba(62, 102, 88, 0.9);
  color: #f4f8f5;
  border-color: transparent;
}
</style>
