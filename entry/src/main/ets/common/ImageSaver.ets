/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { http } from '@kit.NetworkKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common } from '@kit.AbilityKit';

export class ImageSaver {
  static async saveNetworkImageToGallery(context: common.UIAbilityContext, url: string): Promise<void> {
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
    const title = `AgentClaw_${Date.now()}`;
    const tempPath = `${context.cacheDir}/${title}.${extension}`;
    const tempFile = await fileIo.open(
      tempPath,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE
    );
    try {
      await fileIo.write(tempFile.fd, buffer);
    } finally {
      await fileIo.close(tempFile);
    }

    try {
      // The system dialog grants write access to the selected destination URI without
      // requiring the restricted WRITE_IMAGEVIDEO ACL permission.
      const destinationUris = await helper.showAssetsCreationDialog(
        [fileUri.getUriFromPath(tempPath)],
        [{
          title: title,
          fileNameExtension: extension,
          photoType: photoAccessHelper.PhotoType.IMAGE
        }]
      );
      if (destinationUris.length === 0) {
        throw new Error('已取消保存');
      }

      const destinationFile = await fileIo.open(destinationUris[0], fileIo.OpenMode.READ_WRITE);
      try {
        await fileIo.write(destinationFile.fd, buffer);
      } finally {
        await fileIo.close(destinationFile);
      }
    } finally {
      try {
        await fileIo.unlink(tempPath);
      } catch (_) {
        // Best-effort cleanup; a failed cache deletion must not invalidate a saved image.
      }
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
