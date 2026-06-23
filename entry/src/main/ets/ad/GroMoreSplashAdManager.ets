import {
  CSJAdSdk,
  AdSlotBuilder,
  CSJSplashAd,
  CSJSplashAdLoadParam,
  CSJSplashAdLoadListener,
  CSJSplashAdInteractionListener,
  CSJSplashAdCloseType
} from '@csj/openadsdk';
import { display } from '@kit.ArkUI';
import { AdConfig } from '../common/AdConfig';
import { WindowStageHolder } from '../common/WindowStageHolder';
import { GroMoreAdManager } from './GroMoreAdManager';

/**
 * GroMore 开屏广告封装。对应 iOS PangleSplashAdManager.swift。
 * 每个进程生命周期只请求一次开屏（shouldRequestSplashThisSession），
 * 调用方（pages/Index.ets）会在请求前后配合一个超时兜底，避免开屏一直卡住首页。
 */
export class GroMoreSplashAdManager {
  static readonly defaultSplashSlotId: string = AdConfig.splashAdSlotId;
  private static instance: GroMoreSplashAdManager | null = null;

  private isLoading: boolean = false;
  private didRequestSplashThisSession: boolean = false;

  static get shared(): GroMoreSplashAdManager {
    if (GroMoreSplashAdManager.instance === null) {
      GroMoreSplashAdManager.instance = new GroMoreSplashAdManager();
    }
    return GroMoreSplashAdManager.instance;
  }

  get shouldRequestSplashThisSession(): boolean {
    return !this.didRequestSplashThisSession && !this.isLoading;
  }

  loadAndShowDefaultSplashAd(completion?: (shown: boolean, error?: Error) => void): void {
    this.loadAndShowSplashAd(GroMoreSplashAdManager.defaultSplashSlotId, 3500, completion);
  }

  loadAndShowSplashAd(slotId: string, tolerateTimeoutMs: number = 3500, completion?: (shown: boolean, error?: Error) => void): void {
    if (!this.shouldRequestSplashThisSession) {
      completion?.(false);
      return;
    }
    this.didRequestSplashThisSession = true;

    if (!GroMoreAdManager.shared.isSDKInitialized()) {
      completion?.(false, new Error('GroMore SDK 未初始化'));
      return;
    }

    const windowStage = WindowStageHolder.windowStage;
    if (windowStage === null) {
      completion?.(false, new Error('WindowStage 尚未就绪'));
      return;
    }

    if (this.isLoading) {
      return;
    }
    this.isLoading = true;

    const uiContext = windowStage.getMainWindowSync().getUIContext();
    const screen = display.getDefaultDisplaySync();
    const adSlot = new AdSlotBuilder()
      .setCodeId(slotId)
      .setAcceptSize(screen.width, screen.height)
      .build();

    let completionCalled = false;
    const finish = (shown: boolean, error?: Error): void => {
      if (completionCalled) {
        return;
      }
      completionCalled = true;
      completion?.(shown, error);
    };

    const loadListener: CSJSplashAdLoadListener = {
      onAdLoaded: (splashAd: CSJSplashAd) => {
        splashAd.setInteractionListener(this.buildInteractionListener(finish));
        splashAd.showSplashAd(windowStage);
      },
      onError: (code: number, message: string) => {
        this.isLoading = false;
        console.warn(`[GroMoreSplashAdManager] 开屏加载失败 code=${code} message=${message}`);
        finish(false, new Error(message));
      },
      onRenderSuccess: () => {
        console.log('[GroMoreSplashAdManager] 开屏渲染成功');
      },
      onRenderFail: (code: number, message: string) => {
        this.isLoading = false;
        console.warn(`[GroMoreSplashAdManager] 开屏渲染失败 code=${code} message=${message}`);
        finish(false, new Error(message));
      }
    };

    const param = new CSJSplashAdLoadParam(adSlot, loadListener, uiContext, tolerateTimeoutMs);
    CSJAdSdk.getAdCreator().loadSplashAd(param);
  }

  private buildInteractionListener(finish: (shown: boolean, error?: Error) => void): CSJSplashAdInteractionListener {
    return {
      onDidShow: () => {
        this.isLoading = false;
        console.log('[GroMoreSplashAdManager] 开屏已展示');
        finish(true);
      },
      onDidClick: () => {
        console.log('[GroMoreSplashAdManager] 开屏被点击');
      },
      onDidClose: (closeType: CSJSplashAdCloseType) => {
        this.isLoading = false;
        console.log(`[GroMoreSplashAdManager] 开屏已关闭 closeType=${closeType.value}`);
        // 部分情况下 onDidShow 不会触发，这里兜底把"开屏流程结束"通知给调用方。
        finish(true);
      },
      onVideoDidPlayFinish: () => {
        console.log('[GroMoreSplashAdManager] 开屏视频播放完成');
      },
      onVideoDidPlayFail: (code: number, message: string) => {
        console.warn(`[GroMoreSplashAdManager] 开屏视频播放失败 code=${code} message=${message}`);
      }
    };
  }
}
