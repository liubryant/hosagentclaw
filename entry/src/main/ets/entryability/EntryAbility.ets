/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, font, window } from '@kit.ArkUI';
import { AppPreferences } from '../storage/AppPreferences';
import { EnvironmentManager } from '../common/AppConfig';
import { GeneratedDocumentStore } from '../store/GeneratedDocumentStore';
import { WindowStageHolder } from '../common/WindowStageHolder';
import { SHORTCUT_LAUNCH_EVENT, ShortcutLaunchStore } from '../common/ShortcutLaunchStore';
import { PRIVACY_CONSENT_GRANTED_EVENT } from '../common/PrivacyConsent';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private latestWant: Want | null = null;
  private latestLaunchParam: AbilityConstant.LaunchParam | null = null;
  private currentWindowStage: window.WindowStage | null = null;
  private firstPartyServicesInitialized: boolean = false;
  private abilityIsForeground: boolean = false;
  private readonly privacyConsentListener = (): void => {
    this.initializePostConsentServices();
  };

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'tuanjiehub', 'ability onCreate begin');
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    AppPreferences.shared.init(this.context);
    WindowStageHolder.abilityContext = this.context;
    this.latestWant = want;
    this.latestLaunchParam = launchParam;
    this.context.eventHub.on(PRIVACY_CONSENT_GRANTED_EVENT, this.privacyConsentListener);
    ShortcutLaunchStore.capture(want);
    if (AppPreferences.shared.onboardingCompleted) {
      this.initializePostConsentServices();
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.latestWant = want;
    this.latestLaunchParam = launchParam;
    if (AppPreferences.shared.onboardingCompleted) {
      import('../common/TuanjieLifecycleManager').then((managerModule) => {
        managerModule.TuanjieLifecycleManager.shared.onNewWant(want, launchParam);
      }).catch((): void => {});
    }
    const action = ShortcutLaunchStore.capture(want);
    if (action.length > 0) {
      this.context.eventHub.emit(SHORTCUT_LAUNCH_EVENT, action);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    this.context.eventHub.off(PRIVACY_CONSENT_GRANTED_EVENT, this.privacyConsentListener);
    if (AppPreferences.shared.onboardingCompleted) {
      import('../common/TuanjieLifecycleManager').then((managerModule) => {
        managerModule.TuanjieLifecycleManager.shared.onDestroy();
      }).catch((): void => {});
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'tuanjiehub', 'ability windowStageCreate begin');
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    WindowStageHolder.windowStage = windowStage;
    this.currentWindowStage = windowStage;

    font.registerFont({ familyName: 'MiSans', familySrc: $rawfile('fonts/misans_medium.ttf') });
    font.registerFont({ familyName: 'MiSans-DemiBold', familySrc: $rawfile('fonts/misans_demibold.ttf') });
    font.registerFont({ familyName: 'MiSans-Normal', familySrc: $rawfile('fonts/misans_normal.ttf') });

    const mainWindow = windowStage.getMainWindowSync();
    Promise.all([
      // Keep one immutable fullscreen/system-bar geometry for the entire tab
      // shell. Every tab displays the status bar; tab-specific code changes
      // only its paint, so switching never resizes/recomposes the window.
      mainWindow.setWindowLayoutFullScreen(true),
      mainWindow.setWindowSystemBarEnable(['status', 'navigation']),
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#FFFFFF',
        statusBarContentColor: '#1A1A2E',
        isStatusBarLightIcon: false,
        navigationBarColor: '#FFFFFF',
        navigationBarContentColor: '#1A1A2E',
        isNavigationBarLightIcon: false
      })
    ]).then((): void => {
      this.publishSafeInsets(mainWindow);
      this.loadInitialContent(windowStage);
    }).catch((): void => {
      this.publishSafeInsets(mainWindow);
      this.loadInitialContent(windowStage);
    });
  }

  private publishSafeInsets(mainWindow: window.Window): void {
    let bottomInsetVp = 24;
    let topInsetVp = 32;
    try {
      const density = display.getDefaultDisplaySync().densityPixels;
      const navigationArea = mainWindow.getWindowAvoidAreaIgnoringVisibility(
        window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const systemArea = mainWindow.getWindowAvoidAreaIgnoringVisibility(window.AvoidAreaType.TYPE_SYSTEM);
      const cutoutArea = mainWindow.getWindowAvoidAreaIgnoringVisibility(window.AvoidAreaType.TYPE_CUTOUT);
      if (density > 0) {
        if (navigationArea.bottomRect.height > 0) {
          bottomInsetVp = Math.round(navigationArea.bottomRect.height / density);
        }
        const topHeightPx = Math.max(systemArea.topRect.height, cutoutArea.topRect.height);
        if (topHeightPx > 0) {
          topInsetVp = Math.round(topHeightPx / density);
        }
      }
    } catch (_) {
    }
    AppStorage.setOrCreate('shellTopSafeInset', topInsetVp);
    AppStorage.setOrCreate('shellBottomSafeInset', bottomInsetVp);
    hilog.info(DOMAIN, 'tuanjiehub', 'safe insets top=%{public}d bottom=%{public}d',
      topInsetVp, bottomInsetVp);
  }

  private loadInitialContent(windowStage: window.WindowStage): void {
    if (!AppPreferences.shared.onboardingCompleted) {
      this.loadContent(windowStage, 'pages/Index');
      return;
    }
    // 已同意用户先完成 Tuanjie 的窗口生命周期，再展示主页面，避免状态栏二次跳动。
    this.initializePostConsentServices().finally((): void => {
      this.loadContent(windowStage, 'pages/MainPage');
    });
  }

  private loadContent(windowStage: window.WindowStage, page: string): void {
    windowStage.loadContent(page, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  private initializePostConsentServices(): Promise<void> {
    if (!AppPreferences.shared.onboardingCompleted) {
      return Promise.resolve();
    }
    if (!this.firstPartyServicesInitialized) {
      this.firstPartyServicesInitialized = true;
      EnvironmentManager.shared.init(this.context);
      GeneratedDocumentStore.shared.init(this.context);
    }
    const want = this.latestWant;
    const launchParam = this.latestLaunchParam;
    if (want === null || launchParam === null) {
      return Promise.resolve();
    }
    return import('../common/TuanjieLifecycleManager').then((managerModule) => {
      managerModule.TuanjieLifecycleManager.shared.initialize(
        this.context, want, launchParam, this.currentWindowStage, this.abilityIsForeground);
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, 'tuanjiehub', 'post-consent module load failed %{public}s', error.message);
    });
  }

  onWindowStageWillDestroy(): void {
    if (AppPreferences.shared.onboardingCompleted) {
      import('../common/TuanjieLifecycleManager').then((managerModule) => {
        managerModule.TuanjieLifecycleManager.shared.onWindowStageWillDestroy();
      }).catch((): void => {});
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
    this.currentWindowStage = null;
    WindowStageHolder.windowStage = null;
    if (AppPreferences.shared.onboardingCompleted) {
      import('../common/TuanjieLifecycleManager').then((managerModule) => {
        managerModule.TuanjieLifecycleManager.shared.onWindowStageDestroy();
      }).catch((): void => {});
    }
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'tuanjiehub', 'player foreground');
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    this.abilityIsForeground = true;
    if (AppPreferences.shared.onboardingCompleted) {
      import('../common/TuanjieLifecycleManager').then((managerModule) => {
        managerModule.TuanjieLifecycleManager.shared.onForeground();
      }).catch((): void => {});
    }
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    this.abilityIsForeground = false;
    if (AppPreferences.shared.onboardingCompleted) {
      import('../common/TuanjieLifecycleManager').then((managerModule) => {
        managerModule.TuanjieLifecycleManager.shared.onBackground();
      }).catch((): void => {});
    }
  }
}
