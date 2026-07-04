/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { KeyboardAvoidMode, window } from '@kit.ArkUI';
import { WindowStageHolder } from './WindowStageHolder';

export class SystemBarStyle {
  static applyVip(): void {
    const mainWindow = SystemBarStyle.mainWindow();
    if (!mainWindow) {
      return;
    }

    mainWindow.setWindowLayoutFullScreen(true).catch(() => {});
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
