/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import {
  CSJAdSdk,
  SDKConfig,
  SDKConfigBuilder,
  MediationConfigBuilder,
  CSJCustomPrivacyDefaultController
} from '@csj/openadsdk';
import { AdConfig } from '../common/AdConfig';
import { WindowStageHolder } from '../common/WindowStageHolder';

export class GroMoreAdManager {
  private static instance: GroMoreAdManager | null = null;

  private isInitialized: boolean = false;
  private isInitializing: boolean = false;
  private pendingCallbacks: ((success: boolean) => void)[] = [];

  static get shared(): GroMoreAdManager {
    if (GroMoreAdManager.instance === null) {
      GroMoreAdManager.instance = new GroMoreAdManager();
    }
    return GroMoreAdManager.instance;
  }

  initialize(completion?: (success: boolean) => void): void {
    if (this.isInitialized) {
      completion?.(true);
      return;
    }

    if (completion) {
      this.pendingCallbacks.push(completion);
    }

    if (this.isInitializing) {
      return;
    }
    this.isInitializing = true;

    const context = WindowStageHolder.abilityContext;
    if (context === null) {
      console.warn('[GroMoreAdManager] abilityContext 尚未就绪，跳过初始化');
      this.finishPending(false);
      return;
    }

    const config: SDKConfig = new SDKConfigBuilder()
      .appId(AdConfig.groMoreAppId)
      .appName('hosAgentclaw')
      .debug(false)
      .customController(new CSJCustomPrivacyDefaultController())
      .setMediationConfig(new MediationConfigBuilder().useMediation(true).build())
      .setThemeStatus(0)
      .build();

    CSJAdSdk.init(context, config);
    CSJAdSdk.start().then((result) => {
      const success = result !== undefined && (result.code === 0 || result.code === 4200);
      if (success) {
        CSJAdSdk.requestPermissionIfNeed(context);
      } else {
        console.warn(`[GroMoreAdManager] SDK start 未就绪 code=${result?.code} msg=${result?.msg}`);
      }
      this.finishPending(success);
    }).catch((error: Error) => {
      console.warn(`[GroMoreAdManager] SDK start 异常 ${error.message}`);
      this.finishPending(false);
    });
  }

  isSDKInitialized(): boolean {
    return this.isInitialized;
  }

  private finishPending(success: boolean): void {
    this.isInitializing = false;
    if (success) {
      this.isInitialized = true;
    }
    const callbacks = this.pendingCallbacks;
    this.pendingCallbacks = [];
    callbacks.forEach(callback => callback(success));
  }
}
