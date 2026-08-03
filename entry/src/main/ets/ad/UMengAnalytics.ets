/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { init, agree, setLogEnabled, trackEvent } from '@umeng/analytics';
import { AppPreferences } from '../storage/AppPreferences';

export class UMengAnalytics {
  private static instance: UMengAnalytics | null = null;
  private isInitialized: boolean = false;
  private isInitializing: boolean = false;

  static get shared(): UMengAnalytics {
    if (UMengAnalytics.instance === null) {
      UMengAnalytics.instance = new UMengAnalytics();
    }
    return UMengAnalytics.instance;
  }

  async initialize(): Promise<void> {
    if (!AppPreferences.shared.onboardingCompleted) {
      console.warn('[UMengAnalytics] 用户未同意隐私政策，禁止初始化统计 SDK');
      return;
    }

    if (this.isInitialized || this.isInitializing) {
      return;
    }

    this.isInitializing = true;
    try {
      // 调用方只会在用户同意隐私政策后调用 initialize()。
      agree();
      setLogEnabled(false);
      await init();
      this.isInitialized = true;
      console.log('[UMengAnalytics] 初始化成功');
    } catch (error) {
      console.warn(`[UMengAnalytics] 初始化失败 ${error}`);
    } finally {
      this.isInitializing = false;
    }
  }

  logEvent(eventId: string, attributes?: Record<string, string>): void {
    if (!this.isInitialized) {
      return;
    }
    trackEvent(eventId, attributes);
  }
}
