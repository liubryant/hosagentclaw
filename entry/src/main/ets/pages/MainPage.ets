import { AppPreferences } from '../storage/AppPreferences';
import { ShellPage } from '../components/shell/ShellPage';
import { SystemBarStyle } from '../common/SystemBarStyle';
import { AppBackNavigator } from '../common/AppBackNavigator';

const SPLASH_TIMEOUT_FALLBACK_MS: number = 8000;

/** 主页面只会在有效隐私授权后由 EntryAbility 或隐私入口加载。 */
@Entry
@Component
struct MainPage {
  @State private isWaitingForSplashAd: boolean = false;
  private didRequestSplashAd: boolean = false;
  private isInitializingSdks: boolean = false;

  aboutToAppear(): void {
    // Tuanjie 在隐私同意后接收 WindowStage 生命周期，可能覆盖系统栏状态。
    // 主页面显示前立即恢复，避免等待广告模块异步加载期间隐藏时间和图标。
    SystemBarStyle.applyTabStatusBar();
    this.initializeSdksAndProceed();
  }

  onBackPress(): boolean {
    return AppBackNavigator.handleBack();
  }

  build() {
    Stack() {
      if (this.isWaitingForSplashAd) {
        this.splashWaitPage()
      } else {
        ShellPage()
      }
    }
    .width('100%')
    .height('100%')
  }

  private initializeSdksAndProceed(): void {
    if (!AppPreferences.shared.onboardingCompleted || this.isInitializingSdks) {
      return;
    }
    this.isInitializingSdks = true;

    // 只有 MainPage 才能加载统计和广告模块，而 MainPage 只在隐私同意后进入。
    import('../ad/UMengAnalytics').then((analyticsModule) => {
      analyticsModule.UMengAnalytics.shared.initialize();
    }).catch((error: Error) => {
      console.warn(`[MainPage] 友盟统计模块加载失败 ${error.message}`);
    });

    import('../ad/GroMoreSplashAdManager').then((splashModule) => {
      if (!splashModule.GroMoreSplashAdManager.shared.shouldRequestSplashThisSession) {
        this.isWaitingForSplashAd = false;
        SystemBarStyle.applyTabStatusBar();
        return;
      }
      this.isWaitingForSplashAd = true;
      this.requestSplashAdIfNeeded();
    }).catch((error: Error) => {
      console.warn(`[MainPage] 广告模块加载失败 ${error.message}`);
      this.isWaitingForSplashAd = false;
      SystemBarStyle.applyTabStatusBar();
    }).finally(() => {
      this.isInitializingSdks = false;
    });
  }

  @Builder
  private splashWaitPage() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
  }

  private requestSplashAdIfNeeded(): void {
    if (!AppPreferences.shared.onboardingCompleted || this.didRequestSplashAd) {
      this.isWaitingForSplashAd = false;
      SystemBarStyle.applyTabStatusBar();
      return;
    }
    this.didRequestSplashAd = true;
    SystemBarStyle.applySplash();

    setTimeout(() => {
      if (this.isWaitingForSplashAd) {
        this.isWaitingForSplashAd = false;
        SystemBarStyle.applyTabStatusBar();
      }
    }, SPLASH_TIMEOUT_FALLBACK_MS);

    import('../ad/GroMoreAdManager').then((adModule) => {
      adModule.GroMoreAdManager.shared.initialize((success: boolean) => {
        if (!success) {
          this.isWaitingForSplashAd = false;
          SystemBarStyle.applyTabStatusBar();
          return;
        }
        import('../ad/GroMoreSplashAdManager').then((splashModule) => {
          splashModule.GroMoreSplashAdManager.shared.loadAndShowDefaultSplashAd(() => {
            this.isWaitingForSplashAd = false;
            SystemBarStyle.applyTabStatusBar();
          });
        }).catch((error: Error) => {
          console.warn(`[MainPage] 开屏广告模块加载失败 ${error.message}`);
          this.isWaitingForSplashAd = false;
          SystemBarStyle.applyTabStatusBar();
        });
      });
    }).catch((error: Error) => {
      console.warn(`[MainPage] 广告 SDK 模块加载失败 ${error.message}`);
      this.isWaitingForSplashAd = false;
      SystemBarStyle.applyTabStatusBar();
    });
  }
}
