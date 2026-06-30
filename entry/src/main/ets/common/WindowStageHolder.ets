/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

/**
 * 开屏广告（GroMore）需要 WindowStage/UIAbilityContext 才能展示，
 * 但广告管理类是普通单例（不是 @Component），拿不到 this.getUIContext()，
 * 所以在 EntryAbility.onWindowStageCreate 里把这些引用存一份在这里，供 ad/ 目录下的管理类使用。
 */
export class WindowStageHolder {
  static windowStage: window.WindowStage | null = null;
  static abilityContext: common.UIAbilityContext | null = null;
}
