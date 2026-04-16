export async function fetchJadeLibrary() {
  const response = await fetch('/data/jades.json')
  if (!response.ok) {
    throw new Error('玉器库加载失败，请检查静态资源。')
  }
  return response.json()
}
