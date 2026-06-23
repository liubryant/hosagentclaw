import { common, Want, wantConstant } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';

/**
 * 对应 iOS DocumentExportView（UIActivityViewController）：把生成的文件交给系统分享面板。
 */
export class ShareUtil {
  static async shareFile(context: common.UIAbilityContext, path: string, mimeType: string): Promise<void> {
    const uri = fileUri.getUriFromPath(path);
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
}
