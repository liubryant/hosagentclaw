/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { font, window } from '@kit.ArkUI';
import { AppPreferences } from '../storage/AppPreferences';
import { EnvironmentManager } from '../common/AppConfig';
import { GeneratedDocumentStore } from '../store/GeneratedDocumentStore';
import { WindowStageHolder } from '../common/WindowStageHolder';
import { SHORTCUT_LAUNCH_EVENT, ShortcutLaunchStore } from '../common/ShortcutLaunchStore';
import { SetToGlobalThis, TuanjiePlayer } from 'tuanjieLib';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private readonly tuanjiePlayer: TuanjiePlayer = TuanjiePlayer.getInstance();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'tuanjiehub', 'ability onCreate begin');
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    AppPreferences.shared.init(this.context);
    EnvironmentManager.shared.init(this.context);
    GeneratedDocumentStore.shared.init(this.context);
    WindowStageHolder.abilityContext = this.context;
    ShortcutLaunchStore.capture(want);
    SetToGlobalThis('showStaticSplash', $r('app.integer.ShowStaticSplashScreen'));
    SetToGlobalThis('staticSplashScreenFit', $r('app.integer.StaticSplashScreenFit'));
    SetToGlobalThis('appSplash', $r('app.media.start_window_icon_rounded'));
    // Required by Tuanjie's exported Ability template. The engine invokes this
    // global callback from TuanjiePlayer.onCreate even when launch acceleration
    // is disabled in boot.config.
    SetToGlobalThis('isLaunchSnapshotEnabled', (): boolean => false);
    hilog.info(DOMAIN, 'tuanjiehub', 'launch snapshot callback registered');
    // Tuanjie 1.9.3 calls the optional launch-acceleration API even when the
    // current HarmonyOS image does not expose it. Keep the already-created
    // player/worker alive, but do not let that optional API abort app startup.
    try {
      this.tuanjiePlayer.onCreate(this.context, want, launchParam);
      hilog.info(DOMAIN, 'tuanjiehub', 'player onCreate complete');
    } catch (error) {
      const playerError = error as Error;
      hilog.warn(DOMAIN, 'tuanjiehub',
        'player onCreate failed value=%{public}s message=%{public}s stack=%{public}s',
        `${error}`, playerError.message ?? '', playerError.stack ?? '');
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.tuanjiePlayer.onNewWant(want, launchParam);
    const action = ShortcutLaunchStore.capture(want);
    if (action.length > 0) {
      this.context.eventHub.emit(SHORTCUT_LAUNCH_EVENT, action);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    this.tuanjiePlayer.onDestroy();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'tuanjiehub', 'ability windowStageCreate begin');
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    WindowStageHolder.windowStage = windowStage;

    font.registerFont({ familyName: 'MiSans', familySrc: $rawfile('fonts/misans_medium.ttf') });
    font.registerFont({ familyName: 'MiSans-DemiBold', familySrc: $rawfile('fonts/misans_demibold.ttf') });
    font.registerFont({ familyName: 'MiSans-Normal', familySrc: $rawfile('fonts/misans_normal.ttf') });

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
    this.tuanjiePlayer.onWindowStageCreate(windowStage);
    hilog.info(DOMAIN, 'tuanjiehub', 'player windowStageCreate complete');
  }

  onWindowStageWillDestroy(): void {
    this.tuanjiePlayer.onWindowStageWillDestroy();
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
    this.tuanjiePlayer.onWindowStageDestroy();
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'tuanjiehub', 'player foreground');
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    this.tuanjiePlayer.onForeground();
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    this.tuanjiePlayer.onBackground();
  }
}
