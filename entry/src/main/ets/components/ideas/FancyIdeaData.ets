/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
export interface FancyIdea {
  id: string;
  title: string;
  subtitle: string;
  prompt: string;
  imageName: ResourceStr;
}

export interface FancyIdeaGroup {
  title: string;
  items: FancyIdea[];
}

interface FancyIdeaContent {
  title: string;
  subtitle: string;
  prompt: string;
}

const CONTENT: FancyIdeaContent[] = [
  { title: '热点资讯自动汇总', subtitle: '还在一条条刷资讯？每日自动整理，不用费心查找，快速看懂当天重点', prompt: '创建每日「8:00」定时任务，自动抓取当日「AI科技」领域全网热点、重要资讯及要闻摘要，整理成简洁的内容，准时推送至我的眼前。' },
  { title: '创业点子可行性验证', subtitle: '有想法不敢下手？帮你快速验证可行性，零成本少踩坑', prompt: '验证AR智能体办公场景自动化助手这个创业点子，从市场需求、竞争格局、成本投入、盈利模式四个维度分析，生成简易可行性报告。' },
  { title: '痛点自动挖掘分析', subtitle: '立项没方向？自动深挖市场痛点，一份报告帮你稳过评审', prompt: '挖掘AR智能体办公场景的核心用户痛点，抓取相关社交平台用户评论和行业数据，分类整理并生成调研简报，支持导出。' },
  { title: '明日运动计划', subtitle: '想运动又怕坚持不下来？每天帮你排好计划，到点喊你动起来', prompt: '我的运动目标是“每天跑步30分钟、每周3次”，生成明日运动计划，设置「18:30」提醒，支持语音打卡，计划可根据反馈调整。' },
  { title: '每日吃什么推荐', subtitle: '饭点不知道吃啥？报口味定位，健康餐单连店带路喂到嘴边', prompt: '推荐今日午餐和晚餐，偏好清淡、不辣、低脂，适合日常居家做法，提供每道菜的简易做法指引，兼顾营养均衡。' },
  { title: '锻炼任务调整', subtitle: '锻炼计划乱了？帮你重新安排锻炼节奏', prompt: '我觉得当前的运动计划太累，时间也不够，调整明日运动计划，将跑步30分钟改为快走20分钟，调整提醒时间为「19:00」。' },
  { title: '目标拆解与打卡', subtitle: '立的flag总倒？把大目标拆成小步骤，每天打卡追踪进度', prompt: '我的大目标是“3个月减肥10斤”，将其拆解为每日小目标（控制饮食、适量运动），支持语音打卡，每周生成减肥进度报表。' },
  { title: '自律习惯管理', subtitle: '好习惯总坚持不了？21天打卡+数据追踪帮你养成好习惯', prompt: '我想养成“每天读书30分钟”的习惯，发起21天打卡挑战，设置「21:00」提醒，支持语音打卡，每日给出鼓励建议，生成打卡数据报表。' },
  { title: '实时天气查询与出行穿搭建议', subtitle: '支持实时温度、湿度、风力、空气质量查询，未来 7 天天气预报，智能穿衣建议及极端天气预警', prompt: '查询北京今日实时天气、未来7天天气预报，结合今日天气给出穿衣建议，若有极端天气及时预警，语音播报结果。' },
  { title: '制定轻量学习规划', subtitle: '一到备考就头大？把你的学习计划烂摊子全甩给我吧', prompt: '制定“备考雅思”的每周学习规划，每日学习1.5小时，重点覆盖听力和阅读，每周日进行一次复盘，计划可灵活调整。' },
  { title: '深度内容讲解', subtitle: '遇到难题卡壳想放弃？帮你拆解卡点，找到破局思路', prompt: '深度讲解AR智能体的光学显示原理，拆解核心卡点，用通俗语言说明，举2个实际应用例子，延伸相关技术发展趋势。' },
  { title: '每日研究简报', subtitle: '漏掉重要论文和行业报告？每天帮你盯着，关键信息一条不漏', prompt: '设置每日「9:00」的自动定时任务，自动抓取“AR/VR领域”的最新论文和行业报告，提炼核心观点生成研究简报，推送到我的眼前。' },
  { title: '科技资讯精选', subtitle: '信息爆炸跟不上？每日精选科技热点，一文掌握行业动态', prompt: '每日推送“AI、AR/VR领域”的精选科技资讯，简洁提炼核心内容，支持语音朗读，每日更新10条。' },
  { title: '懒人出游规划', subtitle: '周末不知道去哪玩？直接喂到你嘴边', prompt: '规划“周末2天北京亲子游”，偏好亲子景点、清淡餐饮，交通优先选择地铁，生成详细路线。' },
  { title: '趣味塔罗小指引', subtitle: '心中有小纠结？塔罗趣味抽牌，给你轻松小参考', prompt: '我纠结“周末要不要去短途旅行”，触发塔罗抽牌，生成1张塔罗牌，给出趣味指引，语气轻松，不涉及封建迷信。' },
  { title: '生辰趣味解读', subtitle: '输入生辰，解锁传统命理文化趣味解读', prompt: '输入我的生辰信息（1998年5月10日），给出趣味解读，内容轻松有趣，规避封建迷信表述，保护我的隐私。' },
  { title: 'MBTI 配对分析', subtitle: '想知道合不合？帮你分析性格契合度', prompt: '我是INFJ，对方是ESTP，分析我们的性格契合度，给出客观温和的相处建议，仅作娱乐参考，不绝对化。' },
  { title: '影视推荐小助手', subtitle: '周末不知道看啥？按口味精准推荐，片源直接给到', prompt: '推荐“豆瓣8分以上、悬疑类型”的影视，优先选择近两年上映的，提供合规观看指引，推荐10部并简要介绍剧情。' },
  { title: '经济数据查询', subtitle: '读懂 GDP、利率、CPI，把握市场关键参考', prompt: '查询中国最新GDP数据、1年期LPR利率，给出通俗解读，对比上月数据，说明变化趋势，语音播报结果。' },
  { title: '量化策略模拟回测', subtitle: '策略靠不靠谱？用历史数据回测验证你的交易策略', prompt: '启动量化策略模拟回测，输入“均线交叉交易策略”（5日均线金叉买入、死叉卖出），用近1年的股票历史数据进行回测，生成简洁适配AR镜片的回测报告，重点展示收益率、风险系数，完成后推送至我的AR镜片。' }
];

function buildAll(): FancyIdea[] {
  return CONTENT.map((item, index): FancyIdea => {
    const number = index + 1;
    const padded = number < 10 ? `0${number}` : `${number}`;
    return {
      id: `fancy_idea_${number}`,
      title: item.title,
      subtitle: item.subtitle,
      prompt: item.prompt,
      imageName: $r(`app.media.idea_${padded}`)
    };
  });
}

export class FancyIdeaStore {
  static readonly all: FancyIdea[] = buildAll();

  static readonly groups: FancyIdeaGroup[] = [
    { title: '高效办公', items: FancyIdeaStore.all.slice(0, 3) },
    { title: '规律生活', items: FancyIdeaStore.all.slice(3, 9) },
    { title: '勤学智助', items: FancyIdeaStore.all.slice(9, 13) },
    { title: '闲趣伴侣', items: FancyIdeaStore.all.slice(13, 18) },
    { title: '财智洞察', items: FancyIdeaStore.all.slice(18, 20) }
  ];
}
