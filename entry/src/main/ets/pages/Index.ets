import { router } from '@kit.ArkUI';
import { OnboardingPage } from '../components/onboarding/OnboardingPage';
import { PRIVACY_CONSENT_GRANTED_EVENT } from '../common/PrivacyConsent';
import { WindowStageHolder } from '../common/WindowStageHolder';
import { AppPreferences } from '../storage/AppPreferences';

/**
 * 独立隐私入口：此页面禁止导入 Shell、广告、统计、支付和 Tuanjie 模块。
 */
@Entry
@Component
struct Index {
  @State private isNavigating: boolean = false;

  build() {
    Stack() {
      OnboardingPage({
        onContinue: () => {
          if (this.isNavigating) {
            return;
          }
          this.isNavigating = true;
          // 必须先持久化同意状态，再通知 Ability/加载主页面和所有三方模块。
          AppPreferences.shared.onboardingCompleted = true;
          WindowStageHolder.abilityContext?.eventHub.emit(PRIVACY_CONSENT_GRANTED_EVENT);
          router.replaceUrl({ url: 'pages/MainPage' }).catch((error: Error) => {
            this.isNavigating = false;
            console.warn(`[Privacy] 主页面跳转失败 ${error.message}`);
          });
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
