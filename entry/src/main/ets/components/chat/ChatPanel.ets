import { common } from '@kit.AbilityKit';
import { AgentClawDesign } from '../../common/Design';
import { Icons } from '../../common/Icons';
import { ImageSaver } from '../../common/ImageSaver';
import { ShareUtil } from '../../common/ShareUtil';
import { ChatStore } from '../../store/ChatStore';
import { GeneratedDocumentStore } from '../../store/GeneratedDocumentStore';
import { ChatEntryMode, ChatMessage, ChatRole, GeneratedDocument } from '../../model/ChatModels';
import { DocumentPreviewOverlay } from '../documents/DocumentPreviewPage';

interface QuickPrompt {
  title: string;
  subtitle: string;
  prompt: string;
  imageName: ResourceStr;
}

const QUICK_PROMPTS: QuickPrompt[] = [
  {
    title: '安装你的第一个Skill',
    subtitle: '一键解锁自动化超能力',
    prompt: '帮我规划并安装第一个适合日常自动化的 Skill，需要包含用途、安装步骤和验证方式。',
    imageName: $r('app.media.img_chat_idea_skill')
  },
  {
    title: '自动化生活助手',
    subtitle: '自动下载应用、淘宝购物',
    prompt: '打开应用宝帮我下载 应用名称：',
    imageName: $r('app.media.img_chat_idea_life')
  },
  {
    title: '办公文档生成',
    subtitle: '一句话写竞品分析、会议纪要',
    prompt: '帮我生成一份办公文档助手模板，支持竞品分析、会议纪要和待办事项输出。',
    imageName: $r('app.media.img_chat_idea_docs')
  }
];

const MARKDOWN_IMAGE_PATTERN = /!\[[^\]]*]\((https?:\/\/[^)\s]+)\)/g;
const GENERIC_URL_PATTERN = /https?:\/\/\S+/g;

class ChatMediaParser {
  static firstImageURL(content: string): string | null {
    const candidates: string[] = [];
    let match: RegExpExecArray | null;

    const markdownRegex = new RegExp(MARKDOWN_IMAGE_PATTERN);
    while ((match = markdownRegex.exec(content)) !== null) {
      candidates.push(match[1]);
    }
    const genericRegex = new RegExp(GENERIC_URL_PATTERN);
    while ((match = genericRegex.exec(content)) !== null) {
      candidates.push(match[0]);
    }

    for (const candidate of candidates) {
      const normalized = ChatMediaParser.normalize(candidate);
      if (ChatMediaParser.isImageURL(normalized)) {
        return normalized;
      }
    }
    return null;
  }

  static stripMedia(content: string): string {
    const withoutMarkdownImages = content.replace(new RegExp(MARKDOWN_IMAGE_PATTERN), '');
    const cleanedLines = withoutMarkdownImages
      .split('\n')
      .map((line): string => {
        return line.replace(new RegExp(GENERIC_URL_PATTERN), (raw): string => {
          const normalized = ChatMediaParser.normalize(raw);
          return ChatMediaParser.isImageURL(normalized) || ChatMediaParser.isVideoURL(normalized) ? '' : raw;
        }).trim();
      })
      .filter((line): boolean => {
        return line.length > 0 &&
          !line.startsWith('图片链接') &&
          !line.startsWith('Image link') &&
          !line.startsWith('视频链接') &&
          !line.startsWith('Video link');
      });

    return cleanedLines.join('\n').replace(/\n{3,}/g, '\n\n').trim();
  }

  private static normalize(raw: string): string {
    return raw.trim().replace(/[.,;)\]>]+$/g, '');
  }

  private static isImageURL(url: string): boolean {
    const lower = url.toLowerCase();
    return lower.includes('.png') || lower.includes('.jpg') || lower.includes('.jpeg') ||
      lower.includes('.webp') || lower.includes('.gif') || lower.includes('ufileos.com/');
  }

  private static isVideoURL(url: string): boolean {
    const lower = url.toLowerCase();
    return lower.includes('.mp4') || lower.includes('.mov') || lower.includes('.m4v') ||
      lower.includes('.webm') || lower.includes('.m3u8');
  }
}

/**
 * 对应 iOS ChatView.swift。
 */
@Component
export struct ChatPanel {
  store: ChatStore = new ChatStore();
  @State private previewDocument: GeneratedDocument | null = null;

  build() {
    Stack() {
      Column() {
        this.content()

        if (this.store.errorMessage !== null) {
          this.errorBanner(this.store.errorMessage)
        }

        this.composer()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)

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
  private content() {
    Scroll() {
      Column({ space: 12 }) {
        if (this.store.messages.length === 0) {
          this.welcomeState()
        } else {
          ForEach(this.store.messages, (message: ChatMessage) => {
            this.messageBubble(message)
          }, (message: ChatMessage) => message.id)
        }

        if (this.store.isSending) {
          this.thinkingIndicator()
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 18, right: 18, top: 10, bottom: 10 })
    }
    .layoutWeight(1)
    .align(Alignment.Top)
  }

  @Builder
  private welcomeState() {
    Column() {
      Image($r('app.media.app_icon_display'))
        .width(45)
        .height(45)

      Text('7x24小时，随时随地召唤的全能电脑AI助手')
        .fontSize(12)
        .fontColor(AgentClawDesign.secondaryText)
        .textAlign(TextAlign.Center)
        .margin({ top: 18 })

      Column({ space: 8 }) {
        ForEach(QUICK_PROMPTS, (item: QuickPrompt) => {
          Row({ space: 8 }) {
            Column({ space: 6 }) {
              Text(item.title)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333333')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(item.subtitle)
                .fontSize(12)
                .fontColor(AgentClawDesign.secondaryText)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image(item.imageName)
              .width(40)
              .height(30)
              .objectFit(ImageFit.Contain)
          }
          .alignItems(VerticalAlign.Top)
          .width('100%')
          .height(100)
          .padding(10)
          .backgroundColor('#F5F8FA')
          .borderRadius(16)
          .onClick(() => {
            this.store.draft = item.prompt;
          })
        })
      }
      .width('100%')
      .constraintSize({ maxWidth: 420 })
      .padding({ left: 16, right: 16, top: 24 })
    }
    .width('100%')
    .padding({ top: 6, bottom: 12 })
  }

  @Builder
  private messageBubble(message: ChatMessage) {
    Row() {
      if (message.role === ChatRole.USER) {
        Blank().layoutWeight(1)
      }

      Column({ space: 5 }) {
        Text(message.role === ChatRole.USER ? '我' : 'Agent')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(AgentClawDesign.secondaryText)

        if (this.bubbleText(message).length > 0 || this.bubbleImageURL(message) === null) {
          Text(this.bubbleText(message).length === 0 ? '...' : this.bubbleText(message))
            .fontSize(13)
            .fontColor(AgentClawDesign.primaryText)
            .padding({ left: 11, right: 11, top: 8, bottom: 8 })
            .backgroundColor(message.role === ChatRole.USER ? '#E0EDFF' : AgentClawDesign.controlSurface)
            .borderRadius(8)
        }

        if (this.bubbleImageURL(message) !== null) {
          GeneratedImageView({ url: this.bubbleImageURL(message) as string })
        }

        ForEach(message.generatedDocuments, (document: GeneratedDocument) => {
          this.documentCard(document)
        }, (document: GeneratedDocument) => document.id)
      }
      .alignItems(message.role === ChatRole.USER ? HorizontalAlign.End : HorizontalAlign.Start)

      if (message.role !== ChatRole.USER) {
        Blank().layoutWeight(1)
      }
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
  }

  private bubbleImageURL(message: ChatMessage): string | null {
    if (message.role !== ChatRole.ASSISTANT) {
      return null;
    }
    return ChatMediaParser.firstImageURL(message.content);
  }

  private bubbleText(message: ChatMessage): string {
    const imageURL = this.bubbleImageURL(message);
    return imageURL === null ? message.content : ChatMediaParser.stripMedia(message.content);
  }

  @Builder
  private documentCard(document: GeneratedDocument) {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Text(Icons.doc).fontSize(18)
        Column({ space: 4 }) {
          Text(document.displayName)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AgentClawDesign.primaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('已保存到 Agent/Exports')
            .fontSize(11)
            .fontColor(AgentClawDesign.secondaryText)
        }
        .alignItems(HorizontalAlign.Start)
      }

      Row({ space: 12 }) {
        Button('预览', { type: ButtonType.Normal })
          .fontSize(12)
          .fontColor(AgentClawDesign.primaryText)
          .backgroundColor(AgentClawDesign.controlSurface)
          .borderRadius(6)
          .width(80)
          .height(32)
          .onClick(() => {
            this.previewDocument = document;
          })

        Button('分享', { type: ButtonType.Normal })
          .fontSize(12)
          .fontColor(AgentClawDesign.primaryText)
          .backgroundColor(AgentClawDesign.controlSurface)
          .borderRadius(6)
          .width(80)
          .height(32)
          .onClick(() => {
            this.shareGeneratedDocument(document);
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .padding(14)
    .constraintSize({ maxWidth: 320 })
    .backgroundColor(Color.White)
    .borderRadius(8)
    .border({ width: 1, color: AgentClawDesign.divider })
    .alignItems(HorizontalAlign.Start)
  }

  private shareGeneratedDocument(document: GeneratedDocument): void {
    const context = getContext(this) as common.UIAbilityContext;
    const path = GeneratedDocumentStore.shared.fileURL(document);
    ShareUtil.shareFile(context, path, document.mimeType).catch((error: Error) => {
      this.store.errorMessage = `分享失败：${error.message}`;
    });
  }

  @Builder
  private thinkingIndicator() {
    Row({ space: 8 }) {
      LoadingProgress().width(16).height(16).color(AgentClawDesign.secondaryText)
      Text('思考中').fontSize(12).fontColor(AgentClawDesign.secondaryText)
    }
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  private errorBanner(text: string) {
    Row({ space: 8 }) {
      Text(Icons.warning).fontSize(13).fontColor('#B81F1F')
      Text(text).fontSize(12).fontColor('#B81F1F').maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 9, bottom: 9 })
    .backgroundColor('#FFEDED')
  }

  @Builder
  private composer() {
    Column({ space: 8 }) {
      Scroll() {
        Row({ space: 8 }) {
          this.entryButton(Icons.photo, 'AI图文', ChatEntryMode.IMAGE)
          this.entryButton(Icons.video, 'AI视频', ChatEntryMode.VIDEO)
        }
        .padding({ left: 4, right: 4 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)

      Row({ space: 8 }) {
        TextArea({ text: this.store.draft, placeholder: this.composerHint() })
          .fontSize(13)
          .fontColor(AgentClawDesign.primaryText)
          .placeholderColor('rgba(0,0,0,0.34)')
          .backgroundColor(Color.White)
          .enterKeyType(EnterKeyType.Send)
          .constraintSize({ minHeight: 50, maxHeight: 118 })
          .layoutWeight(1)
          .borderRadius(8)
          .border({ width: 1, color: AgentClawDesign.divider })
          .onChange((value: string) => {
            this.store.draft = value;
          })
          .onSubmit(() => {
            this.handleSend();
          })

        Button(this.store.isSending ? Icons.stop : Icons.send)
          .fontColor(Color.White)
          .width(40)
          .height(40)
          .backgroundColor(this.canSend() ? AgentClawDesign.accent : 'rgba(128,128,128,0.5)')
          .borderRadius(8)
          .enabled(this.canSend())
          .onClick(() => {
            this.handleSend();
          })
      }
      .alignItems(VerticalAlign.Bottom)

      Text('内容由AI生成，仅供参考')
        .fontSize(12)
        .fontColor(AgentClawDesign.secondaryText)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 4 })
    }
    .padding({ left: 16, right: 8, top: 8, bottom: 12 })
    .backgroundColor(AgentClawDesign.controlSurface)
  }

  @Builder
  private entryButton(icon: string, title: string, mode: ChatEntryMode) {
    Row({ space: 5 }) {
      Text(icon).fontSize(12).fontColor(AgentClawDesign.primaryText)
      Text(title).fontSize(12).fontColor(AgentClawDesign.primaryText)
    }
    .id(`entry-${mode}`)
    .padding({ left: 10, right: 10 })
    .height(30)
    .backgroundColor(this.store.selectedEntryMode === mode ? 'rgba(59,120,242,0.16)' : Color.White)
    .border({
      width: 1,
      color: this.store.selectedEntryMode === mode ? 'rgba(59,120,242,0.55)' : Color.Transparent
    })
    .borderRadius(8)
    .onClick(() => {
      this.store.createSession(mode);
    })
  }

  private composerHint(): string {
    if (this.store.selectedEntryMode === ChatEntryMode.IMAGE) {
      return '输入描述你想要的图片';
    }
    if (this.store.selectedEntryMode === ChatEntryMode.VIDEO) {
      return '输入描述你想要的视频';
    }
    return '描述任务或提问任何问题';
  }

  private canSend(): boolean {
    return this.store.draft.trim().length > 0 && !this.store.isSending;
  }

  private handleSend(): void {
    if (this.canSend()) {
      this.store.send();
    }
  }
}

@Component
struct GeneratedImageView {
  url: string = '';
  @State private isSaving: boolean = false;
  @State private loadFailed: boolean = false;
  @State private alertMessage: string | null = null;

  build() {
    Stack() {
      Image(this.url)
        .constraintSize({ maxWidth: 240, maxHeight: 240 })
        .objectFit(ImageFit.Contain)
        .onError(() => {
          this.loadFailed = true;
        })

      if (this.isSaving) {
        LoadingProgress().width(24).height(24).color(AgentClawDesign.secondaryText)
      }
    }
    .backgroundColor(Color.White)
    .borderRadius(8)
    .border({ width: 1, color: AgentClawDesign.divider })
    .onClick(() => {
      this.saveToPhotos();
    })
  }

  private saveToPhotos(): void {
    if (this.isSaving) {
      return;
    }
    this.isSaving = true;
    const context = getContext(this) as common.UIAbilityContext;
    ImageSaver.saveNetworkImageToGallery(context, this.url)
      .then(() => {
        this.alertMessage = '已保存到相册';
      })
      .catch((error: Error) => {
        this.alertMessage = `图片保存失败：${error.message}`;
      })
      .finally(() => {
        this.isSaving = false;
        if (this.alertMessage !== null) {
          AlertDialog.show({
            title: '图片保存',
            message: this.alertMessage,
            confirm: {
              value: '确定',
              action: () => {
                this.alertMessage = null;
              }
            }
          });
        }
      });
  }
}
