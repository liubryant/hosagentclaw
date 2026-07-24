import { Want } from '@kit.AbilityKit';

export const SHORTCUT_ACTION_PARAMETER: string = 'shortcutAction';
export const SHORTCUT_ACTION_QUICK_IMAGE: string = 'quick_image';
export const SHORTCUT_ACTION_AVATAR: string = 'avatar';
export const SHORTCUT_LAUNCH_EVENT: string = 'shortcutLaunch';

export class ShortcutLaunchStore {
  private static pendingAction: string = '';

  static capture(want: Want): string {
    const value = want.parameters?.[SHORTCUT_ACTION_PARAMETER];
    const action = typeof value === 'string' ? value : '';
    if (action === SHORTCUT_ACTION_QUICK_IMAGE || action === SHORTCUT_ACTION_AVATAR) {
      ShortcutLaunchStore.pendingAction = action;
    }
    return action;
  }

  static consume(): string {
    const action = ShortcutLaunchStore.pendingAction;
    ShortcutLaunchStore.pendingAction = '';
    return action;
  }
}
