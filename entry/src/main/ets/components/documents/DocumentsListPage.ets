/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { common } from '@kit.AbilityKit';
import { AgentClawDesign } from '../../common/Design';
import { Icons } from '../../common/Icons';
import { ShareUtil } from '../../common/ShareUtil';
import { ChatStore } from '../../store/ChatStore';
import { GeneratedDocumentStore } from '../../store/GeneratedDocumentStore';
import { GeneratedDocument } from '../../model/ChatModels';
import { DocumentPreviewOverlay } from './DocumentPreviewPage';

@Component
export struct DocumentsListPage {
  store: ChatStore = new ChatStore();
  onClose: () => void = () => {
  };
  @State private previewDocument: GeneratedDocument | null = null;

  private getDocuments(): GeneratedDocument[] {
    return [...this.store.allDocuments].sort((a, b) => b.createdAt - a.createdAt);
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.18)')
        .onClick(this.onClose)

      Column() {
        Row() {
          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(Icons.folder).fontSize(16)
              Text('文件管理').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#212121')
            }
            Text('所有对话生成的文档').fontSize(12).fontColor(AgentClawDesign.secondaryText)
          }
          .alignItems(HorizontalAlign.Start)

          Blank().layoutWeight(1)
          Text(Icons.close).fontSize(13).fontWeight(FontWeight.Bold).onClick(this.onClose)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })

        Divider().color(AgentClawDesign.divider)

        if (this.getDocuments().length === 0) {
          Column({ space: 16 }) {
            Text(Icons.doc).fontSize(48)
            Text('暂无生成的文档').fontSize(14).fontColor(Color.Gray)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              ForEach(this.getDocuments(), (document: GeneratedDocument) => {
                this.documentRow(document)
              }, (document: GeneratedDocument) => document.id)
            }
            .width('100%')
            .padding(20)
          }
          .layoutWeight(1)
        }
      }
      .width('92%')
      .height('70%')
      .backgroundColor('#FAFBFC')
      .borderRadius(14)

      if (this.previewDocument !== null) {
        DocumentPreviewOverlay({
          documentPath: GeneratedDocumentStore.shared.fileURL(this.previewDocument),
          displayName: this.previewDocument.displayName,
          onClose: () => {
            this.previewDocument = null;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private documentRow(document: GeneratedDocument) {
    Row({ space: 12 }) {
      Text(Icons.doc).fontSize(20)

      Column({ space: 4 }) {
        Text(document.displayName)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#212121')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`点击预览 · ${this.relativeTime(document.createdAt)}`)
          .fontSize(12)
          .fontColor(AgentClawDesign.secondaryText)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 4 }) {
        Text(Icons.share).fontSize(12).fontColor(Color.White)
        Text('分享').fontSize(12).fontWeight(FontWeight.Medium).fontColor(Color.White)
      }
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(AgentClawDesign.accent)
      .borderRadius(6)
      .onClick(() => {
        this.shareDocument(document);
      })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(10)
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.05)', offsetX: 0, offsetY: 2 })
    .onClick(() => {
      this.previewDocument = document;
    })
  }

  private shareDocument(document: GeneratedDocument): void {
    const context = getContext(this) as common.UIAbilityContext;
    const path = GeneratedDocumentStore.shared.fileURL(document);
    ShareUtil.shareFile(context, path, document.mimeType).catch(() => {
    });
  }

  private relativeTime(createdAt: number): string {
    const now = Date.now();
    const interval = now - createdAt;
    if (interval < 60 * 1000) {
      return '刚刚';
    }
    if (interval < 60 * 60 * 1000) {
      return `${Math.floor(interval / (60 * 1000))}分钟前`;
    }
    if (interval < 24 * 60 * 60 * 1000) {
      return `${Math.floor(interval / (60 * 60 * 1000))}小时前`;
    }
    if (interval < 7 * 24 * 60 * 60 * 1000) {
      return `${Math.floor(interval / (24 * 60 * 60 * 1000))}天前`;
    }
    const date = new Date(createdAt);
    const pad = (value: number): string => value < 10 ? `0${value}` : `${value}`;
    return `${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }
}
