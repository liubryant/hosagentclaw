import { AbilityConstant, common, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SetToGlobalThis, TuanjiePlayer } from 'tuanjieLib';
import { AppPreferences } from '../storage/AppPreferences';

const DOMAIN: number = 0x0000;

/**
 * 本文件包含 Tuanjie 的全部静态依赖，只允许由 EntryAbility 在隐私同意后动态导入。
 * 这样首次隐私页的模块加载图不会提前执行 Tuanjie/worker/native 初始化。
 */
export class TuanjieLifecycleManager {
  private static instance: TuanjieLifecycleManager | null = null;
  private readonly player: TuanjiePlayer = TuanjiePlayer.getInstance();
  private globalsConfigured: boolean = false;
  private abilityCreated: boolean = false;
  private windowStageCreated: boolean = false;
  private inForeground: boolean = false;

  static get shared(): TuanjieLifecycleManager {
    if (TuanjieLifecycleManager.instance === null) {
      TuanjieLifecycleManager.instance = new TuanjieLifecycleManager();
    }
    return TuanjieLifecycleManager.instance;
  }

  initialize(context: common.UIAbilityContext, want: Want,
    launchParam: AbilityConstant.LaunchParam, windowStage: window.WindowStage | null,
    abilityIsForeground: boolean): void {
    if (!AppPreferences.shared.onboardingCompleted) {
      hilog.warn(DOMAIN, 'privacy', 'privacy consent missing, skip Tuanjie initialization');
      return;
    }

    this.configureGlobals();
    if (!this.abilityCreated) {
      // Tuanjie 的可选启动加速接口在部分系统镜像上会抛错，但 worker 可能已创建，
      // 因此先标记生命周期已转发，避免重复创建实例。
      this.abilityCreated = true;
      try {
        this.player.onCreate(context, want, launchParam);
        hilog.info(DOMAIN, 'tuanjiehub', 'post-consent player onCreate complete');
      } catch (error) {
        const playerError = error as Error;
        hilog.warn(DOMAIN, 'tuanjiehub',
          'post-consent player onCreate failed value=%{public}s message=%{public}s stack=%{public}s',
          `${error}`, playerError.message ?? '', playerError.stack ?? '');
      }
    }

    if (windowStage !== null && !this.windowStageCreated) {
      this.windowStageCreated = true;
      try {
        this.player.onWindowStageCreate(windowStage);
        hilog.info(DOMAIN, 'tuanjiehub', 'post-consent player windowStageCreate complete');
      } catch (error) {
        hilog.warn(DOMAIN, 'tuanjiehub', 'post-consent windowStageCreate failed %{public}s', `${error}`);
      }
    }
    this.updateForeground(abilityIsForeground);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    if (this.abilityCreated) {
      this.player.onNewWant(want, launchParam);
    }
  }

  onDestroy(): void {
    if (this.abilityCreated) {
      this.player.onDestroy();
      this.abilityCreated = false;
    }
  }

  onWindowStageWillDestroy(): void {
    if (this.windowStageCreated) {
      this.player.onWindowStageWillDestroy();
    }
  }

  onWindowStageDestroy(): void {
    if (this.windowStageCreated) {
      this.player.onWindowStageDestroy();
      this.windowStageCreated = false;
    }
  }

  onForeground(): void {
    this.updateForeground(true);
  }

  onBackground(): void {
    this.updateForeground(false);
  }

  private updateForeground(foreground: boolean): void {
    if (!this.abilityCreated || this.inForeground === foreground) {
      return;
    }
    this.inForeground = foreground;
    if (foreground) {
      this.player.onForeground();
    } else {
      this.player.onBackground();
    }
  }

  private configureGlobals(): void {
    if (this.globalsConfigured) {
      return;
    }
    this.globalsConfigured = true;
    SetToGlobalThis('showStaticSplash', $r('app.integer.ShowStaticSplashScreen'));
    SetToGlobalThis('staticSplashScreenFit', $r('app.integer.StaticSplashScreenFit'));
    SetToGlobalThis('appSplash', $r('app.media.start_window_icon_rounded'));
    SetToGlobalThis('isLaunchSnapshotEnabled', (): boolean => false);
  }
}
