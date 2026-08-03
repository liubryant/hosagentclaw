import { AbilityStage } from '@kit.AbilityKit';
import { InternalPlugin, preInit } from '@umeng/analytics';

export default class HosAgentClawAbilityStage extends AbilityStage {
  onCreate(): void {
    // 此处只进行预初始化，不采集或上传数据。
    // 用户同意隐私政策后，才会由 UMengAnalytics.initialize() 调用 init()。
    preInit({
      context: this.context.getApplicationContext(),
      plugins: [new InternalPlugin()]
    });
  }
}
