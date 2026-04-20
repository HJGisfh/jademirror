<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import * as THREE from 'three'

const props = defineProps({
  imageSrc: {
    type: String,
    default: '',
  },
  jade: {
    type: Object,
    default: null,
  },
})

const emit = defineEmits(['trigger-sound'])

const containerRef = ref(null)

let renderer = null
let scene = null
let camera = null
let group = null
let bodyMesh = null
let ringMesh = null
let frameId = null
let dragging = false
let pointerId = null
let pressTimer = null
let pressTriggeredHold = false
let startX = 0
let startY = 0
let textureLoader = null
let activeTexture = null

const colorTintMap = {
  青: 0xaed3c1,
  白: 0xe7f2ea,
  黄: 0xdac99f,
  赤: 0xb99076,
}

function readTintColor(jade) {
  const colorKey = String(jade?.traits?.color || '')
  return colorTintMap[colorKey] || 0xb7d6c4
}

function clearMeshes() {
  if (!group) {
    return
  }

  const meshes = [bodyMesh, ringMesh].filter(Boolean)
  for (const mesh of meshes) {
    group.remove(mesh)
    if (mesh.geometry) {
      mesh.geometry.dispose()
    }
    if (mesh.material) {
      if (Array.isArray(mesh.material)) {
        mesh.material.forEach((item) => item.dispose())
      } else {
        mesh.material.dispose()
      }
    }
  }

  bodyMesh = null
  ringMesh = null

  if (activeTexture) {
    activeTexture.dispose()
    activeTexture = null
  }
}

function buildUnifiedShape() {
  clearMeshes()

  const tintColor = readTintColor(props.jade)

  const bodyMaterial = new THREE.MeshPhysicalMaterial({
    color: tintColor,
    roughness: 0.22,
    metalness: 0.06,
    transmission: 0.74,
    thickness: 0.72,
    clearcoat: 0.78,
    clearcoatRoughness: 0.2,
    ior: 1.48,
    attenuationColor: tintColor,
    attenuationDistance: 1.15,
  })

  const ringMaterial = new THREE.MeshPhysicalMaterial({
    color: 0xe2efe6,
    roughness: 0.15,
    metalness: 0,
    transmission: 0.58,
    thickness: 0.4,
    clearcoat: 0.8,
    clearcoatRoughness: 0.2,
    emissive: 0x335f50,
    emissiveIntensity: 0.09,
    ior: 1.45,
  })

  bodyMesh = new THREE.Mesh(new THREE.TorusGeometry(1.28, 0.33, 84, 220), bodyMaterial)
  ringMesh = new THREE.Mesh(new THREE.TorusGeometry(0.58, 0.085, 56, 160), ringMaterial)
  ringMesh.position.y = 0.02

  group.add(bodyMesh)
  group.add(ringMesh)
}

function buildScene() {
  const container = containerRef.value
  if (!container) {
    return
  }

  const width = container.clientWidth
  const height = container.clientHeight

  scene = new THREE.Scene()
  camera = new THREE.PerspectiveCamera(44, width / Math.max(height, 1), 0.1, 100)
  camera.position.set(0, 0.2, 5.2)

  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
  renderer.setSize(width, height)
  container.appendChild(renderer.domElement)

  group = new THREE.Group()
  scene.add(group)

  buildUnifiedShape()

  const ambient = new THREE.AmbientLight(0xf5fbf7, 0.58)
  scene.add(ambient)

  const hemiLight = new THREE.HemisphereLight(0xe7f7ee, 0x9eb7a8, 0.42)
  scene.add(hemiLight)

  const keyLight = new THREE.PointLight(0xbee7d2, 1.18, 12)
  keyLight.position.set(2.8, 2.2, 2.6)
  scene.add(keyLight)

  const fillLight = new THREE.PointLight(0xf1d9a8, 0.8, 10)
  fillLight.position.set(-2.3, -1.6, 1.8)
  scene.add(fillLight)

  textureLoader = new THREE.TextureLoader()
  applyTexture(props.imageSrc)

  if (renderer.domElement) {
    renderer.domElement.addEventListener('pointerdown', handlePointerDown)
    renderer.domElement.addEventListener('pointermove', handlePointerMove)
    renderer.domElement.addEventListener('pointerup', handlePointerUp)
    renderer.domElement.addEventListener('pointercancel', handlePointerUp)
    renderer.domElement.addEventListener('pointerleave', handlePointerUp)
  }
}

function applyTexture(src) {
  if (!bodyMesh || !ringMesh) {
    return
  }

  if (activeTexture) {
    activeTexture.dispose()
    activeTexture = null
  }

  if (!src) {
    bodyMesh.material.map = null
    ringMesh.material.map = null
    bodyMesh.material.needsUpdate = true
    ringMesh.material.needsUpdate = true
    return
  }

  textureLoader.load(
    src,
    (texture) => {
      texture.colorSpace = THREE.SRGBColorSpace
      texture.wrapS = THREE.RepeatWrapping
      texture.wrapT = THREE.RepeatWrapping
      texture.repeat.set(1.3, 1.2)
      texture.rotation = Math.PI * 0.08
      texture.anisotropy = 8

      activeTexture = texture
      bodyMesh.material.map = texture
      ringMesh.material.map = texture
      bodyMesh.material.needsUpdate = true
      ringMesh.material.needsUpdate = true
    },
    undefined,
    () => {
      bodyMesh.material.map = null
      ringMesh.material.map = null
      bodyMesh.material.needsUpdate = true
      ringMesh.material.needsUpdate = true
    },
  )
}

function animate() {
  if (!renderer || !scene || !camera || !group) {
    return
  }

  if (!dragging) {
    group.rotation.y += 0.004
    group.rotation.x += 0.0016
  }

  renderer.render(scene, camera)
  frameId = requestAnimationFrame(animate)
}

function handlePointerDown(event) {
  if (!renderer?.domElement || pointerId !== null) {
    return
  }

  pointerId = event.pointerId
  dragging = false
  pressTriggeredHold = false
  startX = event.clientX
  startY = event.clientY

  renderer.domElement.setPointerCapture(pointerId)

  clearTimeout(pressTimer)
  pressTimer = window.setTimeout(() => {
    if (!dragging) {
      pressTriggeredHold = true
      emit('trigger-sound', 'hold')
    }
  }, 800)
}

function handlePointerMove(event) {
  if (pointerId === null || event.pointerId !== pointerId || !group) {
    return
  }

  const deltaX = event.clientX - startX
  const deltaY = event.clientY - startY
  const travel = Math.abs(deltaX) + Math.abs(deltaY)

  if (travel > 6) {
    dragging = true
  }

  if (dragging) {
    group.rotation.y += deltaX * 0.006
    group.rotation.x += deltaY * 0.004
    group.rotation.x = Math.max(-1, Math.min(1, group.rotation.x))
    startX = event.clientX
    startY = event.clientY
  }
}

function handlePointerUp(event) {
  if (pointerId === null || event.pointerId !== pointerId) {
    return
  }

  clearTimeout(pressTimer)

  if (!dragging && !pressTriggeredHold) {
    emit('trigger-sound', 'touch')
  }

  if (renderer?.domElement && renderer.domElement.hasPointerCapture(pointerId)) {
    renderer.domElement.releasePointerCapture(pointerId)
  }

  pointerId = null
  dragging = false
  pressTriggeredHold = false
}

function handleResize() {
  const container = containerRef.value
  if (!container || !renderer || !camera) {
    return
  }

  const width = container.clientWidth
  const height = container.clientHeight

  camera.aspect = width / Math.max(height, 1)
  camera.updateProjectionMatrix()
  renderer.setSize(width, height)
}

function disposeScene() {
  clearTimeout(pressTimer)

  if (frameId) {
    cancelAnimationFrame(frameId)
    frameId = null
  }

  window.removeEventListener('resize', handleResize)

  if (renderer?.domElement) {
    renderer.domElement.removeEventListener('pointerdown', handlePointerDown)
    renderer.domElement.removeEventListener('pointermove', handlePointerMove)
    renderer.domElement.removeEventListener('pointerup', handlePointerUp)
    renderer.domElement.removeEventListener('pointercancel', handlePointerUp)
    renderer.domElement.removeEventListener('pointerleave', handlePointerUp)
  }

  if (bodyMesh) {
    clearMeshes()
  }

  if (renderer) {
    renderer.dispose()
    if (renderer.domElement?.parentNode) {
      renderer.domElement.parentNode.removeChild(renderer.domElement)
    }
  }

  scene = null
  camera = null
  renderer = null
  group = null
  bodyMesh = null
  ringMesh = null
  pointerId = null
}

watch(
  () => props.imageSrc,
  (value) => {
    applyTexture(value)
  },
)

watch(
  () => props.jade,
  () => {
    if (!group) {
      return
    }
    buildUnifiedShape()
    applyTexture(props.imageSrc)
  },
  { deep: true },
)

onMounted(() => {
  buildScene()
  animate()
  window.addEventListener('resize', handleResize)
})

onBeforeUnmount(() => {
  disposeScene()
})
</script>

<template>
  <div ref="containerRef" class="generated-viewer" />
</template>

<style scoped>
.generated-viewer {
  width: 100%;
  height: min(560px, 62vw);
  min-height: 300px;
  border-radius: var(--radius-md);
  border: 1px dashed rgba(54, 89, 76, 0.36);
  background:
    radial-gradient(circle at 54% 36%, rgba(236, 248, 241, 0.86), rgba(217, 233, 222, 0.36) 62%),
    linear-gradient(145deg, rgba(250, 253, 251, 0.9), rgba(237, 247, 241, 0.72));
  box-shadow: inset 0 0 24px rgba(255, 255, 255, 0.68);
  touch-action: none;
}
</style>
