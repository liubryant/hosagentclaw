/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';

export class ImageSaver {
  static async saveNetworkImageToGallery(context: common.UIAbilityContext, url: string): Promise<void> {
    const permission: Permissions = 'ohos.permission.WRITE_IMAGEVIDEO';
    const grantResult = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, [permission]);
    const granted = grantResult.authResults.length > 0 && grantResult.authResults[0] === 0;
    if (!granted) {
      throw new Error('没有相册写入权限');
    }

    const request = http.createHttp();
    let buffer: ArrayBuffer;
    try {
      const response = await request.request(url, { expectDataType: http.HttpDataType.ARRAY_BUFFER });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`图片下载失败：HTTP ${response.responseCode}`);
      }
      buffer = response.result as ArrayBuffer;
    } finally {
      request.destroy();
    }

    const helper = photoAccessHelper.getPhotoAccessHelper(context);
    const extension = ImageSaver.extensionFromURL(url);
    const assetUri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, extension);
    const file = await fileIo.open(assetUri, fileIo.OpenMode.READ_WRITE);
    try {
      await fileIo.write(file.fd, buffer);
    } finally {
      await fileIo.close(file);
    }
  }

  private static extensionFromURL(url: string): string {
    const clean = url.split('?')[0].split('#')[0];
    const dotIndex = clean.lastIndexOf('.');
    if (dotIndex < 0) {
      return 'jpg';
    }
    const ext = clean.substring(dotIndex + 1).toLowerCase();
    const allowed = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
    return allowed.includes(ext) ? ext : 'jpg';
  }
}
