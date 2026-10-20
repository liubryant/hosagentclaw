import { AppPreferences } from '../storage/AppPreferences';
import { ShellPage } from '../components/shell/ShellPage';
import { SystemBarStyle } from '../common/SystemBarStyle';
import { AppBackNavigator } from '../common/AppBackNavigator';

/** 主页面只会在有效隐私授权后由 EntryAbility 或隐私入口加载。 */
@Entry
@Component
struct MainPage {
  aboutToAppear(): void {
    // Tuanjie 在隐私同意后接收 WindowStage 生命周期，可能覆盖系统栏状态。
    // 主页面显示前立即恢复，确保时间和系统图标正常显示。
    SystemBarStyle.applyTabStatusBar();
    this.initializeAnalytics();
  }

  onBackPress(): boolean {
    return AppBackNavigator.handleBack();
  }

  build() {
    Stack() {
      ShellPage()
    }
    .width('100%')
    .height('100%')
  }

  private initializeAnalytics(): void {
    if (!AppPreferences.shared.onboardingCompleted) {
      return;
    }

    // MainPage 只在隐私同意后进入，统计模块继续保持动态延迟加载。
    import('../ad/UMengAnalytics').then((analyticsModule) => {
      analyticsModule.UMengAnalytics.shared.initialize();
    }).catch((error: Error) => {
      console.warn(`[MainPage] 友盟统计模块加载失败 ${error.message}`);
    });
  }
}
