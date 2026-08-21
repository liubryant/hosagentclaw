/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { AppPreferences } from '../storage/AppPreferences';
import { OnboardingPage } from '../components/onboarding/OnboardingPage';
import { ShellPage } from '../components/shell/ShellPage';
import { SystemBarStyle } from '../common/SystemBarStyle';
import { AppBackNavigator } from '../common/AppBackNavigator';

const SPLASH_TIMEOUT_FALLBACK_MS = 8000;

@Entry
@Component
struct Index {
  @State private onboardingCompleted: boolean = AppPreferences.shared.onboardingCompleted;
  @State private isWaitingForSplashAd: boolean = false;
  private didRequestSplashAd: boolean = false;
  private isInitializingSdks: boolean = false;

  aboutToAppear(): void {
    if (this.onboardingCompleted) {
      this.initializeSdksAndProceed();
    }
  }

  onBackPress(): boolean {
    return AppBackNavigator.handleBack();
  }

  build() {
    if (this.onboardingCompleted) {
      Stack() {
        if (this.isWaitingForSplashAd) {
          this.splashWaitPage()
        } else {
          ShellPage()
        }
      }
      .width('100%')
      .height('100%')
    } else {
      OnboardingPage({
        onContinue: () => {
          AppPreferences.shared.onboardingCompleted = true;
          this.onboardingCompleted = true;
          this.initializeSdksAndProceed();
        }
      })
    }
  }

  private initializeSdksAndProceed(): void {
    if (!AppPreferences.shared.onboardingCompleted || this.isInitializingSdks) {
      return;
    }
    this.isInitializingSdks = true;

    // 用户同意隐私政策后才动态加载统计/广告模块，避免未同意前触发三方 SDK 的 import/初始化副作用。
    import('../ad/UMengAnalytics').then((analyticsModule) => {
      analyticsModule.UMengAnalytics.shared.initialize();
    }).catch((error: Error) => {
      console.warn(`[Index] 友盟统计模块加载失败 ${error.message}`);
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
      console.warn(`[Index] 广告模块加载失败 ${error.message}`);
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
          console.warn(`[Index] 开屏广告模块加载失败 ${error.message}`);
          this.isWaitingForSplashAd = false;
          SystemBarStyle.applyTabStatusBar();
        });
      });
    }).catch((error: Error) => {
      console.warn(`[Index] 广告 SDK 模块加载失败 ${error.message}`);
      this.isWaitingForSplashAd = false;
      SystemBarStyle.applyTabStatusBar();
    });
  }
}
