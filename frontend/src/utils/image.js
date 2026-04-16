function blobToDataURL(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onloadend = () => resolve(reader.result)
    reader.onerror = () => reject(new Error('图片转换失败'))
    reader.readAsDataURL(blob)
  })
}

export async function urlToDataURL(url) {
  const response = await fetch(url)
  if (!response.ok) {
    throw new Error('图片读取失败')
  }
  const blob = await response.blob()
  return blobToDataURL(blob)
}

export function createFallbackJadeDataURL(title = '玉镜') {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#dceadf"/><stop offset="100%" stop-color="#84a594"/></linearGradient></defs><rect width="1024" height="1024" rx="62" fill="#f6f2e7"/><circle cx="512" cy="512" r="308" fill="url(#g)" opacity="0.9"/><circle cx="512" cy="512" r="132" fill="#f6f2e7"/><text x="512" y="870" text-anchor="middle" fill="#27463f" font-size="52" font-family="STSong, serif">${title}</text></svg>`
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`
}
