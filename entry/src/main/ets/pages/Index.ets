import { AppPreferences } from '../storage/AppPreferences';
import { OnboardingPage } from '../components/onboarding/OnboardingPage';
import { ShellPage } from '../components/shell/ShellPage';

/**
 * 对应 iOS ContentView.swift（不含广告/统计 SDK 相关逻辑，已与用户确认跳过）。
 */
@Entry
@Component
struct Index {
  @State private onboardingCompleted: boolean = AppPreferences.shared.onboardingCompleted;

  build() {
    if (this.onboardingCompleted) {
      ShellPage()
    } else {
      OnboardingPage({
        onContinue: () => {
          AppPreferences.shared.onboardingCompleted = true;
          this.onboardingCompleted = true;
        }
      })
    }
  }
}
