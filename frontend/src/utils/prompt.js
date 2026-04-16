const colorMap = {
  青: '青白微翠，半透明玉质，冷调温润反光',
  白: '脂白凝润，细腻油脂感，高洁克制',
  赤: '赤沁温亮，局部沁色过渡自然，古拙有力',
  黄: '蜜黄沉稳，暖金玉感，厚重而含光',
}

const symbolMap = {
  龙: '螭龙或游龙纹，线条遒劲，带护佑意味',
  凤: '凤鸟回旋纹，羽翼舒展，灵秀典雅',
  蝉: '古蝉纹与羽化线条，清简克制，寓意新生',
  璧: '环璧纹与同心圆意象，礼器秩序感明确',
}

const landscapeMap = {
  山: '山峦层叠的起伏肌理，层次清晰',
  水: '流线般水纹走向，柔中见劲',
  竹: '竹节式细刻节律，清瘦有骨',
  云: '卷云与留白交织，轻灵飘逸',
}

const moodMap = {
  静: '沉静克制，呼吸感缓慢',
  雅: '清雅含蓄，书卷气强',
  烈: '刚毅有锋，力量感集中',
  灵: '灵动轻捷，节奏轻快',
}

const textureMap = {
  润: '温润细腻如脂，表面包浆自然',
  透: '晶透有光泽，边缘透光细腻',
  雕: '浅浮雕层次清晰，阴刻线干净',
  素: '素面留白克制，器形比例精确',
}

const emotionMap = {
  happy: '愉悦温暖，柔和金色光线，微微高光',
  sad: '沉静淡雅，薄雾明暗过渡，冷暖对比克制',
  surprised: '灵动飘逸，细节闪耀通透，边缘高亮',
  angry: '深沉有力，线条更具张力，低角度打光',
  neutral: '平静温润，自然博物馆陈列光，平衡曝光',
}

const dynastyStyleMap = {
  汉: '汉代风格，雄浑朴茂，礼制器感',
  东汉: '东汉风格，厚重沉稳，纹饰凝练',
  战国: '战国风格，线条劲利，纹样秩序强',
  良渚: '良渚风格，神秘庄严，符号化几何纹理',
  唐: '唐代风格，丰润华美，气象开阔',
  宋: '宋代风格，清雅内敛，极简与留白',
  明: '明代风格，工整细密，器形端正',
  清: '清代风格，精工细作，收藏级质感',
  西周: '西周风格，古朴凝练，礼器感明确',
  南朝: '南朝风格，柔雅流动，线条圆融',
}

function buildCraftText(jade) {
  const name = jade?.name || ''
  if (name.includes('璧')) {
    return '强调环形中孔结构，边缘修磨细致，礼器比例严谨'
  }
  if (name.includes('琮')) {
    return '方外圆内结构，棱角与转折清晰，神人纹刻画克制'
  }
  if (name.includes('佩') || name.includes('珮')) {
    return '佩饰尺度精巧，穿系孔与边缘过渡自然，便于贴身佩戴'
  }
  if (name.includes('环') || name.includes('璜')) {
    return '弧线连贯，重心稳定，弯月式器形流畅'
  }
  return '遵循古玉工艺，阴刻线与浅浮雕结合，保留包浆与岁月痕迹'
}

function sanitizeText(value, fallback) {
  const v = String(value || '').trim()
  return v || fallback
}

export function buildImagePrompt({ answers, jade, emotion }) {
  const dynasty = sanitizeText(jade?.dynasty, '古代')
  const name = sanitizeText(jade?.name, '古玉')
  const description = sanitizeText(jade?.description, '古玉器物，温润雅正')

  const color = colorMap[answers.color] || '青白玉色，温润含光'
  const symbol = symbolMap[answers.symbol] || '古玉纹饰，层次分明'
  const landscape = landscapeMap[answers.landscape] || '东方山水肌理'
  const mood = moodMap[answers.mood] || '温润内敛'
  const texture = textureMap[answers.texture] || '细腻温润'
  const emotionText = emotionMap[emotion] || emotionMap.neutral
  const dynastyStyle = dynastyStyleMap[dynasty] || `${dynasty}代审美，古雅庄重`
  const craftText = buildCraftText(jade)

  return [
    `${dynasty}${name}`,
    description,
    dynastyStyle,
    color,
    symbol,
    landscape,
    texture,
    mood,
    emotionText,
    craftText,
    '中国古玉，博物馆级陈列摄影风格，超高细节，8k，微距质感，柔和体积光',
    '背景简洁留白，主体居中，材质真实，玉石半透明，边缘高光克制',
    '无现代金属配件，无文字水印，无英文字符，无塑料感，无卡通风格',
  ].join('，')
}
