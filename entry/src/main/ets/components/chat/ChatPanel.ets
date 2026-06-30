import { common } from '@kit.AbilityKit';
import { inputMethod } from '@kit.IMEKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { AgentClawDesign } from '../../common/Design';
import { Icons } from '../../common/Icons';
import { ImageSaver } from '../../common/ImageSaver';
import { ShareUtil } from '../../common/ShareUtil';
import { ChatStore } from '../../store/ChatStore';
import { GeneratedDocumentStore } from '../../store/GeneratedDocumentStore';
import { ChatEntryMode, ChatMessage, ChatRole, GeneratedDocument } from '../../model/ChatModels';
import { DocumentPreviewOverlay } from '../documents/DocumentPreviewPage';
import { TodayHotspotItem, TodayHotspotService } from '../../gateway/TodayHotspotService';

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

// Background images for hotspot cards, cycling in order
const HOTSPOT_BG_IMAGES: ResourceStr[] = [
  $r('app.media.img_chat_idea_skill'),
  $r('app.media.img_chat_idea_life'),
  $r('app.media.img_chat_idea_docs')
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
          !line.startsWith('Video link') &&
          !line.startsWith('视频封面') &&
          !line.toLowerCase().startsWith('cover_image_url');
      });

    return cleanedLines.join('\n').replace(/\n{3,}/g, '\n\n').trim();
  }

  static firstVideoURL(content: string): string | null {
    const genericRegex = new RegExp(GENERIC_URL_PATTERN);
    let match: RegExpExecArray | null;
    while ((match = genericRegex.exec(content)) !== null) {
      const normalized = ChatMediaParser.normalize(match[0]);
      if (ChatMediaParser.isVideoURL(normalized)) {
        return normalized;
      }
    }
    return null;
  }

  static firstVideoCoverURL(content: string): string | null {
    const lines = content.split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      const lower = trimmed.toLowerCase();
      if (trimmed.startsWith('视频封面') || lower.startsWith('cover_image_url') || lower.startsWith('cover image')) {
        const separator = trimmed.indexOf(':') >= 0 ? trimmed.indexOf(':') : trimmed.indexOf('：');
        if (separator >= 0) {
          const normalized = ChatMediaParser.normalize(trimmed.substring(separator + 1));
          if (ChatMediaParser.isImageURL(normalized)) {
            return normalized;
          }
        }
      }
    }
    return null;
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
 * 更新：热点话题欢迎页、入口按钮反选、图片附件。
 */
@Component
export struct ChatPanel {
  store: ChatStore = new ChatStore();
  onOpenVideo: (url: string, coverURL: string) => void = () => {};
  @State private previewDocument: GeneratedDocument | null = null;
  @State private hotspots: TodayHotspotItem[] = [];
  @State private isLoadingHotspots: boolean = false;
  @State private attachedImageUri: string = '';
  @State private isImagePickerSheetVisible: boolean = false;
  @State private panelWidth: number = 360;

  aboutToAppear(): void {
    this.loadHotspots();
  }

  private loadHotspots(): void {
    this.isLoadingHotspots = true;
    TodayHotspotService.shared.fetchHotspots()
      .then((items: TodayHotspotItem[]) => {
        this.hotspots = items;
      })
      .catch(() => {
        this.hotspots = [];
      })
      .finally(() => {
        this.isLoadingHotspots = false;
      });
  }

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

      // Image picker bottom sheet
      if (this.isImagePickerSheetVisible) {
        Column() {
          // Dim tap-to-dismiss area above sheet
          Column()
            .layoutWeight(1)
            .width('100%')
            .onClick(() => {
              this.isImagePickerSheetVisible = false;
            })

          // Sheet anchored at bottom
          Column({ space: 0 }) {
            // Drag handle
            Row()
              .width(36)
              .height(4)
              .borderRadius(2)
              .backgroundColor('rgba(0,0,0,0.18)')
              .margin({ top: 10, bottom: 0 })

            // Title
            Text('选择图片')
              .fontSize(15)
              .fontFamily('MiSans')
              .fontWeight(FontWeight.Bold)
              .fontColor(AgentClawDesign.primaryText)
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ top: 16, bottom: 4 })

            // Options row — matches Android bottom_sheet_image_picker.xml
            Row({ space: 16 }) {
              // Camera option
              Column({ space: 12 }) {
                Column() {
                  Text('📷')
                    .fontSize(28)
                    .fontColor(Color.White)
                }
                .width(72)
                .height(72)
                .borderRadius(36)
                .justifyContent(FlexAlign.Center)
                .backgroundColor('#4DADF7')

                Text('拍照')
                  .fontSize(13)
                  .fontFamily('MiSans')
                  .fontColor(AgentClawDesign.primaryText)
              }
              .justifyContent(FlexAlign.Center)
              .layoutWeight(1)
              .padding({ top: 24, bottom: 24 })
              .backgroundColor('#F7F8FA')
              .borderRadius(12)
              .onClick(() => {
                this.isImagePickerSheetVisible = false;
                this.pickImageFromCamera();
              })

              // Gallery option
              Column({ space: 12 }) {
                Column() {
                  Text('🖼')
                    .fontSize(28)
                    .fontColor(Color.White)
                }
                .width(72)
                .height(72)
                .borderRadius(36)
                .justifyContent(FlexAlign.Center)
                .backgroundColor('#FF8C61')

                Text('从相册选择')
                  .fontSize(13)
                  .fontFamily('MiSans')
                  .fontColor(AgentClawDesign.primaryText)
              }
              .justifyContent(FlexAlign.Center)
              .layoutWeight(1)
              .padding({ top: 24, bottom: 24 })
              .backgroundColor('#F7F8FA')
              .borderRadius(12)
              .onClick(() => {
                this.isImagePickerSheetVisible = false;
                this.pickImage();
              })
            }
            .width('100%')
            .padding({ left: 32, right: 32, top: 20, bottom: 4 })
          }
          .width('100%')
          .backgroundColor(Color.White)
          .borderRadius({ topLeft: 16, topRight: 16 })
          .padding({ bottom: 24 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.panelWidth = Number(newValue.width);
    })
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
      Stack() {
        Column()
          .width(48)
          .height(48)
          .borderRadius(24)
          .linearGradient({
            angle: 135,
            colors: [['#7658F7', 0], ['#C85CC7', 1]] as [string, number][]
          })

        Text('AI')
          .fontSize(16)
          .fontFamily('MiSans-DemiBold')
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)

        Text('✦')
          .fontSize(10)
          .fontColor(Color.White)
          .margin({ left: 31, bottom: 31 })
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .border({ width: 2, color: 'rgba(255,255,255,0.72)' })
      .shadow({ radius: 8, color: 'rgba(118,88,247,0.22)', offsetX: 0, offsetY: 4 })

      Text('7x24小时，随时随地召唤的全能电脑AI助手')
        .fontSize(12)
        .fontFamily('MiSans-Normal')
        .fontColor(AgentClawDesign.secondaryText)
        .textAlign(TextAlign.Center)
        .margin({ top: 18 })

      Column({ space: 8 }) {
        if (this.hotspots.length > 0) {
          // Dynamic hot topics from API
          ForEach(this.hotspots, (item: TodayHotspotItem, index: number) => {
            Row({ space: 8 }) {
              Column({ space: 6 }) {
                Text(item.title)
                  .fontSize(12)
                  .fontFamily('MiSans')
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#333333')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(item.subtitle)
                  .fontSize(12)
                  .fontFamily('MiSans-Normal')
                  .fontColor(AgentClawDesign.secondaryText)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Image(HOTSPOT_BG_IMAGES[index % HOTSPOT_BG_IMAGES.length])
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
              this.store.resetToDefaultMode();
              this.store.draft = item.prompt;
            })
          }, (item: TodayHotspotItem, index: number) => `hotspot-${index}`)
        } else {
          // Fallback: static quick prompts
          ForEach(QUICK_PROMPTS, (item: QuickPrompt) => {
            Row({ space: 8 }) {
              Column({ space: 6 }) {
                Text(item.title)
                  .fontSize(12)
                  .fontFamily('MiSans')
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#333333')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(item.subtitle)
                  .fontSize(12)
                  .fontFamily('MiSans-Normal')
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
              this.store.resetToDefaultMode();
              this.store.draft = item.prompt;
            })
          })
        }
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
          .fontFamily('MiSans')
          .fontWeight(FontWeight.Medium)
          .fontColor(AgentClawDesign.secondaryText)

        if (this.bubbleText(message).length > 0 ||
          (this.bubbleImageURL(message) === null && this.bubbleVideoURL(message) === null)) {
          Text(this.bubbleText(message).length === 0 ? '...' : this.bubbleText(message))
            .fontSize(13)
            .fontFamily('MiSans')
            .fontColor(AgentClawDesign.primaryText)
            .padding({ left: 11, right: 11, top: 8, bottom: 8 })
            .backgroundColor(message.role === ChatRole.USER ? '#E0EDFF' : AgentClawDesign.controlSurface)
            .borderRadius(8)
        }

        if (this.bubbleImageURL(message) !== null) {
          GeneratedImageView({ url: this.bubbleImageURL(message) as string })
        }

        if (this.bubbleVideoURL(message) !== null) {
          this.generatedVideoCard(
            this.bubbleVideoURL(message) as string,
            this.bubbleVideoCoverURL(message) ?? ''
          )
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
    if (ChatMediaParser.firstVideoURL(message.content) !== null) {
      return null;
    }
    return ChatMediaParser.firstImageURL(message.content);
  }

  private bubbleVideoURL(message: ChatMessage): string | null {
    if (message.role !== ChatRole.ASSISTANT) {
      return null;
    }
    return ChatMediaParser.firstVideoURL(message.content);
  }

  private bubbleVideoCoverURL(message: ChatMessage): string | null {
    if (message.role !== ChatRole.ASSISTANT) {
      return null;
    }
    return ChatMediaParser.firstVideoCoverURL(message.content);
  }

  private bubbleText(message: ChatMessage): string {
    const imageURL = this.bubbleImageURL(message);
    const videoURL = this.bubbleVideoURL(message);
    return imageURL === null && videoURL === null ? message.content : ChatMediaParser.stripMedia(message.content);
  }

  @Builder
  private generatedVideoCard(url: string, coverURL: string) {
    Stack() {
      if (coverURL.length > 0) {
        Image(coverURL)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 145,
            colors: [['#7658F7', 0], ['#187FD8', 0.58], ['#5CC6BE', 1]] as [string, number][]
          })
      }

      Column() {
        Text('▶')
          .fontSize(20)
          .fontColor(Color.White)
      }
      .width(52)
      .height(52)
      .borderRadius(26)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('rgba(0,0,0,0.56)')
      .border({ width: 1, color: 'rgba(255,255,255,0.5)' })

      Text('AI生成')
        .fontSize(10)
        .fontColor(Color.White)
        .padding({ left: 7, right: 7, top: 4, bottom: 4 })
        .backgroundColor('rgba(0,0,0,0.52)')
        .borderRadius(5)
        .position({ x: 10, y: 10 })
    }
    .width(this.videoCardWidth())
    .height(this.videoCardHeight())
    .borderRadius(12)
    .clip(true)
    .backgroundColor('#20212B')
    .onClick(() => {
      this.onOpenVideo(url, coverURL);
    })
  }

  private videoCardWidth(): number {
    // 预留消息列表左右 padding 和气泡安全间距；侧栏展开时随 ChatPanel 收窄。
    return Math.max(148, Math.min(260, this.panelWidth - 52));
  }

  private videoCardHeight(): number {
    return Math.round(this.videoCardWidth() * 0.6);
  }

  @Builder
  private documentCard(document: GeneratedDocument) {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Text(Icons.doc).fontSize(18)
        Column({ space: 4 }) {
          Text(document.displayName)
            .fontSize(12)
            .fontFamily('MiSans')
            .fontWeight(FontWeight.Medium)
            .fontColor(AgentClawDesign.primaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('已保存到 Agent/Exports')
            .fontSize(11)
            .fontFamily('MiSans-Normal')
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
    Row({ space: 10 }) {
      LoadingProgress()
        .width(20)
        .height(20)
        .color(AgentClawDesign.accent)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 1 })
      Text(this.store.generationStatus.length > 0 ? this.store.generationStatus : '思考中')
        .fontSize(13)
        .fontFamily('MiSans')
        .fontWeight(FontWeight.Medium)
        .fontColor('#30313A')
        .lineHeight(20)
        .wordBreak(WordBreak.BREAK_ALL)
        .maxLines(8)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .backgroundColor('#F3F1FF')
    .borderRadius(12)
    .border({ width: 1, color: 'rgba(118,88,247,0.18)' })
  }

  @Builder
  private errorBanner(text: string) {
    Row({ space: 8 }) {
      Text(Icons.warning).fontSize(13).fontColor('#B81F1F')
      Text(text).fontSize(12).fontFamily('MiSans').fontColor('#B81F1F').maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 9, bottom: 9 })
    .backgroundColor('#FFEDED')
  }

  @Builder
  private composer() {
    Column({ space: 6 }) {
      // Entry buttons row — ABOVE the composer card
      Scroll() {
        Row({ space: 8 }) {
          this.entryButton(Icons.photo, 'AI图文', ChatEntryMode.IMAGE)
          this.entryButton(Icons.video, 'AI视频', ChatEntryMode.VIDEO)
        }
        .padding({ left: 4, right: 4 })
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .height(32)

      // Composer card
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          // Image thumbnail at top-left when attached
          if (this.store.attachedImageBase64 !== null) {
            Row({ space: 8 }) {
              Stack() {
                Image(this.attachedImageUri.length > 0 ? this.attachedImageUri : '')
                  .width(84)
                  .height(84)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(8)
                  .backgroundColor(AgentClawDesign.controlSurface)

                Text('✕')
                  .fontSize(12)
                  .fontColor(Color.White)
                  .width(20)
                  .height(20)
                  .textAlign(TextAlign.Center)
                  .backgroundColor('rgba(0,0,0,0.55)')
                  .borderRadius(10)
                  .alignSelf(ItemAlign.Start)
                  .margin({ left: 62, top: 2 })
                  .onClick(() => {
                    this.store.attachedImageBase64 = null;
                    this.attachedImageUri = '';
                  })
              }
              .width(84)
              .height(84)
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 8 })
          }

          // Text area takes full width
          TextArea({ text: this.store.draft, placeholder: this.composerHint() })
            .fontSize(15)
            .fontFamily('MiSans')
            .fontColor(AgentClawDesign.primaryText)
            .placeholderColor('rgba(0,0,0,0.34)')
            .backgroundColor(Color.Transparent)
            .enterKeyType(EnterKeyType.Send)
            .constraintSize({ minHeight: 58, maxHeight: 120 })
            .width('100%')
            .padding({ left: 10, right: 10, top: 8, bottom: 58 })
            .onChange((value: string) => {
              this.store.draft = value;
            })
            .onSubmit(() => {
              this.handleSend();
            })
        }
        .width('100%')
        .constraintSize({ minHeight: 90 })

        // Button overlay at bottom-right
        Row({ space: 6 }) {
          // Attach button — only in IMAGE mode
          if (this.store.currentEntryMode === ChatEntryMode.IMAGE) {
            Text('📎')
              .fontSize(18)
              .width(26)
              .height(26)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.isImagePickerSheetVisible = true;
              })
          }

          // Send / Stop button
          Button(this.store.isSending ? Icons.stop : Icons.send)
            .fontColor(Color.White)
            .width(52)
            .height(36)
            .fontSize(14)
            .backgroundColor(this.canSend() ? AgentClawDesign.accent : 'rgba(128,128,128,0.45)')
            .borderRadius(10)
            .enabled(this.canSend())
            .onClick(() => {
              this.handleSend();
            })
        }
        .padding({ right: 8, bottom: 8 })
        .justifyContent(FlexAlign.End)
        .width('100%')
      }
      .width('100%')
      .constraintSize({ minHeight: 90 })
      .backgroundColor(AgentClawDesign.controlSurface)
      .borderRadius(12)

      // Disclaimer text
      Text('内容由AI生成，仅供参考')
        .fontSize(10)
        .fontFamily('MiSans-Normal')
        .fontColor(AgentClawDesign.secondaryText)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 12 })
    .backgroundColor(Color.White)
  }

  @Builder
  private entryButton(icon: string, title: string, mode: ChatEntryMode) {
    Row({ space: 5 }) {
      Text(icon).fontSize(12).fontColor(AgentClawDesign.primaryText)
      Text(title)
        .fontSize(11)
        .fontFamily('MiSans')
        .fontColor(this.store.selectedEntryMode === mode ? AgentClawDesign.accent : AgentClawDesign.primaryText)
    }
    .id(`entry-${mode}`)
    .padding({ left: 12, right: 12 })
    .height(32)
    .backgroundColor(this.store.selectedEntryMode === mode ? 'rgba(57,120,243,0.12)' : AgentClawDesign.controlSurface)
    .border({
      width: 1,
      color: this.store.selectedEntryMode === mode ? 'rgba(57,120,243,0.45)' : Color.Transparent
    })
    .borderRadius(12)
    .onClick(() => {
      this.store.createSession(mode);
      this.attachedImageUri = '';
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
    return (this.store.draft.trim().length > 0 || this.store.attachedImageBase64 !== null) &&
      !this.store.isSending;
  }

  private handleSend(): void {
    if (this.canSend()) {
      // TextArea keeps the input session alive after submit unless it is stopped explicitly.
      inputMethod.getController().stopInputSession().catch(() => {});
      this.store.send();
      // Clear local URI reference after send
      this.attachedImageUri = '';
    }
  }

  private pickImageFromCamera(): void {
    // HarmonyOS camera: use picker.CameraPicker
    // For now fallback to gallery picker since camera needs extra setup
    this.pickImage();
  }

  private pickImage(): void {
    const picker = new photoAccessHelper.PhotoViewPicker();
    picker.select({
      MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1
    }).then((result) => {
      if (result.photoUris.length === 0) {
        return;
      }
      const uri = result.photoUris[0];
      this.attachedImageUri = uri;

      // Read file and convert to base64
      try {
        const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
        const stat = fileIo.statSync(file.fd);
        const buffer = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buffer);
        fileIo.closeSync(file.fd);
        const base64Helper = new util.Base64Helper();
        this.store.attachedImageBase64 = base64Helper.encodeToStringSync(new Uint8Array(buffer));
        this.store.updateEntryMode(ChatEntryMode.IMAGE);
      } catch (e) {
        console.error('[ChatPanel] Failed to read image file:', e);
        this.attachedImageUri = '';
        this.store.attachedImageBase64 = null;
      }
    }).catch((e: Error) => {
      console.warn('[ChatPanel] Image picker cancelled or failed:', e);
    });
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
