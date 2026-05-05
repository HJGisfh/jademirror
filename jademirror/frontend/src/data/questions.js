export const VECTOR_KEYS = [
  'EI', 'SN', 'TF', 'JP',
  'Openness', 'Conscientiousness', 'Extraversion', 'Agreeableness', 'Neuroticism',
  'Warrior', 'Sage', 'Explorer', 'Mediator', 'Creator', 'Ruler', 'Healer',
]

export const VECTOR_LABELS = {
  EI: '外倾 ↔ 内倾',
  SN: '实感 ↔ 直觉',
  TF: '思考 ↔ 情感',
  JP: '判断 ↔ 感知',
  Openness: '开放性',
  Conscientiousness: '尽责性',
  Extraversion: '外倾性',
  Agreeableness: '宜人性',
  Neuroticism: '神经质',
  Warrior: '战士',
  Sage: '智者',
  Explorer: '探索者',
  Mediator: '调停者',
  Creator: '创造者',
  Ruler: '统治者',
  Healer: '治愈者',
}

export const MBTI_DIMS = ['EI', 'SN', 'TF', 'JP']
export const BIG5_DIMS = ['Openness', 'Conscientiousness', 'Extraversion', 'Agreeableness', 'Neuroticism']
export const ARCHETYPE_DIMS = ['Warrior', 'Sage', 'Explorer', 'Mediator', 'Creator', 'Ruler', 'Healer']

export function createZeroVector() {
  return Object.fromEntries(VECTOR_KEYS.map((k) => [k, 0]))
}

export const deepTestQuestions = [
  {
    id: 'q1',
    module: 'core',
    moduleTitle: '核心驱动力与荣格原型',
    title: '若你穿越回古代，必须选择一种身份度过一生，你会选择？',
    subtitle: '动机与原型',
    options: [
      {
        value: 'A', label: '镇守边疆的武将', description: '掌握天下兵马，守护一方安宁',
        tone: '#8a7b6b',
        vector: { EI: 2, Extraversion: 2, Warrior: 2 },
      },
      {
        value: 'B', label: '编纂奇书的隐士', description: '隐居深山，著书立说，洞察天理',
        tone: '#7a9b8a',
        vector: { EI: -2, Openness: 2, Sage: 2 },
      },
      {
        value: 'C', label: '记录风土的游医', description: '游历四方，采药问俗，济世行脚',
        tone: '#9ba87a',
        vector: { EI: 1, Openness: 2, Explorer: 2 },
      },
      {
        value: 'D', label: '调和朝堂的贤相', description: '辅佐帝王，化解纷争，安邦定国',
        tone: '#a89882',
        vector: { Agreeableness: 2, Conscientiousness: 2, Mediator: 2 },
      },
    ],
  },
  {
    id: 'q2',
    module: 'core',
    moduleTitle: '核心驱动力与荣格原型',
    title: '面对一件浑然天成但有一道明显裂纹的璞玉，你认为它最大的价值在于？',
    subtitle: '本真与创造',
    options: [
      {
        value: 'A', label: '裂纹即自然印记', description: '大地孕育的痕迹，无需修饰便已完满',
        tone: '#8ea596',
        vector: { Openness: 2, SN: -1 },
      },
      {
        value: 'B', label: '俏色化裂纹为绝唱', description: '以巧思将瑕疵变为独一无二的艺术',
        tone: '#b29493',
        vector: { SN: -2, Creator: 2, Openness: 1 },
      },
      {
        value: 'C', label: '打磨出纯净核心', description: '剥离杂质，留下最纯粹的本质',
        tone: '#9bb0b4',
        vector: { Conscientiousness: 2, JP: 2 },
      },
      {
        value: 'D', label: '大成若缺的哲理', description: '残缺本身便是世间最深的智慧',
        tone: '#a0b58c',
        vector: { SN: -2, Sage: 1, Openness: 1 },
      },
    ],
  },
  {
    id: 'q3',
    module: 'core',
    moduleTitle: '核心驱动力与荣格原型',
    title: '在一片未知的迷雾森林中，最让你感到安心的是？',
    subtitle: '安全感来源',
    options: [
      {
        value: 'A', label: '削铁如泥的利刃', description: '手中握有力量，便无惧未知',
        tone: '#6a8b98',
        vector: { SN: 2, JP: 1, Warrior: 1 },
      },
      {
        value: 'B', label: '清晰的星象方位', description: '知识是最可靠的指引，理性照亮前路',
        tone: '#9ea7c8',
        vector: { SN: -2, TF: 1, Sage: 1 },
      },
      {
        value: 'C', label: '默契的同路同伴', description: '有人并肩而行，便不惧风雨',
        tone: '#b29493',
        vector: { TF: -2, Agreeableness: 2 },
      },
      {
        value: 'D', label: '迷雾终散的信念', description: '只要前行，一切终将明朗',
        tone: '#c0c5d8',
        vector: { JP: -2, Openness: 2, Explorer: 1 },
      },
    ],
  },
  {
    id: 'q4',
    module: 'core',
    moduleTitle: '核心驱动力与荣格原型',
    title: '若要你在一块玉牌上留下铭文，你更倾向于哪种内容？',
    subtitle: '价值投射',
    options: [
      {
        value: 'A', label: '威严法度与规则', description: '不可僭越的秩序，是世间安定的根基',
        tone: '#88a79a',
        vector: { JP: 2, Ruler: 2, Conscientiousness: 1 },
      },
      {
        value: 'B', label: '顿悟的缥缈诗句', description: '一次灵光乍现的记录，胜过千言万语',
        tone: '#c0c5d8',
        vector: { SN: -2, Openness: 2 },
      },
      {
        value: 'C', label: '祈求平安的祝词', description: '愿岁月静好，家人无恙，人间值得',
        tone: '#d2ae74',
        vector: { TF: -2, Agreeableness: 2, Healer: 1 },
      },
      {
        value: 'D', label: '只有自己懂的图腾', description: '一个隐秘的符号，承载只有自己理解的意义',
        tone: '#7a9b8a',
        vector: { EI: -2, Explorer: 1, Openness: 1 },
      },
    ],
  },
  {
    id: 'q5',
    module: 'perception',
    moduleTitle: '信息感知与能量流动',
    title: '参加一场古代名流云集的"曲水流觞"雅集，你的常态是？',
    subtitle: '社交能量',
    options: [
      {
        value: 'A', label: '主导话题，享受交锋', description: '在人群中心，思想碰撞令你兴奋',
        tone: '#c57f67',
        vector: { EI: 2, Extraversion: 2 },
      },
      {
        value: 'B', label: '与一两人低声深聊', description: '气味相投之人，才值得敞开心扉',
        tone: '#b29493',
        vector: { EI: -1, TF: -1, Agreeableness: 1 },
      },
      {
        value: 'C', label: '独自观察，若有所思', description: '看水流与宾客神态，在沉默中思考',
        tone: '#9ea7c8',
        vector: { EI: -2, SN: -1 },
      },
      {
        value: 'D', label: '关注酒食与陈设细节', description: '器物之美与工艺之精，更令你驻足',
        tone: '#d2ae74',
        vector: { EI: -1, SN: 1 },
      },
    ],
  },
  {
    id: 'q6',
    module: 'perception',
    moduleTitle: '信息感知与能量流动',
    title: '阅读一本晦涩的古籍时，最吸引你的部分是？',
    subtitle: '认知偏好',
    options: [
      {
        value: 'A', label: '解决当下困境的方法', description: '实用为先，知识应当服务于现实',
        tone: '#88a79a',
        vector: { SN: 2 },
      },
      {
        value: 'B', label: '宏大世界观的透露', description: '字里行间那个时代的思想版图',
        tone: '#9ea7c8',
        vector: { SN: -2, Openness: 1 },
      },
      {
        value: 'C', label: '人物的悲欢离合', description: '历史洪流中个体的命运与情感',
        tone: '#b29493',
        vector: { TF: -2, Agreeableness: 1 },
      },
      {
        value: 'D', label: '纸张质感与古人批注', description: '物质载体本身，也是一段沉默的历史',
        tone: '#d2ae74',
        vector: { SN: 1, Openness: 1 },
      },
    ],
  },
  {
    id: 'q7',
    module: 'perception',
    moduleTitle: '信息感知与能量流动',
    title: '当你需要恢复精力时，你更倾向于？',
    subtitle: '能量来源',
    options: [
      {
        value: 'A', label: '热闹集市感受烟火', description: '人间喧嚣是最真实的生命力',
        tone: '#c57f67',
        vector: { EI: 2, Extraversion: 2 },
      },
      {
        value: 'B', label: '安静茶室闭门独处', description: '绝对的安静，才能听见内心的声音',
        tone: '#9ea7c8',
        vector: { EI: -2 },
      },
      {
        value: 'C', label: '野外爬山涉水', description: '让身体与自然对抗，在运动中找回力量',
        tone: '#8a7b6b',
        vector: { EI: 1, SN: 1, Warrior: 1 },
      },
      {
        value: 'D', label: '沉浸专注的手艺', description: '练字、雕刻，在极度专注中忘却时间',
        tone: '#a89882',
        vector: { EI: -1, JP: 1, Conscientiousness: 1, Creator: 1 },
      },
    ],
  },
  {
    id: 'q8',
    module: 'perception',
    moduleTitle: '信息感知与能量流动',
    title: '面对一幅意境深远的留白山水画，你最先注意到？',
    subtitle: '感知焦点',
    options: [
      {
        value: 'A', label: '气势磅礴的主峰', description: '浓墨重彩，一眼便被力量感捕获',
        tone: '#6a8b98',
        vector: { JP: 1, Ruler: 1, Extraversion: 1 },
      },
      {
        value: 'B', label: '留白中的云雾水波', description: '空白处藏着最丰富的想象',
        tone: '#c0c5d8',
        vector: { SN: -2, Openness: 1 },
      },
      {
        value: 'C', label: '画角精细的私人印章', description: '细节之处，方见匠心与岁月',
        tone: '#d2ae74',
        vector: { SN: 2 },
      },
      {
        value: 'D', label: '画面传递的整体情绪', description: '孤独或宁静，情绪是最先抵达的信号',
        tone: '#b29493',
        vector: { TF: -2, Agreeableness: 1, Healer: 1 },
      },
    ],
  },
  {
    id: 'q9',
    module: 'decision',
    moduleTitle: '决策逻辑与共情尺度',
    title: '作为一县之长，面对因灾荒而不得已偷盗粮食的灾民，你会？',
    subtitle: '法理与人情',
    options: [
      {
        value: 'A', label: '按律严惩，私下补偿', description: '法不可违，但人情可在法外周全',
        tone: '#6a8b98',
        vector: { TF: 2, JP: 1 },
      },
      {
        value: 'B', label: '特殊时期，网开一面', description: '律法本为安民，不可刻舟求剑',
        tone: '#b29493',
        vector: { TF: -2, JP: -1, Agreeableness: 1 },
      },
      {
        value: 'C', label: '开仓放粮，以劳代赈', description: '解决根源问题，同时维护制度尊严',
        tone: '#88a79a',
        vector: { TF: 2, SN: -1, Ruler: 1 },
      },
      {
        value: 'D', label: '发动募捐，从宽处理', description: '感到痛心，尽全力在制度内寻找温度',
        tone: '#d2ae74',
        vector: { TF: -2, Agreeableness: 2, Healer: 1 },
      },
    ],
  },
  {
    id: 'q10',
    module: 'decision',
    moduleTitle: '决策逻辑与共情尺度',
    title: '在团队中讨论一个重要项目的方向时，你通常是？',
    subtitle: '团队角色',
    options: [
      {
        value: 'A', label: '坚定的捍卫者', description: '用严密逻辑驳倒不合理提议，捍卫正确方向',
        tone: '#6a8b98',
        vector: { TF: 2, Agreeableness: -1 },
      },
      {
        value: 'B', label: '敏锐的倾听者', description: '发现矛盾点，调和大家意见，寻求共识',
        tone: '#b29493',
        vector: { TF: -2, Agreeableness: 2, Mediator: 1 },
      },
      {
        value: 'C', label: '创新的破局者', description: '提出大家没想到的全新角度，打破僵局',
        tone: '#9ea7c8',
        vector: { SN: -2, Openness: 2, Explorer: 1 },
      },
      {
        value: 'D', label: '务实的执行者', description: '关心提议能否按时落地，拒绝空中楼阁',
        tone: '#88a79a',
        vector: { SN: 2, JP: 2, Conscientiousness: 1 },
      },
    ],
  },
  {
    id: 'q11',
    module: 'decision',
    moduleTitle: '决策逻辑与共情尺度',
    title: '如果有人误解了你的一个极其重要的决定，你的第一反应是？',
    subtitle: '自我边界',
    options: [
      {
        value: 'A', label: '结果正确，无需解释', description: '时间会证明一切，解释是多余的消耗',
        tone: '#6a8b98',
        vector: { TF: 2, Agreeableness: -1 },
      },
      {
        value: 'B', label: '内耗委屈，渴望澄清', description: '被误解的痛苦会持续很久，难以释怀',
        tone: '#c57f67',
        vector: { TF: -2, Neuroticism: 2 },
      },
      {
        value: 'C', label: '平静梳理，事实证明', description: '用数据和逻辑向对方证明，情绪不是工具',
        tone: '#88a79a',
        vector: { TF: 1, JP: 1 },
      },
      {
        value: 'D', label: '常态如此，无需强求', description: '人与人本就无法完全理解，接受即可',
        tone: '#9ea7c8',
        vector: { EI: -2, Sage: 1 },
      },
    ],
  },
  {
    id: 'q12',
    module: 'decision',
    moduleTitle: '决策逻辑与共情尺度',
    title: '评价一段历史时，你更看重？',
    subtitle: '价值取向',
    options: [
      {
        value: 'A', label: '制度与科技的进步', description: '经济的变革与技术的演进，推动文明前行',
        tone: '#88a79a',
        vector: { TF: 2, SN: -1 },
      },
      {
        value: 'B', label: '文学与思想的解放', description: '民间风貌与精神自由，才是文明的底色',
        tone: '#b29493',
        vector: { TF: -2, Openness: 1 },
      },
      {
        value: 'C', label: '权谋博弈与宏大战略', description: '帝王将相的决策，塑造了历史的走向',
        tone: '#6a8b98',
        vector: { TF: 1, Ruler: 1 },
      },
      {
        value: 'D', label: '普通人的真实命运', description: '被正史忽略的芸芸众生，才是历史的真相',
        tone: '#d2ae74',
        vector: { TF: -1, Agreeableness: 1, Healer: 1 },
      },
    ],
  },
  {
    id: 'q13',
    module: 'order',
    moduleTitle: '秩序感与压力边界',
    title: '计划一次长途远行，你的行囊和行程通常是？',
    subtitle: '秩序偏好',
    options: [
      {
        value: 'A', label: '详细清单，按部就班', description: '提前预定所有客栈，行程精确到时辰',
        tone: '#88a79a',
        vector: { JP: 2, Conscientiousness: 2 },
      },
      {
        value: 'B', label: '确定方向，随心而行', description: '带上必需品，随时根据心情改变路线',
        tone: '#c0c5d8',
        vector: { JP: -2, Openness: 2, Explorer: 1 },
      },
      {
        value: 'C', label: '粗略框架，保留随机', description: '一半计划一半随机，应对突发也有底气',
        tone: '#9ea7c8',
        vector: { Openness: 1 },
      },
      {
        value: 'D', label: '极度精简，到了再筹', description: '行囊最简，到了目的地再随机应变',
        tone: '#a0b58c',
        vector: { JP: -1, Explorer: 2 },
      },
    ],
  },
  {
    id: 'q14',
    module: 'order',
    moduleTitle: '秩序感与压力边界',
    title: '当突发变故彻底打乱了你原本完美的计划时，你的内部状态是？',
    subtitle: '压力反应',
    options: [
      {
        value: 'A', label: '屏蔽情绪，计算方案', description: '大脑立刻切换到应急模式，效率优先',
        tone: '#6a8b98',
        vector: { TF: 2, Neuroticism: -2 },
      },
      {
        value: 'B', label: '烦躁不适，需要时间', description: '失控感强烈，需要一段时间才能接受',
        tone: '#c57f67',
        vector: { Neuroticism: 2, JP: 1 },
      },
      {
        value: 'C', label: '觉得刺激，迎接挑战', description: '变故反而激活了你的斗志和好奇心',
        tone: '#9ea7c8',
        vector: { Openness: 2, JP: -1, Explorer: 1 },
      },
      {
        value: 'D', label: '顺其自然，最好安排', description: '一切都是最好的安排，无需焦虑',
        tone: '#b29493',
        vector: { Agreeableness: 1, JP: -2, Mediator: 1 },
      },
    ],
  },
  {
    id: 'q15',
    module: 'order',
    moduleTitle: '秩序感与压力边界',
    title: '你理想中的书房或工作台是怎样的？',
    subtitle: '空间秩序',
    options: [
      {
        value: 'A', label: '井井有条，绝对整洁', description: '所有物件有固定位置，一丝不苟',
        tone: '#88a79a',
        vector: { JP: 2, Conscientiousness: 2 },
      },
      {
        value: 'B', label: '看似杂乱，自有秩序', description: '别人看不懂，但自己清楚每样东西在哪',
        tone: '#a0b58c',
        vector: { JP: -2 },
      },
      {
        value: 'C', label: '摆满灵感小物件', description: '各种古怪艺术品和奇趣物件激发创意',
        tone: '#9ea7c8',
        vector: { Openness: 2, SN: -1, Creator: 1 },
      },
      {
        value: 'D', label: '极简到极致', description: '除了当前正在做的事，别无他物',
        tone: '#d9d8d4',
        vector: { JP: 1, EI: -1 },
      },
    ],
  },
  {
    id: 'q16',
    module: 'order',
    moduleTitle: '秩序感与压力边界',
    title: '夜深人静，当你凝视一块古玉时，你觉得它更像你的什么？',
    subtitle: '自我映照',
    options: [
      {
        value: 'A', label: '一面镜子', description: '映照出我最核心的原则与底线',
        tone: '#9bb0b4',
        vector: { JP: 2, Conscientiousness: 1 },
      },
      {
        value: 'B', label: '一个容器', description: '承载了我所有无法向外人道的情绪',
        tone: '#b29493',
        vector: { TF: -2, Neuroticism: 1, Healer: 1 },
      },
      {
        value: 'C', label: '一扇门', description: '连接着超越世俗的广阔精神世界',
        tone: '#9ea7c8',
        vector: { SN: -2, Openness: 2, Sage: 1 },
      },
      {
        value: 'D', label: '一把剑', description: '时刻提醒我保持清醒与锋芒',
        tone: '#6a8b98',
        vector: { TF: 2, Agreeableness: -1, Warrior: 1 },
      },
    ],
  },
]

export const quickTestQuestions = [
  {
    id: 'fq1',
    module: 'openness',
    moduleTitle: '开放性 / S-N维度',
    title: '在博物馆，你被一件古器物深深吸引，通常是因为它：',
    subtitle: '感知维度',
    options: [
      {
        value: 'A', label: '雕工巧夺天工', description: '材质万里挑一，工艺令人叹服',
        tone: '#88a79a',
        vector: { SN: 2, Openness: -1 },
      },
      {
        value: 'B', label: '造型奇特诡异', description: '似乎隐藏着上古的神话密码',
        tone: '#9ea7c8',
        vector: { SN: -2, Openness: 2 },
      },
      {
        value: 'C', label: '重大历史的见证', description: '某个王朝兴衰的实物印记',
        tone: '#6a8b98',
        vector: { SN: -1, Openness: 1, Ruler: 1 },
      },
      {
        value: 'D', label: '线条流畅柔美', description: '整体给人一种安宁的抚慰感',
        tone: '#b29493',
        vector: { TF: -1, Openness: 1, Agreeableness: 1 },
      },
    ],
  },
  {
    id: 'fq2',
    module: 'agreeableness',
    moduleTitle: '宜人性 / T-F维度',
    title: '面对人际交往中不可避免的冲突，你的本能反应是：',
    subtitle: '共情尺度',
    options: [
      {
        value: 'A', label: '像刀锋划清界限', description: '对错比关系更重要，原则不可退让',
        tone: '#6a8b98',
        vector: { TF: 2, Agreeableness: -2 },
      },
      {
        value: 'B', label: '像水一样包容化解', description: '寻找双方都能接受的折中点',
        tone: '#95b7c8',
        vector: { TF: -2, Agreeableness: 2, Mediator: 1 },
      },
      {
        value: 'C', label: '像旁观者抽离', description: '情绪对立毫无意义，理性看待即可',
        tone: '#9ea7c8',
        vector: { TF: 1, EI: -1, Sage: 1 },
      },
      {
        value: 'D', label: '像火一样直接表达', description: '迅速爆发也迅速翻篇，不憋着',
        tone: '#c57f67',
        vector: { TF: 1, Agreeableness: -1, EI: 1, Warrior: 1 },
      },
    ],
  },
  {
    id: 'fq3',
    module: 'archetype',
    moduleTitle: '荣格原型 · 动机投射',
    title: '如果只能拥有一种超能力，你希望是：',
    subtitle: '核心原型',
    options: [
      {
        value: 'A', label: '洞悉万物底层规律', description: '看透世间一切运转的本质法则',
        tone: '#9ea7c8',
        vector: { Sage: 2, SN: -1, EI: -1 },
      },
      {
        value: 'B', label: '疗愈他人的伤痛', description: '治愈身体与灵魂深处的创痕',
        tone: '#b29493',
        vector: { Healer: 2, TF: -2, Agreeableness: 1 },
      },
      {
        value: 'C', label: '改变规则的绝对力量', description: '建立新秩序，重塑世界的运行方式',
        tone: '#6a8b98',
        vector: { Ruler: 2, TF: 1, EI: 1, JP: 1 },
      },
      {
        value: 'D', label: '体验所有不同人生', description: '在无数种截然不同的存在中穿梭',
        tone: '#a0b58c',
        vector: { Explorer: 2, EI: 1, Openness: 2 },
      },
    ],
  },
  {
    id: 'fq4',
    module: 'neuroticism',
    moduleTitle: '神经质 / 压力反应',
    title: '当你处于长期高压或极度疲惫时，你的"阴暗面"会表现为：',
    subtitle: '压力边界',
    options: [
      {
        value: 'A', label: '极度专断苛刻', description: '对周围人的容错率降到冰点，一切必须按规矩来',
        tone: '#6a8b98',
        vector: { Neuroticism: -1, TF: 1, JP: 1, Agreeableness: -1 },
      },
      {
        value: 'B', label: '彻底自我封闭', description: '切断所有联系，对外界失去兴趣',
        tone: '#9ea7c8',
        vector: { Neuroticism: 1, EI: -2 },
      },
      {
        value: 'C', label: '深深的自我怀疑', description: '陷入无休止的内耗纠结，无法自拔',
        tone: '#c57f67',
        vector: { Neuroticism: 2, TF: -1 },
      },
      {
        value: 'D', label: '放纵感官刺激', description: '冲动消费或感官麻痹，试图逃避压力',
        tone: '#c57f67',
        vector: { Neuroticism: 1, SN: 1, JP: -1 },
      },
    ],
  },
  {
    id: 'fq5',
    module: 'jp',
    moduleTitle: 'J-P维度 / 秩序感',
    title: '你更喜欢自己的人生呈现哪种状态？',
    subtitle: '秩序偏好',
    options: [
      {
        value: 'A', label: '结构严谨的古塔', description: '步步为营，根基深厚，层层递进',
        tone: '#88a79a',
        vector: { JP: 2, Conscientiousness: 2 },
      },
      {
        value: 'B', label: '蜿蜒不知去向的溪流', description: '随山势而行，随遇而安，不知终点',
        tone: '#95b7c8',
        vector: { JP: -2, Openness: 1 },
      },
      {
        value: 'C', label: '留白极多的宣纸', description: '随时可以添上新的一笔，充满可能',
        tone: '#c0c5d8',
        vector: { JP: -1, Openness: 2, Creator: 1 },
      },
      {
        value: 'D', label: '时刻打磨的宝剑', description: '锋利待出鞘，随时准备应对一切',
        tone: '#6a8b98',
        vector: { JP: 1, Warrior: 1, Conscientiousness: 1 },
      },
    ],
  },
  {
    id: 'fq6',
    module: 'integration',
    moduleTitle: '自我同一性整合',
    title: '纵观你的内心，你觉得目前最缺失、也最渴望寻回的特质是：',
    subtitle: '深层渴望',
    options: [
      {
        value: 'A', label: '纯粹与柔软', description: '卸下防备，回归最本真的温柔',
        tone: '#b29493',
        vector: { TF: -1, Agreeableness: 1 },
      },
      {
        value: 'B', label: '坚定与力量', description: '不再犹豫，拥有不可动摇的决断力',
        tone: '#6a8b98',
        vector: { TF: 1, JP: 1 },
      },
      {
        value: 'C', label: '轻盈与松弛', description: '放下执念，让生命重新流动起来',
        tone: '#c0c5d8',
        vector: { JP: -1, Openness: 1 },
      },
      {
        value: 'D', label: '专注与沉静', description: '在喧嚣中守住内心的定力',
        tone: '#9ea7c8',
        vector: { EI: -1, Conscientiousness: 1 },
      },
    ],
  },
]

export const DEEP_TEST_MODULES = [
  { key: 'core', label: '壹', title: '核心驱动力与荣格原型', range: [0, 3] },
  { key: 'perception', label: '贰', title: '信息感知与能量流动', range: [4, 7] },
  { key: 'decision', label: '叁', title: '决策逻辑与共情尺度', range: [8, 11] },
  { key: 'order', label: '肆', title: '秩序感与压力边界', range: [12, 15] },
]

export const emotionLabelMap = {
  happy: '愉悦',
  sad: '沉静',
  angry: '刚毅',
  surprised: '灵动',
  neutral: '平和',
}
