<script setup>
import { onMounted, onUnmounted, ref } from 'vue'
import * as THREE from 'three'
import { useAudioStore } from '@/stores/audioStore'
import { useUserStore } from '@/stores/userStore'

const containerRef = ref(null)
const audioStore = useAudioStore()
const userStore = useUserStore()

let renderer = null
let scene = null
let camera = null
let ringMesh = null
let innerMesh = null
let frameId = null
let raycaster = null
let pointer = null
let glowUntil = 0

function buildScene() {
  const container = containerRef.value
  if (!container) {
    return
  }

  const width = container.clientWidth
  const height = container.clientHeight

  scene = new THREE.Scene()
  camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 100)
  camera.position.set(0, 0, 4.6)

  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
  renderer.setSize(width, height)
  container.appendChild(renderer.domElement)

  const ringGeometry = new THREE.TorusGeometry(1.24, 0.32, 64, 180)
  const ringMaterial = new THREE.MeshPhysicalMaterial({
    color: 0x9bc5ad,
    roughness: 0.24,
    metalness: 0.07,
    transmission: 0.65,
    thickness: 0.72,
    clearcoat: 0.75,
    clearcoatRoughness: 0.2,
  })
  ringMesh = new THREE.Mesh(ringGeometry, ringMaterial)
  scene.add(ringMesh)

  const innerGeometry = new THREE.TorusGeometry(0.55, 0.055, 40, 120)
  const innerMaterial = new THREE.MeshStandardMaterial({
    color: 0xddeee3,
    emissive: 0x517466,
    emissiveIntensity: 0.16,
  })
  innerMesh = new THREE.Mesh(innerGeometry, innerMaterial)
  scene.add(innerMesh)

  const ambient = new THREE.AmbientLight(0xf3f9f2, 0.6)
  scene.add(ambient)

  const pointA = new THREE.PointLight(0xbde1cf, 1.2, 12)
  pointA.position.set(2.5, 1.8, 2)
  scene.add(pointA)

  const pointB = new THREE.PointLight(0xeed39a, 0.9, 10)
  pointB.position.set(-2.8, -1.7, 2)
  scene.add(pointB)

  raycaster = new THREE.Raycaster()
  pointer = new THREE.Vector2()
}

function animate() {
  if (!renderer || !scene || !camera) {
    return
  }

  ringMesh.rotation.x += 0.003
  ringMesh.rotation.y += 0.005
  innerMesh.rotation.z -= 0.006
  innerMesh.position.y = Math.sin(performance.now() * 0.0014) * 0.05

  const now = performance.now()
  if (now < glowUntil) {
    innerMesh.material.emissiveIntensity = 0.34
  } else {
    innerMesh.material.emissiveIntensity = 0.16
  }

  renderer.render(scene, camera)
  frameId = requestAnimationFrame(animate)
}

async function handlePointerDown(event) {
  const container = containerRef.value
  if (!container || !renderer || !camera || !raycaster || !pointer) {
    return
  }

  const rect = renderer.domElement.getBoundingClientRect()
  pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1
  pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1

  raycaster.setFromCamera(pointer, camera)
  const hits = raycaster.intersectObjects([ringMesh, innerMesh], false)
  if (!hits.length) {
    return
  }

  const matchedJade = userStore.matchedJade
  const emotion = userStore.currentEmotion || 'neutral'

  try {
    await audioStore.playJadeMelody({
      jade: matchedJade,
      emotion,
      mode: 'touch',
    })
    glowUntil = performance.now() + 260
  } catch {
    // ignore audio failures in scene interaction
  }
}

function handleResize() {
  const container = containerRef.value
  if (!container || !renderer || !camera) {
    return
  }

  const width = container.clientWidth
  const height = container.clientHeight
  camera.aspect = width / height
  camera.updateProjectionMatrix()
  renderer.setSize(width, height)
}

function disposeScene() {
  if (frameId) {
    cancelAnimationFrame(frameId)
    frameId = null
  }

  window.removeEventListener('resize', handleResize)
  if (renderer && renderer.domElement) {
    renderer.domElement.removeEventListener('pointerdown', handlePointerDown)
  }

  if (ringMesh) {
    ringMesh.geometry.dispose()
    ringMesh.material.dispose()
  }

  if (innerMesh) {
    innerMesh.geometry.dispose()
    innerMesh.material.dispose()
  }

  if (renderer) {
    renderer.dispose()
    if (renderer.domElement && renderer.domElement.parentNode) {
      renderer.domElement.parentNode.removeChild(renderer.domElement)
    }
  }

  scene = null
  camera = null
  renderer = null
  ringMesh = null
  innerMesh = null
  raycaster = null
  pointer = null
}

onMounted(() => {
  buildScene()
  animate()
  if (renderer?.domElement) {
    renderer.domElement.addEventListener('pointerdown', handlePointerDown)
  }
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  disposeScene()
})
</script>

<template>
  <div ref="containerRef" class="scene-wrap"></div>
</template>

<style scoped>
.scene-wrap {
  width: 100%;
  height: min(460px, 58vw);
  min-height: 320px;
  border-radius: 30px;
  background:
    radial-gradient(circle at 50% 35%, rgba(237, 248, 240, 0.88), rgba(223, 236, 225, 0.22) 64%),
    linear-gradient(140deg, rgba(244, 241, 232, 0.8), rgba(219, 232, 223, 0.35));
  border: 1px solid rgba(61, 95, 82, 0.15);
  box-shadow: inset 0 0 20px rgba(255, 255, 255, 0.6);
}
</style>
