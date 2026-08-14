/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { KeyboardAvoidMode, window } from '@kit.ArkUI';
import { WindowStageHolder } from './WindowStageHolder';

export class SystemBarStyle {
  static applyImmersiveDark(): void {
    const mainWindow = SystemBarStyle.mainWindow();
    if (!mainWindow) {
      return;
    }

    mainWindow.setWindowLayoutFullScreen(true).catch(() => {});
    mainWindow.setWindowSystemBarEnable(['navigation']).catch(() => {});
    mainWindow.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE);
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      statusBarContentColor: '#FFFFFF',
      isStatusBarLightIcon: true,
      navigationBarColor: '#000000',
      navigationBarContentColor: '#FFFFFF',
      isNavigationBarLightIcon: true
    }).catch(() => {});
  }

  static applySplash(): void {
    const mainWindow = SystemBarStyle.mainWindow();
    if (!mainWindow) {
      return;
    }
    // Splash ads are overlays. Changing fullscreen/status-bar visibility here
    // resizes the ArkUI viewport when the ad closes and makes the bottom bar
    // jump on the first home frame. Keep window geometry unchanged.
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#000000',
      statusBarContentColor: '#FFFFFF',
      isStatusBarLightIcon: true,
      navigationBarColor: '#FFFFFF',
      navigationBarContentColor: '#1A1A2E',
      isNavigationBarLightIcon: false
    }).catch(() => {});
  }

  /**
   * Avatar page: hide only the top status bar while keeping the bottom
   * navigation/gesture area identical to the normal tab pages.
   */
  static applyAvatarImmersive(): void {
    const mainWindow = SystemBarStyle.mainWindow();
    if (!mainWindow) {
      return;
    }

    // Avatar keeps its original top immersive presentation: hide the status
    // bar while retaining the system navigation bar. ShellPage independently
    // restores the bottom gesture inset consumed by the Tuanjie surface.
    mainWindow.setWindowLayoutFullScreen(false).catch(() => {});
    mainWindow.setWindowSystemBarEnable(['navigation']).catch(() => {});
    mainWindow.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      statusBarContentColor: '#FFFFFF',
      isStatusBarLightIcon: true,
      navigationBarColor: '#FFFFFF',
      navigationBarContentColor: '#1A1A2E',
      isNavigationBarLightIcon: false
    }).catch(() => {});
  }

  /**
   * Tab switches must not change window geometry. Toggling fullscreen/status
   * bar visibility while an XComponent surface mounts causes a visible relayout
   * and its async window operations can complete out of order on rapid taps.
   */
  static applyAvatarTabStable(): void {
    const mainWindow = SystemBarStyle.mainWindow();
    if (!mainWindow) {
      return;
    }
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#4B2E78',
      statusBarContentColor: '#FFFFFF',
      isStatusBarLightIcon: true,
      navigationBarColor: '#FFFFFF',
      navigationBarContentColor: '#1A1A2E',
      isNavigationBarLightIcon: false
    }).catch(() => {});
  }

  static restoreTabDefaultStable(): void {
    const mainWindow = SystemBarStyle.mainWindow();
    if (!mainWindow) {
      return;
    }
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#FFFFFF',
      statusBarContentColor: '#1A1A2E',
      isStatusBarLightIcon: false,
      navigationBarColor: '#FFFFFF',
      navigationBarContentColor: '#1A1A2E',
      isNavigationBarLightIcon: false
    }).catch(() => {});
  }

  static applyProfileStatusBar(isProfile: boolean): void {
    const mainWindow = SystemBarStyle.mainWindow();
    if (!mainWindow) {
      return;
    }
    // Fullscreen geometry is established once by EntryAbility. Never reset it
    // during a tab click, otherwise the compositor flashes the window surface.
    mainWindow.setWindowSystemBarEnable(isProfile ? ['status', 'navigation'] : ['navigation']).catch(() => {});
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      statusBarContentColor: isProfile ? '#1A1A2E' : '#00000000',
      isStatusBarLightIcon: false,
      navigationBarColor: '#FFFFFF',
      navigationBarContentColor: '#1A1A2E',
      isNavigationBarLightIcon: false
    }).catch(() => {});
  }

  static applyVip(): void {
    const mainWindow = SystemBarStyle.mainWindow();
    if (!mainWindow) {
      return;
    }

    mainWindow.setWindowLayoutFullScreen(true).catch(() => {});
    mainWindow.setWindowSystemBarEnable(['status', 'navigation']).catch(() => {});
    mainWindow.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE);
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#0D0703',
      statusBarContentColor: '#FFEDBD',
      isStatusBarLightIcon: true,
      navigationBarColor: '#0D0703',
      navigationBarContentColor: '#FFEDBD',
      isNavigationBarLightIcon: true
    }).catch(() => {});
  }

  static applyVideo(): void {
    const mainWindow = SystemBarStyle.mainWindow();
    if (!mainWindow) {
      return;
    }

    mainWindow.setWindowLayoutFullScreen(true).catch(() => {});
    mainWindow.setWindowSystemBarEnable(['status', 'navigation']).catch(() => {});
    mainWindow.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE);
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#050507',
      statusBarContentColor: '#FFFFFF',
      isStatusBarLightIcon: true,
      navigationBarColor: '#050507',
      navigationBarContentColor: '#FFFFFF',
      isNavigationBarLightIcon: true
    }).catch(() => {});
  }

  static restoreDefault(): void {
    const mainWindow = SystemBarStyle.mainWindow();
    if (!mainWindow) {
      return;
    }

    mainWindow.setWindowLayoutFullScreen(false).catch(() => {});
    mainWindow.setWindowSystemBarEnable(['status', 'navigation']).catch(() => {});
    mainWindow.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#FFFFFF',
      statusBarContentColor: '#1A1A2E',
      isStatusBarLightIcon: false,
      navigationBarColor: '#FFFFFF',
      navigationBarContentColor: '#1A1A2E',
      isNavigationBarLightIcon: false
    }).catch(() => {});
  }

  private static mainWindow(): window.Window | undefined {
    try {
      return WindowStageHolder.windowStage?.getMainWindowSync();
    } catch (_) {
      return undefined;
    }
  }
}
