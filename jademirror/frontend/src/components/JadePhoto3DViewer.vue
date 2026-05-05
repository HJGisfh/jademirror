<script setup>
/**
 * 用千问返回的平面图贴在 Three.js 平面上做「立体预览」，
 * 外形与图片一致（无程序化玉琮体），拖拽旋转、惯性、点击音效与旧 3D 区一致。
 */
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import * as THREE from 'three'

const props = defineProps({
  imageSrc: { type: String, default: '' },
})

const emit = defineEmits(['trigger-sound'])

const containerRef = ref(null)
let renderer = null
let scene = null
let camera = null
let group = null
let mesh = null
let frameId = null
let texture = null
let dragging3d = false
let pointerId = null
let pressTimer = null
let pressTriggeredHold = false
let startX = 0
let startY = 0
let lastMoveX = 0
let rotationVelocity = 0
const autoRotateSpeed = 0.003

function clearGroupContent() {
  if (!group) return
  while (group.children.length > 0) {
    const ch = group.children[0]
    group.remove(ch)
    if (ch.geometry) ch.geometry.dispose()
    if (ch.material) {
      if (Array.isArray(ch.material)) ch.material.forEach((m) => m.dispose())
      else ch.material.dispose()
    }
  }
  mesh = null
  if (texture) {
    texture.dispose()
    texture = null
  }
}

function buildScene() {
  const container = containerRef.value
  if (!container || !props.imageSrc) return

  const width = container.clientWidth
  const height = container.clientHeight

  scene = new THREE.Scene()
  camera = new THREE.PerspectiveCamera(40, width / Math.max(height, 1), 0.1, 100)
  camera.position.set(0, 0.15, 3.2)

  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
  renderer.setSize(width, height)
  renderer.toneMapping = THREE.ACESFilmicToneMapping
  renderer.toneMappingExposure = 1.05
  container.appendChild(renderer.domElement)

  group = new THREE.Group()
  scene.add(group)

  scene.add(new THREE.AmbientLight(0xf5fbf7, 0.65))
  const key = new THREE.DirectionalLight(0xfff8ee, 1.0)
  key.position.set(2.2, 3.5, 4)
  scene.add(key)
  const fill = new THREE.DirectionalLight(0xd8eef0, 0.45)
  fill.position.set(-2.5, 0.5, 2)
  scene.add(fill)

  const loader = new THREE.TextureLoader()
  loader.load(
    props.imageSrc,
    (tex) => {
      tex.colorSpace = THREE.SRGBColorSpace
      tex.anisotropy = Math.min(8, renderer.capabilities.getMaxAnisotropy())
      texture = tex
      const iw = tex.image?.width || 1
      const ih = tex.image?.height || 1
      const aspect = iw / ih
      const h = 2.2
      const w = h * aspect
      clearGroupContent()
      const geo = new THREE.PlaneGeometry(w, h, 1, 1)
      const mat = new THREE.MeshStandardMaterial({
        map: tex,
        roughness: 0.42,
        metalness: 0.02,
        side: THREE.DoubleSide,
        transparent: true,
      })
      mesh = new THREE.Mesh(geo, mat)
      mesh.rotation.x = -0.08
      group.add(mesh)

      const rim = new THREE.Mesh(
        new THREE.PlaneGeometry(w + 0.06, h + 0.06),
        new THREE.MeshBasicMaterial({ color: 0xe8f2ec, transparent: true, opacity: 0.35, depthWrite: false }),
      )
      rim.position.z = -0.02
      group.add(rim)
    },
    undefined,
    () => {},
  )

  renderer.domElement.addEventListener('pointerdown', handlePointerDown)
  renderer.domElement.addEventListener('pointermove', handlePointerMove)
  renderer.domElement.addEventListener('pointerup', handlePointerUp)
  renderer.domElement.addEventListener('pointercancel', handlePointerUp)
  renderer.domElement.addEventListener('pointerleave', handlePointerUp)
}

function animate() {
  if (!renderer || !scene || !camera || !group) return
  if (!dragging3d) {
    if (Math.abs(rotationVelocity) > 0.0001) {
      group.rotation.y += rotationVelocity
      rotationVelocity *= 0.94
      if (Math.abs(rotationVelocity) < 0.0001) rotationVelocity = 0
    } else {
      group.rotation.y += autoRotateSpeed
    }
  }
  renderer.render(scene, camera)
  frameId = requestAnimationFrame(animate)
}

function handlePointerDown(event) {
  if (!renderer?.domElement || pointerId !== null) return
  pointerId = event.pointerId
  dragging3d = false
  pressTriggeredHold = false
  startX = event.clientX
  startY = event.clientY
  lastMoveX = event.clientX
  rotationVelocity = 0
  renderer.domElement.setPointerCapture(pointerId)
  clearTimeout(pressTimer)
  pressTimer = window.setTimeout(() => {
    if (!dragging3d) {
      pressTriggeredHold = true
      emit('trigger-sound', 'hold')
    }
  }, 800)
}

function handlePointerMove(event) {
  if (pointerId === null || event.pointerId !== pointerId || !group) return
  const deltaX = event.clientX - startX
  const deltaY = event.clientY - startY
  if (Math.abs(deltaX) + Math.abs(deltaY) > 6) dragging3d = true
  if (dragging3d) {
    const rotDelta = deltaX * 0.008
    group.rotation.y += rotDelta
    group.rotation.x += deltaY * 0.0025
    group.rotation.x = Math.max(-0.45, Math.min(0.45, group.rotation.x))
    rotationVelocity = (event.clientX - lastMoveX) * 0.006
    lastMoveX = event.clientX
    startX = event.clientX
    startY = event.clientY
  }
}

function handlePointerUp(event) {
  if (pointerId === null || event.pointerId !== pointerId) return
  clearTimeout(pressTimer)
  if (!dragging3d && !pressTriggeredHold) emit('trigger-sound', 'touch')
  if (renderer?.domElement?.hasPointerCapture(pointerId)) renderer.domElement.releasePointerCapture(pointerId)
  pointerId = null
  dragging3d = false
  pressTriggeredHold = false
}

function handleResize() {
  const container = containerRef.value
  if (!container || !renderer || !camera) return
  const width = container.clientWidth
  const height = container.clientHeight
  camera.aspect = width / Math.max(height, 1)
  camera.updateProjectionMatrix()
  renderer.setSize(width, height)
}

function disposeScene() {
  clearTimeout(pressTimer)
  if (frameId) cancelAnimationFrame(frameId)
  frameId = null
  window.removeEventListener('resize', handleResize)
  if (renderer?.domElement) {
    renderer.domElement.removeEventListener('pointerdown', handlePointerDown)
    renderer.domElement.removeEventListener('pointermove', handlePointerMove)
    renderer.domElement.removeEventListener('pointerup', handlePointerUp)
    renderer.domElement.removeEventListener('pointercancel', handlePointerUp)
    renderer.domElement.removeEventListener('pointerleave', handlePointerUp)
  }
  clearGroupContent()
  if (renderer) {
    renderer.dispose()
    if (renderer.domElement?.parentNode) renderer.domElement.parentNode.removeChild(renderer.domElement)
  }
  scene = null
  camera = null
  renderer = null
  group = null
}

watch(
  () => props.imageSrc,
  (src) => {
    if (!src || !renderer || !group) return
    clearGroupContent()
    const loader = new THREE.TextureLoader()
    loader.load(
      src,
      (tex) => {
        tex.colorSpace = THREE.SRGBColorSpace
        tex.anisotropy = Math.min(8, renderer.capabilities.getMaxAnisotropy())
        texture = tex
        const iw = tex.image?.width || 1
        const ih = tex.image?.height || 1
        const aspect = iw / ih
        const h = 2.2
        const w = h * aspect
        const geo = new THREE.PlaneGeometry(w, h, 1, 1)
        const mat = new THREE.MeshStandardMaterial({
          map: tex,
          roughness: 0.42,
          metalness: 0.02,
          side: THREE.DoubleSide,
          transparent: true,
        })
        mesh = new THREE.Mesh(geo, mat)
        mesh.rotation.x = -0.08
        group.add(mesh)
        const rim = new THREE.Mesh(
          new THREE.PlaneGeometry(w + 0.06, h + 0.06),
          new THREE.MeshBasicMaterial({ color: 0xe8f2ec, transparent: true, opacity: 0.35, depthWrite: false }),
        )
        rim.position.z = -0.02
        group.add(rim)
      },
      undefined,
      () => {},
    )
  },
)

onMounted(() => {
  buildScene()
  animate()
  window.addEventListener('resize', handleResize)
})
onBeforeUnmount(() => disposeScene())
</script>

<template>
  <div ref="containerRef" class="photo-3d-viewer" />
</template>

<style scoped>
.photo-3d-viewer {
  width: 100%;
  height: min(480px, 58vw);
  min-height: 280px;
  border-radius: var(--radius-md);
  border: 1px dashed rgba(54, 89, 76, 0.36);
  background:
    radial-gradient(circle at 50% 40%, rgba(236, 248, 241, 0.9), rgba(217, 233, 222, 0.4) 65%),
    linear-gradient(145deg, rgba(250, 253, 251, 0.95), rgba(237, 247, 241, 0.75));
  touch-action: none;
}
</style>
