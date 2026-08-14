/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { webview } from '@kit.ArkWeb';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { AgentClawDesign } from '../../common/Design';
import { Icons } from '../../common/Icons';
import { ChatStore } from '../../store/ChatStore';
import { GeneratedDocumentStore } from '../../store/GeneratedDocumentStore';
import { LocalChatSession } from '../../model/ChatModels';
import { ChatEntryMode } from '../../model/ChatModels';
import { GeneratedDocument } from '../../model/ChatModels';
import { ChatPanel } from '../chat/ChatPanel';
import { FancyIdeasPage } from '../ideas/FancyIdeasPage';
import { FancyIdea } from '../ideas/FancyIdeaData';
import { SettingsPanel } from '../settings/SettingsPanel';
import { DocumentsListPage } from '../documents/DocumentsListPage';
import { LoginDialog } from '../account/LoginDialog';
import { CreationGalleryPage } from '../creation/CreationGalleryPage';
import { ProfilePage } from '../profile/ProfilePage';
import { VipMembershipPage } from '../vip/VipMembershipPage';
import { AvatarPage } from '../avatar/AvatarPage';
import { AppPreferences } from '../../storage/AppPreferences';
import { SystemBarStyle } from '../../common/SystemBarStyle';
import { WindowStageHolder } from '../../common/WindowStageHolder';
import {
  SHORTCUT_ACTION_QUICK_IMAGE,
  SHORTCUT_ACTION_AVATAR,
  SHORTCUT_LAUNCH_EVENT,
  ShortcutLaunchStore
} from '../../common/ShortcutLaunchStore';

type BottomTab = 'chat' | 'creation' | 'avatar' | 'profile';

@Component
export struct ShellPage {
  private store: ChatStore = new ChatStore();
  private readonly shortcutLaunchListener = (action: string): void => {
    this.handleShortcutLaunch(action);
  };
  @State private activeTab: BottomTab = 'creation';
  @StorageProp('shellBottomSafeInset') private bottomSafeInset: number = 24;
  @State private isSidebarVisible: boolean = true;
  @State private isImagePickerSheetVisible: boolean = false;
  @State private isCreationFullscreen: boolean = false;
  @State private isSettingsPresented: boolean = false;
  @State private isDocumentsPresented: boolean = false;
  @State private isLoginPresented: boolean = false;
  @State private isVipPresented: boolean = false;
  @State private isIdeasPresented: boolean = false;
  @State private sidebarQuery: string = '';
  @State private webViewUrl: string = '';
  @State private webViewTitle: string = '';
  @State private fullscreenVideoURL: string = '';
  @State private fullscreenVideoCoverURL: string = '';
  @State private fullscreenImageDocument: GeneratedDocument | null = null;
  @State private videoPlaybackError: string = '';
  @State private webviewController: webview.WebviewController = new webview.WebviewController();
  @State private isLoggedIn: boolean = false;
  @State private userPhone: string = '';
  @State private isTabTransitioning: boolean = false;

  aboutToAppear(): void {
    SystemBarStyle.applyProfileStatusBar(this.activeTab === 'profile');
    this.refreshLoginState();
    WindowStageHolder.abilityContext?.eventHub.on(SHORTCUT_LAUNCH_EVENT, this.shortcutLaunchListener);
    this.handleShortcutLaunch(ShortcutLaunchStore.consume());
  }

  aboutToDisappear(): void {
    WindowStageHolder.abilityContext?.eventHub.off(SHORTCUT_LAUNCH_EVENT, this.shortcutLaunchListener);
  }

  private handleShortcutLaunch(action: string): void {
    if (action === SHORTCUT_ACTION_AVATAR) {
      ShortcutLaunchStore.consume();
      this.activeTab = 'avatar';
      this.isSidebarVisible = false;
      this.isCreationFullscreen = false;
      return;
    }
    if (action !== SHORTCUT_ACTION_QUICK_IMAGE) {
      return;
    }
    ShortcutLaunchStore.consume();
    this.activeTab = 'chat';
    this.isSidebarVisible = true;
    this.isCreationFullscreen = false;
    this.clearAttachedImage();
    this.store.createSession(ChatEntryMode.IMAGE);
  }

  private refreshLoginState(): void {
    this.isLoggedIn = AppPreferences.shared.isLoggedIn;
    this.userPhone = AppPreferences.shared.userPhone ?? '';
  }

  private openVipPage(): void {
    this.isVipPresented = true;
    SystemBarStyle.applyVip();
  }

  private closeVipPage(): void {
    this.isVipPresented = false;
    SystemBarStyle.restoreDefault();
    this.refreshLoginState();
  }

  private openFullscreenVideo(url: string, coverURL: string): void {
    this.fullscreenVideoURL = url;
    this.fullscreenVideoCoverURL = coverURL;
    this.videoPlaybackError = '';
    SystemBarStyle.applyVideo();
  }

  private closeFullscreenVideo(): void {
    this.fullscreenVideoURL = '';
    this.fullscreenVideoCoverURL = '';
    this.videoPlaybackError = '';
    SystemBarStyle.restoreDefault();
  }

  private clearAttachedImage(): void {
    this.store.attachedImageUri = '';
    this.store.attachedImageBase64 = null;
  }

  private closeImagePickerSheet(): void {
    this.isImagePickerSheetVisible = false;
  }

  private pickImageFromCamera(): void {
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
      this.store.attachedImageUri = uri;

      this.encodeImageToBase64(uri).then((base64: string) => {
        this.store.attachedImageBase64 = base64;
        this.store.updateEntryMode(ChatEntryMode.IMAGE);
      }).catch((e: Error) => {
        console.error('[ShellPage] Failed to read image file:', e);
        this.clearAttachedImage();
      });
    }).catch((e: Error) => {
      console.warn('[ShellPage] Image picker cancelled or failed:', e);
    });
  }

  private async encodeImageToBase64(uri: string): Promise<string> {
    const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    let sourceBuffer: ArrayBuffer;
    try {
      const stat = fileIo.statSync(file.fd);
      sourceBuffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, sourceBuffer);
    } finally {
      fileIo.closeSync(file.fd);
    }

    try {
      return await this.encodedUploadImageBase64(sourceBuffer);
    } catch (error) {
      throw new Error('图片处理失败，请更换图片或重新选择后再试');
    }
  }

  private async encodedUploadImageBase64(sourceBuffer: ArrayBuffer): Promise<string> {
    const targetBytes = 420 * 1024;
    const maxDimensions: number[] = [1024, 896, 768, 640];
    const qualities: number[] = [68, 58, 48, 38, 30, 24];

    for (const maxDimension of maxDimensions) {
      const jpegBuffer = await this.packUploadImage(sourceBuffer, maxDimension, qualities, targetBytes);
      if (jpegBuffer !== null) {
        return this.base64String(jpegBuffer);
      }
    }

    const fallbackBuffer = await this.packUploadImage(sourceBuffer, 512, [20], Number.MAX_SAFE_INTEGER);
    if (fallbackBuffer === null) {
      throw new Error('图片处理失败，请更换图片或重新选择后再试');
    }
    return this.base64String(fallbackBuffer);
  }

  private async packUploadImage(
    sourceBuffer: ArrayBuffer,
    maxDimension: number,
    qualities: number[],
    targetBytes: number
  ): Promise<ArrayBuffer | null> {
    const imageSource = image.createImageSource(sourceBuffer);
    const pixelMap = await imageSource.createPixelMap();
    try {
      const info = await pixelMap.getImageInfo();
      const width = info.size.width;
      const height = info.size.height;
      const longestSide = Math.max(width, height);
      if (longestSide > maxDimension && longestSide > 0) {
        const ratio = maxDimension / longestSide;
        await pixelMap.scale(ratio, ratio);
      }

      const packer = image.createImagePacker();
      try {
        for (const quality of qualities) {
          const jpegBuffer = await packer.packToData(pixelMap, { format: 'image/jpeg', quality: quality });
          if (jpegBuffer.byteLength <= targetBytes) {
            console.log(`image_edit_payload_image_bytes=${jpegBuffer.byteLength}`);
            return jpegBuffer;
          }
        }
      } finally {
        await packer.release();
      }
    } finally {
      await pixelMap.release();
      await imageSource.release();
    }
    return null;
  }

  private base64String(buffer: ArrayBuffer): string {
    const base64Helper = new util.Base64Helper();
    const base64 = base64Helper.encodeToStringSync(new Uint8Array(buffer));
    console.log(`image_edit_payload_base64_chars=${base64.length}`);
    return base64;
  }

  private maskedPhone(phone: string): string {
    if (phone.length !== 11) {
      return phone;
    }
    return `${phone.substring(0, 3)}****${phone.substring(7)}`;
  }

  private bottomBarHeight(): number {
    return 62 + this.bottomSafeInset;
  }

  build() {
    Stack() {
      Stack({ alignContent: Alignment.Bottom }) {
        Row() {
          if (this.isSidebarVisible && this.activeTab === 'chat') {
            this.sidebar()
          }

          Column() {
            if (!this.isCreationFullscreen && this.activeTab === 'chat') {
              this.chatHeader()
              Divider().color(AgentClawDesign.divider).strokeWidth(0.5)
            }

            Stack() {
              // Keep XComponent visible to the render tree at one fixed size.
              // Hidden/Visible toggles make Tuanjie republish the safe area,
              // changing the viewport and bottom-tab height on every switch.
              AvatarPage({
                isActive: this.activeTab === 'avatar',
                onRequireLogin: () => {
                  this.refreshLoginState();
                  if (!this.isLoggedIn) {
                    this.isLoginPresented = true;
                  }
                },
                onRequireVip: () => {
                  this.openVipPage();
                }
              })
                .width('100%')
                .height('100%')
                .position({ x: this.activeTab === 'avatar' ? 0 : -2000, y: 0 })
                .hitTestBehavior(this.activeTab === 'avatar' ? HitTestMode.Default : HitTestMode.None)

              CreationGalleryPage({
                onLaunchImageChat: (prompt?: string) => {
                  this.activeTab = 'chat';
                  this.isSidebarVisible = true;
                  if (prompt !== undefined && prompt.trim().length > 0) {
                    this.store.createSessionWithDraft(prompt, ChatEntryMode.IMAGE);
                  } else {
                    this.store.createSession(ChatEntryMode.IMAGE);
                  }
                },
                onLaunchVideoChat: () => {
                  this.activeTab = 'chat';
                  this.isSidebarVisible = true;
                  this.store.createSession(ChatEntryMode.VIDEO);
                },
                onFullscreenChanged: (fs: boolean) => {
                  this.isCreationFullscreen = fs;
                  if (fs) {
                    SystemBarStyle.applyImmersiveDark();
                  } else {
                    SystemBarStyle.restoreDefault();
                  }
                }
                })
                .width('100%')
                .height('100%')
                .visibility(this.activeTab === 'creation' ? Visibility.Visible : Visibility.Hidden)
                .hitTestBehavior(this.activeTab === 'creation' ? HitTestMode.Default : HitTestMode.None)

              ProfilePage({
                onOpenSettings: () => {
                  this.isSettingsPresented = true;
                },
                onOpenDocuments: () => {
                  this.isDocumentsPresented = true;
                },
                onOpenWebView: (url: string, title: string) => {
                  this.webViewUrl = url;
                  this.webViewTitle = title;
                },
                onOpenVip: () => {
                  this.openVipPage();
                }
                })
                .width('100%')
                .height('100%')
                .visibility(this.activeTab === 'profile' ? Visibility.Visible : Visibility.Hidden)
                .hitTestBehavior(this.activeTab === 'profile' ? HitTestMode.Default : HitTestMode.None)

              ChatPanel({
                store: this.store,
                onOpenVideo: (url: string, coverURL: string) => {
                  this.openFullscreenVideo(url, coverURL);
                },
                onRequireLogin: () => {
                  this.refreshLoginState();
                  if (!this.isLoggedIn) {
                    this.isLoginPresented = true;
                  }
                },
                onImagePickerOpen: () => {
                  this.isImagePickerSheetVisible = true;
                },
                onClearAttachedImage: () => {
                  this.clearAttachedImage();
                },
                onOpenImagePreview: (document: GeneratedDocument) => {
                  this.fullscreenImageDocument = document;
                }
                })
                .width('100%')
                .height('100%')
                .visibility(this.activeTab === 'chat' ? Visibility.Visible : Visibility.Hidden)
                .hitTestBehavior(this.activeTab === 'chat' ? HitTestMode.Default : HitTestMode.None)
            }
            .layoutWeight(1)
            .width('100%')

          }
          .layoutWeight(1)
          .backgroundColor(Color.White)
          .borderRadius(this.isSidebarVisible && this.activeTab === 'chat' ? 20 : 0)
          .clip(true)
        }
        .height('100%')
        .width('100%')
        .padding({ bottom: this.isCreationFullscreen ? 0 : this.bottomBarHeight() })

        if (!this.isCreationFullscreen) {
          this.bottomTabBar()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AgentClawDesign.appBackground)

      if (this.isSettingsPresented) {
        SettingsPanel({
          store: this.store,
          onClose: () => {
            this.isSettingsPresented = false;
          },
          onOpenWebView: (url: string, title: string) => {
            this.webViewUrl = url;
            this.webViewTitle = title;
          }
        })
      }

      if (this.isDocumentsPresented) {
        DocumentsListPage({
          store: this.store,
          onClose: () => {
            this.isDocumentsPresented = false;
          },
          onOpenVideo: (url: string, coverURL: string) => {
            this.isDocumentsPresented = false;
            this.openFullscreenVideo(url, coverURL);
          }
        })
      }


      if (this.isLoginPresented) {
        LoginDialog({
          onClose: () => {
            this.isLoginPresented = false;
            this.refreshLoginState();
          }
        })
      }

      if (this.isVipPresented) {
        VipMembershipPage({
          onClose: () => {
            this.closeVipPage();
          },
          onRequireLogin: () => {
            this.refreshLoginState();
            if (!this.isLoggedIn) {
              this.closeVipPage();
              this.isLoginPresented = true;
            }
          },
          onOpenWebView: (url: string, title: string) => {
            this.closeVipPage();
            this.webViewUrl = url;
            this.webViewTitle = title;
          }
        })
          .width('100%')
          .height('100%')
          .position({ x: 0, y: 0 })
          .zIndex(1001)
      }

      if (this.isImagePickerSheetVisible) {
        this.imagePickerSheet()
      }

      if (this.isIdeasPresented) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0.3)')
            .onClick(() => {
              this.isIdeasPresented = false;
            })

          Column() {
            Row() {
              Text('灵感泉涌')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontFamily('MiSans-DemiBold')
                .fontColor(AgentClawDesign.primaryText)
                .layoutWeight(1)
              Text(Icons.close)
                .fontSize(14)
                .fontColor(AgentClawDesign.secondaryText)
                .onClick(() => {
                  this.isIdeasPresented = false;
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 8 })

            FancyIdeasPage({
              onUseIdea: (idea: FancyIdea) => {
                this.isIdeasPresented = false;
                this.activeTab = 'chat';
                this.store.createSessionWithDraft(idea.prompt);
              }
            })
              .layoutWeight(1)
          }
          .width('100%')
          .height('80%')
          .backgroundColor(Color.White)
          .borderRadius({ topLeft: 16, topRight: 16 })
          .alignSelf(ItemAlign.End)
        }
        .width('100%')
        .height('100%')
      }

      if (this.webViewUrl.length > 0) {
        Column() {
          Row({ space: 8 }) {
            Text('←')
              .fontSize(18)
              .fontColor(AgentClawDesign.primaryText)
              .width(44)
              .height(44)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.webViewUrl = '';
                this.webViewTitle = '';
              })
            Text(this.webViewTitle)
              .fontSize(15)
              .fontFamily('MiSans-DemiBold')
              .fontColor(AgentClawDesign.primaryText)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .height(52)
          .padding({ left: 4, right: 16 })
          .backgroundColor(Color.White)
          .border({ width: { bottom: 0.5 }, color: AgentClawDesign.divider })

          Web({ src: this.webViewUrl, controller: this.webviewController })
            .layoutWeight(1)
            .width('100%')
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.White)
        .position({ x: 0, y: 0 })
        .zIndex(999)
      }

      if (this.fullscreenVideoURL.length > 0) {
        Stack() {
          if (this.fullscreenVideoCoverURL.length > 0) {
            Image(this.fullscreenVideoCoverURL)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
              .opacity(0.32)
          }

          Video({ src: this.fullscreenVideoURL })
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .controls(false)
            .autoPlay(true)
            .loop(true)
            .onError(() => {
              this.videoPlaybackError = '视频加载失败，请检查网络后重试';
            })

          if (this.videoPlaybackError.length > 0) {
            Text(this.videoPlaybackError)
              .fontSize(13)
              .fontColor(Color.White)
              .padding(12)
              .backgroundColor('rgba(0,0,0,0.62)')
              .borderRadius(8)
          }

          Text('✕')
            .fontSize(18)
            .fontColor(Color.White)
            .width(44)
            .height(44)
            .textAlign(TextAlign.Center)
            .backgroundColor('rgba(0,0,0,0.58)')
            .borderRadius(22)
            .position({ x: 18, y: 54 })
            .onClick(() => {
              this.closeFullscreenVideo();
            })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#050507')
        .position({ x: 0, y: 0 })
        .zIndex(1000)
      }

      if (this.fullscreenImageDocument !== null) {
        this.fullscreenImagePreview(this.fullscreenImageDocument)
      }

    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private fullscreenImagePreview(document: GeneratedDocument) {
    Stack() {
      Column() {
        Row() {
          Text(document.displayName)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(Icons.close)
            .fontSize(18)
            .fontColor(Color.White)
            .padding(12)
            .onClick(() => {
              this.fullscreenImageDocument = null;
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 8 })

        Image(fileUri.getUriFromPath(GeneratedDocumentStore.shared.fileURL(document)))
          .layoutWeight(1)
          .width('100%')
          .objectFit(ImageFit.Contain)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#EE000000')
    .zIndex(1002)
  }

  @Builder
  private bottomTabBar() {
    Row() {
      this.tabItem('creation')
      this.tabItem('chat')
      this.tabItem('avatar')
      this.tabItem('profile')
    }
    .width('100%')
    .height(this.bottomBarHeight())
    .backgroundColor('#FCFFFFFF')
    .border({ width: { top: 0.5 }, color: AgentClawDesign.divider })
    .padding({ left: 12, top: 6, right: 12, bottom: 2 + this.bottomSafeInset })
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      console.info(`tuanjiehub bottom_tab_area tab=${this.activeTab} width=${newValue.width} height=${newValue.height} x=${newValue.position.x} y=${newValue.position.y}`);
    })
  }

  @Builder
  private tabItem(tab: BottomTab) {
    Column({ space: 3 }) {
      if (tab === 'avatar') {
        Stack({ alignContent: Alignment.Center }) {
          Stack({ alignContent: Alignment.Center }) {
            Image($rawfile('icons/lily_tab_thumbnail.png'))
              .width(29)
              .height(29)
              .objectFit(ImageFit.Cover)
          }
          .width(29)
          .height(29)
          .borderRadius(15)
          .clip(true)
        }
        .width(31)
        .height(31)
      } else {
        Image(tab === 'creation' ? $rawfile('icons/ic_bottom_creation.svg') :
              tab === 'chat' ? $rawfile('icons/ic_bottom_conversation.svg') :
              $rawfile('icons/ic_bottom_profile.svg'))
          .width(22)
          .height(22)
          .fillColor(this.activeTab === tab ? Color.White : '#7B8190')
      }
      Text(tab === 'creation' ? '画图' : tab === 'chat' ? '对话' : tab === 'avatar' ? '智能体' : '我的')
        .fontSize(11)
        .fontFamily('MiSans-DemiBold')
        .fontColor(this.activeTab === tab ? Color.White : '#7B8190')
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .borderRadius(15)
    .linearGradient(this.activeTab === tab ? {
      angle: 0,
      colors: [['#7557F6', 0], ['#A451EE', 1]] as [string, number][]
    } : { angle: 0, colors: [['rgba(0,0,0,0)', 0], ['rgba(0,0,0,0)', 1]] as [string, number][] })
    .onClick(() => {
      if (this.activeTab === tab || this.isTabTransitioning) {
        return;
      }
      const involvesAvatarSurface = this.activeTab === 'avatar' || tab === 'avatar';
      if (involvesAvatarSurface) {
        this.isTabTransitioning = true;
        setTimeout((): void => {
          this.isTabTransitioning = false;
        }, 260);
      }
      console.info(`tuanjiehub tab_select from=${this.activeTab} to=${tab}`);
      this.activeTab = tab;
      SystemBarStyle.applyProfileStatusBar(tab === 'profile');
      if (tab === 'chat') {
        this.isSidebarVisible = true;
      }
      this.isCreationFullscreen = false;
    })
  }

  @Builder
  private sidebar() {
    Column({ space: 12 }) {
      this.searchField()

      Row({ space: 6 }) {
        Text(Icons.newChat).fontSize(13).fontColor(AgentClawDesign.primaryText)
        Text('新对话')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontFamily('MiSans-DemiBold')
          .fontColor(AgentClawDesign.primaryText)
        Blank().layoutWeight(1)
      }
      .padding({ left: 14, right: 14 })
      .height(38)
      .backgroundColor('rgba(255,255,255,0.72)')
      .borderRadius(8)
      .onClick(() => {
        this.guardedCreateSession(() => { this.store.createSession(); });
      })

      Scroll() {
        Column({ space: 6 }) {
          ForEach(this.filteredSessions(), (session: LocalChatSession) => {
            this.sessionRow(session)
          }, (session: LocalChatSession) => session.id)
        }
        .width('100%')
        .padding({ top: 2 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)

      Column({ space: 4 }) {
        this.sidebarNavItem(Icons.sparkles, '灵感泉涌', '提示词模板', () => {
          this.isIdeasPresented = true;
        })
        this.sidebarNavItem(Icons.folder, '文件', '文件与分享', () => {
          this.isDocumentsPresented = true;
        })
        this.sidebarNavItem(
          Icons.login,
          this.isLoggedIn ? (this.userPhone.length > 0 ? this.maskedPhone(this.userPhone) : '已登录') : '登录',
          this.isLoggedIn ? '点击管理账户' : '登录解锁更多功能',
          () => { this.isLoginPresented = true; }
        )
        this.sidebarNavItem(Icons.sidebar, '设置', '技能和关于', () => {
          this.isSettingsPresented = true;
        })
        this.sidebarVipItem(() => {
          this.openVipPage();
        })
      }
    }
    .width('40%')
    .padding({ left: 12, right: 10, top: 16, bottom: 16 })
    .height('100%')
    .backgroundColor(AgentClawDesign.sidebarBackground)
  }

  @Builder
  private imagePickerSheet() {
    Column() {
      Column()
        .layoutWeight(1)
        .width('100%')
        .onClick(() => {
          this.closeImagePickerSheet();
        })

      Column({ space: 0 }) {
        Row()
          .width(36)
          .height(4)
          .borderRadius(2)
          .backgroundColor('rgba(0,0,0,0.18)')
          .margin({ top: 10, bottom: 0 })

        Text('选择图片')
          .fontSize(15)
          .fontFamily('MiSans')
          .fontWeight(FontWeight.Bold)
          .fontColor(AgentClawDesign.primaryText)
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: 16, bottom: 4 })

        Row({ space: 16 }) {
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
            this.closeImagePickerSheet();
            this.pickImageFromCamera();
          })

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
            this.closeImagePickerSheet();
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
    .position({ x: 0, y: 0 })
    .zIndex(1002)
  }

  @Builder
  private searchField() {
    Row({ space: 6 }) {
      Text(Icons.search).fontSize(11)
      TextInput({ text: this.sidebarQuery, placeholder: '搜索历史' })
        .fontSize(12)
        .fontFamily('MiSans')
        .fontColor(AgentClawDesign.primaryText)
        .placeholderColor(AgentClawDesign.secondaryText)
        .backgroundColor(Color.Transparent)
        .layoutWeight(1)
        .height(32)
        .padding(0)
        .onChange((value: string) => {
          this.sidebarQuery = value;
        })
    }
    .padding({ left: 8, right: 8 })
    .height(32)
    .backgroundColor('rgba(255,255,255,0.76)')
    .borderRadius(8)
  }

  private filteredSessions(): LocalChatSession[] {
    const query = this.sidebarQuery.trim().toLowerCase();
    if (query.length === 0) {
      return this.store.sessions;
    }
    return this.store.sessions.filter(item => item.title.toLowerCase().includes(query));
  }

  @Builder
  private sessionRow(session: LocalChatSession) {
    Row({ space: 10 }) {
      Text(Icons.message)
        .fontSize(11)
        .fontColor(session.id === this.store.selectedSessionID ? AgentClawDesign.accent : AgentClawDesign.secondaryText)

      Column({ space: 3 }) {
        Text(session.title)
          .fontSize(11)
          .fontFamily('MiSans')
          .fontWeight(session.id === this.store.selectedSessionID ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(AgentClawDesign.primaryText)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.formattedTime(session.updatedAt))
          .fontSize(10)
          .fontFamily('MiSans-Normal')
          .fontColor(AgentClawDesign.secondaryText)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(Icons.trash)
        .fontSize(11)
        .fontColor(AgentClawDesign.secondaryText)
        .onClick(() => {
          this.confirmDelete(session);
        })
    }
    .width('100%')
    .height(38)
    .padding({ left: 8, right: 8 })
    .backgroundColor(session.id === this.store.selectedSessionID ? Color.White : 'rgba(255,255,255,0.42)')
    .borderRadius(8)
    .onClick(() => {
      this.guardedCreateSession(() => { this.store.selectSession(session); });
    })
  }

  private guardedCreateSession(action: () => void): void {
    if (this.store.isSending) {
      AlertDialog.show({
        title: 'AI 正在生成',
        message: '当前对话尚未完成，切换后生成结果仍会保存到原对话。是否继续？',
        primaryButton: {
          value: '继续切换',
          fontColor: '#E5484D',
          action: action
        },
        secondaryButton: {
          value: '取消',
          action: () => {}
        }
      });
    } else {
      action();
    }
  }

  private confirmDelete(session: LocalChatSession): void {
    AlertDialog.show({
      title: '删除对话',
      message: '确定要删除这个对话吗？此操作无法撤销。',
      primaryButton: {
        value: '删除',
        fontColor: '#D0021B',
        action: () => {
          this.store.deleteSession(session);
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    });
  }

  @Builder
  private sidebarNavItem(icon: string, title: string, subtitle: string, action: () => void) {
    Row({ space: 10 }) {
      Text(icon).fontSize(14).fontColor(Color.Black).width(20)

      Column({ space: 2 }) {
        Text(title)
          .fontSize(12)
          .fontFamily('MiSans')
          .fontWeight(FontWeight.Medium)
          .fontColor(AgentClawDesign.primaryText)
        Text(subtitle)
          .fontSize(11)
          .fontFamily('MiSans-Normal')
          .fontColor(AgentClawDesign.secondaryText)
      }
      .alignItems(HorizontalAlign.Start)

      Blank().layoutWeight(1)
    }
    .width('100%')
    .height(40)
    .padding({ left: 10, right: 10 })
    .backgroundColor('rgba(255,255,255,0.44)')
    .borderRadius(8)
    .onClick(action)
  }

  @Builder
  private sidebarVipItem(action: () => void) {
    Column({ space: 5 }) {
      Text('✦  VIP 会员')
        .fontSize(13)
        .fontFamily('MiSans-DemiBold')
        .fontWeight(FontWeight.Bold)
        .fontColor('#F5D69D')
        .width('100%')
        .textAlign(TextAlign.Center)

      Text('解锁满血 AI')
        .fontSize(10)
        .fontFamily('MiSans')
        .fontColor('#C9AA79')
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(56)
    .padding({ left: 12, right: 12 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .linearGradient({
      angle: 90,
      colors: [['#2B211A', 0.0], ['#3D2B1F', 0.55], ['#211914', 1.0]]
    })
    .border({ width: 1, color: '#6F5133' })
    .borderRadius(12)
    .onClick(action)
  }

  @Builder
  private chatHeader() {
    Row() {
      if (this.activeTab === 'chat') {
        this.headerIconButton($rawfile('icons/ic_header_sidebar.svg'), 20, () => {
          this.isSidebarVisible = !this.isSidebarVisible;
        })
      }

      this.headerIconButton($rawfile('icons/ic_header_new_chat.svg'), 18, () => {
        this.guardedCreateSession(() => { this.store.createSession(); });
      })

      Blank().layoutWeight(1)

      Row() {
        Image($r('app.media.slide_setting')).width(20).height(20)
      }
      .width(36)
      .height(36)
      .alignItems(VerticalAlign.Center)
      .borderRadius(10)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.isSettingsPresented = true;
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  @Builder
  private headerIconButton(icon: ResourceStr, iconSize: number, action: () => void) {
    Row() {
      Image(icon).width(iconSize).height(iconSize).fillColor('#1A1A2E')
    }
    .width(36)
    .height(36)
    .alignItems(VerticalAlign.Center)
    .borderRadius(10)
    .justifyContent(FlexAlign.Center)
    .onClick(action)
  }

  private formattedTime(timestamp: number): string {
    const date = new Date(timestamp);
    const pad = (value: number): string => value < 10 ? `0${value}` : `${value}`;
    return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }
}
