/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { webview } from '@kit.ArkWeb';
import { fileIo } from '@kit.CoreFileKit';
import { AgentClawDesign } from '../../common/Design';
import { Icons } from '../../common/Icons';

@Component
export struct DocumentPreviewOverlay {
  documentPath: string = '';
  displayName: string = '';
  onClose: () => void = () => {
  };
  private controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Stack() {
      Column() {
        Row() {
          Text(this.displayName)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(AgentClawDesign.primaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(Icons.close)
            .fontSize(16)
            .onClick(this.onClose)
        }
        .width('100%')
        .height(44)
        .padding({ left: 14, right: 14 })
        .backgroundColor(AgentClawDesign.controlSurface)

        Web({ src: '', controller: this.controller })
          .layoutWeight(1)
          .onPageEnd(() => {
          })
          .onControllerAttached(() => {
            this.loadDocument();
          })
      }
      .width('90%')
      .height('80%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .clip(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.35)')
    .onClick(() => {
    })
  }

  private loadDocument(): void {
    let text = '';
    try {
      text = fileIo.readTextSync(this.documentPath);
    } catch (e) {
      this.controller.loadData(this.errorHtml('文件不存在或无法读取'), 'text/html', 'UTF-8');
      return;
    }

    const lower = this.documentPath.toLowerCase();
    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      this.controller.loadData(text, 'text/html', 'UTF-8');
    } else {
      this.controller.loadData(this.textPreviewHtml(text), 'text/html', 'UTF-8');
    }
  }

  private textPreviewHtml(text: string): string {
    return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head><body style="font-family:-apple-system,sans-serif;margin:18px;color:#222;line-height:1.55;"><pre style="white-space:pre-wrap;word-wrap:break-word;font:14px monospace;">${this.escapeHtml(text)}</pre></body></html>`;
  }

  private errorHtml(message: string): string {
    return `<!doctype html><html><body style="font-family:sans-serif;padding:20px;color:#333;">${this.escapeHtml(message)}</body></html>`;
  }

  private escapeHtml(text: string): string {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }
}
