/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { common, Want, wantConstant } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';

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
