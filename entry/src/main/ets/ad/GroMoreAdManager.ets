/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import {
  CSJAdSdk,
  SDKConfig,
  SDKConfigBuilder,
  MediationConfigBuilder,
  CSJCustomPrivacyController
} from '@csj/openadsdk';
import { AdConfig } from '../common/AdConfig';
import { WindowStageHolder } from '../common/WindowStageHolder';
import { AppPreferences } from '../storage/AppPreferences';

/**
 * 穿山甲最小化隐私控制器。
 *
 * OAID、位置、Wi-Fi 状态和 MAC 地址均不是应用核心功能的必要信息，
 * 因此即使用户同意隐私政策也不向广告 SDK 开放，避免 SDK 回退到默认
 * 控制器后自行读取设备标识符。
 */
class MinimalCSJPrivacyController extends CSJCustomPrivacyController {
  isCanUseAppTrackingConsent(): boolean {
    return false;
  }

  getDevOaid(): string | undefined {
    return undefined;
  }

  isCanUseLocation(): boolean {
    return false;
  }

  getTTLocation(): number[] | undefined {
    return undefined;
  }

  isCanUseWifiState(): boolean {
    return false;
  }

  getMacAddress(): string | undefined {
    return undefined;
  }
}

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
    if (!AppPreferences.shared.onboardingCompleted) {
      console.warn('[GroMoreAdManager] 用户未同意隐私政策，禁止初始化广告 SDK');
      completion?.(false);
      return;
    }

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
      .customController(new MinimalCSJPrivacyController())
      .setMediationConfig(new MediationConfigBuilder().useMediation(true).build())
      .setThemeStatus(0)
      .build();

    CSJAdSdk.init(context, config);
    CSJAdSdk.start().then((result) => {
      const success = result !== undefined && (result.code === 0 || result.code === 4200);
      if (!success) {
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
