/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { common } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';
import { AgentClawDesign } from '../../common/Design';
import { Icons } from '../../common/Icons';
import { ShareUtil } from '../../common/ShareUtil';
import { ChatStore } from '../../store/ChatStore';
import { GeneratedDocumentStore } from '../../store/GeneratedDocumentStore';
import { GeneratedDocument } from '../../model/ChatModels';
import { DocumentPreviewOverlay } from './DocumentPreviewPage';
import { AppBackNavigator } from '../../common/AppBackNavigator';

@Component
export struct DocumentsListPage {
  private readonly backHandlerId: string = AppBackNavigator.createHandlerId('documents');
  store: ChatStore = new ChatStore();
  onClose: () => void = () => {
  };
  onOpenVideo: (url: string, coverURL: string) => void = () => {};
  @State private previewDocument: GeneratedDocument | null = null;
  @State private previewImage: GeneratedDocument | null = null;

  aboutToAppear(): void {
    AppBackNavigator.register(this.backHandlerId, (): boolean => this.handleBack());
  }

  aboutToDisappear(): void {
    AppBackNavigator.unregister(this.backHandlerId);
  }

  private handleBack(): boolean {
    if (this.previewImage !== null) {
      this.previewImage = null;
      return true;
    }
    if (this.previewDocument !== null) {
      this.previewDocument = null;
      return true;
    }
    this.onClose();
    return true;
  }

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
          Row() {
            Image($rawfile('icons/ic_back.svg')).width(22).height(22)
          }
          .width(44)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .onClick(this.onClose)

          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(Icons.folder).fontSize(16)
              Text('文件管理').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#212121')
            }
            Text('所有对话生成的文档、图片和视频').fontSize(12).fontColor(AgentClawDesign.secondaryText)
          }
          .alignItems(HorizontalAlign.Start)

          Blank().layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 8, right: 20, top: 12, bottom: 12 })

        Divider().color(AgentClawDesign.divider)

        if (this.getDocuments().length === 0) {
          Column({ space: 16 }) {
            Text(Icons.doc).fontSize(48)
            Text('暂无保存的文件').fontSize(14).fontColor(Color.Gray)
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
            .constraintSize({ minHeight: '100%' })
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Start)
            .align(Alignment.TopStart)
          }
          .width('100%')
          .layoutWeight(1)
          .align(Alignment.TopStart)
        }
      }
      .width('92%')
      .height('58%')
      .backgroundColor('#FAFBFC')
      .borderRadius(14)
      .justifyContent(FlexAlign.Start)

      if (this.previewDocument !== null) {
        DocumentPreviewOverlay({
          documentPath: GeneratedDocumentStore.shared.fileURL(this.previewDocument),
          displayName: this.previewDocument.displayName,
          onClose: () => {
            this.previewDocument = null;
          }
        })
      }

      if (this.previewImage !== null) {
        this.imagePreviewOverlay(this.previewImage)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private documentRow(document: GeneratedDocument) {
    Row({ space: 12 }) {
      Text(this.documentIcon(document)).fontSize(20)

      Column({ space: 4 }) {
        Text(document.displayName)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#212121')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.actionText(document)} · ${this.relativeTime(document.createdAt)}`)
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
      this.openDocument(document);
    })
  }

  @Builder
  private imagePreviewOverlay(document: GeneratedDocument) {
    Stack() {
      Column() {
        Row() {
          Row() {
            Image($rawfile('icons/ic_back.svg')).width(21).height(21)
          }
          .width(40)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.previewImage = null;
          })

          Text(document.displayName)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(AgentClawDesign.primaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .height(44)
        .padding({ left: 2, right: 14 })
        .backgroundColor(AgentClawDesign.controlSurface)

        Image(fileUri.getUriFromPath(GeneratedDocumentStore.shared.fileURL(document)))
          .layoutWeight(1)
          .width('100%')
          .objectFit(ImageFit.Contain)
          .backgroundColor('#111111')
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
  }

  private openDocument(document: GeneratedDocument): void {
    if (this.isImage(document)) {
      this.previewImage = document;
      return;
    }
    if (this.isVideo(document)) {
      this.onOpenVideo(fileUri.getUriFromPath(GeneratedDocumentStore.shared.fileURL(document)), '');
      return;
    }
    this.previewDocument = document;
  }

  private documentIcon(document: GeneratedDocument): string {
    if (this.isImage(document)) {
      return Icons.photo;
    }
    if (this.isVideo(document)) {
      return Icons.video;
    }
    return Icons.doc;
  }

  private actionText(document: GeneratedDocument): string {
    if (this.isVideo(document)) {
      return '点击播放';
    }
    return '点击预览';
  }

  private isImage(document: GeneratedDocument): boolean {
    return document.mimeType.startsWith('image/');
  }

  private isVideo(document: GeneratedDocument): boolean {
    return document.mimeType.startsWith('video/');
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
