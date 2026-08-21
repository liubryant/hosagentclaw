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

    mainWindow.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE);
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      statusBarContentColor: '#00000000',
      isStatusBarLightIcon: false,
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
      statusBarColor: '#FFFFFF',
      statusBarContentColor: '#1A1A2E',
      isStatusBarLightIcon: false,
      navigationBarColor: '#FFFFFF',
      navigationBarContentColor: '#1A1A2E',
      isNavigationBarLightIcon: false
    }).catch(() => {});
  }

  /**
   * Avatar page: keep the fixed shell geometry and make the top system-bar
   * content transparent while retaining the bottom navigation/gesture area.
   */
  static applyAvatarImmersive(): void {
    const mainWindow = SystemBarStyle.mainWindow();
    if (!mainWindow) {
      return;
    }

    mainWindow.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      statusBarContentColor: '#00000000',
      isStatusBarLightIcon: false,
      navigationBarColor: '#FFFFFF',
      navigationBarContentColor: '#1A1A2E',
      isNavigationBarLightIcon: false
    }).catch(() => {});
  }

  /** All main tabs share one visible white status bar and fixed geometry. */
  static applyTabStatusBar(): void {
    const mainWindow = SystemBarStyle.mainWindow();
    if (!mainWindow) {
      return;
    }
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

  static applyVip(): void {
    const mainWindow = SystemBarStyle.mainWindow();
    if (!mainWindow) {
      return;
    }

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
