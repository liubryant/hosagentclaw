/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { common, Want, wantConstant } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';
import systemShare from '@hms.collaboration.systemShare';

export class ShareUtil {
  static async shareFile(context: common.UIAbilityContext, path: string, mimeType: string): Promise<void> {
    const uri = fileUri.getUriFromPath(path);
    try {
      const record: systemShare.SharedRecord = {
        utd: ShareUtil.utdForMimeType(mimeType),
        uri: uri,
        title: ShareUtil.lastPathComponent(path)
      };
      const data = new systemShare.SharedData(record);
      const controller = new systemShare.ShareController(data);
      await controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
      return;
    } catch (error) {
      console.warn(`[ShareUtil] system share failed, fallback to want: ${(error as Error).message}`);
    }

    const want: Want = {
      action: 'ohos.want.action.sendData',
      type: mimeType,
      uri: uri,
      flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION,
      parameters: {
        'ability.params.stream': [uri]
      }
    };
    await context.startAbility(want);
  }

  private static utdForMimeType(mimeType: string): string {
    const lower = mimeType.toLowerCase();
    if (lower.startsWith('image/')) {
      return 'general.image';
    }
    if (lower.startsWith('video/')) {
      return 'general.video';
    }
    if (lower === 'text/plain') {
      return 'general.plain-text';
    }
    if (lower === 'text/html') {
      return 'general.html';
    }
    return 'general.file';
  }

  private static lastPathComponent(path: string): string {
    const parts = path.split('/');
    return parts[parts.length - 1];
  }
}
