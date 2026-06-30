/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { preInit, init, agree, setLogEnabled, trackEvent } from '@umeng/analytics';
import { UMConfig } from '@umeng/common';
import { AdConfig } from '../common/AdConfig';
import { WindowStageHolder } from '../common/WindowStageHolder';

export class UMengAnalytics {
  private static instance: UMengAnalytics | null = null;
  private isInitialized: boolean = false;

  static get shared(): UMengAnalytics {
    if (UMengAnalytics.instance === null) {
      UMengAnalytics.instance = new UMengAnalytics();
    }
    return UMengAnalytics.instance;
  }

  initialize(): void {
    if (this.isInitialized) {
      return;
    }

    const context = WindowStageHolder.abilityContext;
    if (context === null) {
      console.warn('[UMengAnalytics] abilityContext 尚未就绪，跳过初始化');
      return;
    }

    const config = new UMConfig();
    config.appKey = AdConfig.umengAppKey;
    config.channel = AdConfig.umengChannel;
    config.enableLog = false;
    config.context = context.getApplicationContext();

    preInit(config);
    // 调用方只会在用户同意隐私政策后才调用 initialize()，这里告知 SDK 已获得同意。
    agree();
    setLogEnabled(false);

    init().then(() => {
      console.log('[UMengAnalytics] 初始化成功');
    }).catch((error: Error) => {
      console.warn(`[UMengAnalytics] 初始化失败 ${error.message}`);
    });

    this.isInitialized = true;
  }

  logEvent(eventId: string, attributes?: Record<string, string>): void {
    if (!this.isInitialized) {
      return;
    }
    trackEvent(eventId, attributes);
  }
}
