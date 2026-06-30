import { AppPreferences } from '../storage/AppPreferences';
import { OnboardingPage } from '../components/onboarding/OnboardingPage';
import { ShellPage } from '../components/shell/ShellPage';
import { UMengAnalytics } from '../ad/UMengAnalytics';
import { GroMoreAdManager } from '../ad/GroMoreAdManager';
import { GroMoreSplashAdManager } from '../ad/GroMoreSplashAdManager';

const SPLASH_TIMEOUT_FALLBACK_MS = 5000;

/**
 * 对应 iOS ContentView.swift：隐私协议门槛 → （仅同意后）初始化统计/广告 SDK → 开屏广告 → 主界面。
 * 鸿蒙没有 iOS ATT 那一步（App Tracking Transparency 是 iOS 专属概念），其余流程与 iOS 版一致：
 * 友盟统计、GroMore 开屏广告都只在用户同意隐私政策后才会初始化。
 */
@Entry
@Component
struct Index {
  @State private onboardingCompleted: boolean = AppPreferences.shared.onboardingCompleted;
  @State private isWaitingForSplashAd: boolean = false;
  @State private showSkipButton: boolean = false;
  private didRequestSplashAd: boolean = false;

  aboutToAppear(): void {
    if (this.onboardingCompleted) {
      this.isWaitingForSplashAd = GroMoreSplashAdManager.shared.shouldRequestSplashThisSession;
      this.initializeSdksAndProceed();
    }
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
          this.isWaitingForSplashAd = GroMoreSplashAdManager.shared.shouldRequestSplashThisSession;
          this.initializeSdksAndProceed();
        }
      })
    }
  }

  private initializeSdksAndProceed(): void {
    // 隐私协议已同意（首次同意 or 此前已同意过），这里才允许初始化统计/广告 SDK。
    UMengAnalytics.shared.initialize();
    this.requestSplashAdIfNeeded();
  }

  @Builder
  private splashWaitPage() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.White)

      if (this.showSkipButton) {
        Row() {
          Text('跳过')
            .fontSize(13)
            .fontFamily('MiSans')
            .fontColor('#666666')
            .padding({ left: 16, right: 16 })
            .height(34)
            .backgroundColor('rgba(0,0,0,0.08)')
            .borderRadius(17)
            .onClick(() => {
              this.isWaitingForSplashAd = false;
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
        .padding({ right: 20, top: 56 })
      }
    }
    .width('100%')
    .height('100%')
  }

  private requestSplashAdIfNeeded(): void {
    if (this.didRequestSplashAd || !GroMoreSplashAdManager.shared.shouldRequestSplashThisSession) {
      this.isWaitingForSplashAd = false;
      return;
    }
    this.didRequestSplashAd = true;
    setTimeout(() => { this.showSkipButton = true; }, 1500);

    setTimeout(() => {
      if (this.isWaitingForSplashAd) {
        this.isWaitingForSplashAd = false;
      }
    }, SPLASH_TIMEOUT_FALLBACK_MS);

    GroMoreAdManager.shared.initialize((success: boolean) => {
      if (!success) {
        this.isWaitingForSplashAd = false;
        return;
      }
      GroMoreSplashAdManager.shared.loadAndShowDefaultSplashAd(() => {
        this.isWaitingForSplashAd = false;
      });
    });
  }
}
