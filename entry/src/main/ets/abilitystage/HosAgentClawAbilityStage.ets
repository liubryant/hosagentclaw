import { AbilityStage } from '@kit.AbilityKit';

export default class HosAgentClawAbilityStage extends AbilityStage {
  // 禁止在 AbilityStage 启动阶段导入或初始化任何第三方统计、广告 SDK。
  // 相关 SDK 统一在用户明确同意隐私政策后动态加载并初始化。
}
