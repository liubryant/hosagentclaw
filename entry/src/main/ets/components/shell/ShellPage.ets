/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { webview } from '@kit.ArkWeb';
import { AgentClawDesign } from '../../common/Design';
import { Icons } from '../../common/Icons';
import { ChatStore } from '../../store/ChatStore';
import { LocalChatSession } from '../../model/ChatModels';
import { ChatEntryMode } from '../../model/ChatModels';
import { ChatPanel } from '../chat/ChatPanel';
import { FancyIdeasPage } from '../ideas/FancyIdeasPage';
import { FancyIdea } from '../ideas/FancyIdeaData';
import { SettingsPanel } from '../settings/SettingsPanel';
import { DocumentsListPage } from '../documents/DocumentsListPage';
import { LoginDialog } from '../account/LoginDialog';
import { CreationGalleryPage } from '../creation/CreationGalleryPage';
import { ProfilePage } from '../profile/ProfilePage';
import { AppPreferences } from '../../storage/AppPreferences';

type BottomTab = 'chat' | 'creation' | 'profile';

@Component
export struct ShellPage {
  private store: ChatStore = new ChatStore();
  @State private activeTab: BottomTab = 'creation';
  @State private isSidebarVisible: boolean = true;
  @State private isCreationFullscreen: boolean = false;
  @State private isSettingsPresented: boolean = false;
  @State private isDocumentsPresented: boolean = false;
  @State private isLoginPresented: boolean = false;
  @State private isIdeasPresented: boolean = false;
  @State private sidebarQuery: string = '';
  @State private webViewUrl: string = '';
  @State private webViewTitle: string = '';
  @State private fullscreenVideoURL: string = '';
  @State private fullscreenVideoCoverURL: string = '';
  @State private videoPlaybackError: string = '';
  @State private webviewController: webview.WebviewController = new webview.WebviewController();
  @State private isLoggedIn: boolean = false;
  @State private userPhone: string = '';

  aboutToAppear(): void {
    this.refreshLoginState();
  }

  private refreshLoginState(): void {
    this.isLoggedIn = AppPreferences.shared.isLoggedIn;
    this.userPhone = AppPreferences.shared.userPhone ?? '';
  }

  private maskedPhone(phone: string): string {
    if (phone.length !== 11) {
      return phone;
    }
    return `${phone.substring(0, 3)}****${phone.substring(7)}`;
  }

  build() {
    Stack() {
      Column() {
        Row() {
          if (this.isSidebarVisible && this.activeTab === 'chat') {
            this.sidebar()
          }

          Column() {
            if (!this.isCreationFullscreen) {
              this.chatHeader()
              Divider().color(AgentClawDesign.divider).strokeWidth(0.5)
            }

            if (this.activeTab === 'creation') {
              CreationGalleryPage({
                onLaunchImageChat: () => {
                  this.activeTab = 'chat';
                  this.isSidebarVisible = true;
                  this.store.createSession(ChatEntryMode.IMAGE);
                },
                onLaunchVideoChat: () => {
                  this.activeTab = 'chat';
                  this.isSidebarVisible = true;
                  this.store.createSession(ChatEntryMode.VIDEO);
                },
                onFullscreenChanged: (fs: boolean) => {
                  this.isCreationFullscreen = fs;
                }
              })
                .layoutWeight(1)
            } else if (this.activeTab === 'profile') {
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
                }
              })
                .layoutWeight(1)
            } else {
              ChatPanel({
                store: this.store,
                onOpenVideo: (url: string, coverURL: string) => {
                  this.fullscreenVideoURL = url;
                  this.fullscreenVideoCoverURL = coverURL;
                  this.videoPlaybackError = '';
                }
              })
                .layoutWeight(1)
            }

            if (!this.isCreationFullscreen) {
              this.bottomTabBar()
            }
          }
          .layoutWeight(1)
          .backgroundColor(Color.White)
          .borderRadius(this.isSidebarVisible ? 20 : 0)
          .clip(true)
        }
        .layoutWeight(1)
        .width('100%')
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
              this.fullscreenVideoURL = '';
              this.fullscreenVideoCoverURL = '';
              this.videoPlaybackError = '';
            })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#050507')
        .position({ x: 0, y: 0 })
        .zIndex(1000)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private bottomTabBar() {
    Row() {
      this.tabItem('creation')
      if (this.activeTab !== 'chat') {
        this.tabItem('chat')
      }
      this.tabItem('profile')
    }
    .width('100%')
    .height(68)
    .backgroundColor('#FCFFFFFF')
    .border({ width: { top: 0.5 }, color: AgentClawDesign.divider })
    .padding({ left: 12, top: 7, right: 12, bottom: 7 })
  }

  @Builder
  private tabItem(tab: BottomTab) {
    Column({ space: 3 }) {
      Image(tab === 'creation' ? $rawfile('icons/ic_bottom_creation.svg') :
            tab === 'chat' ? $rawfile('icons/ic_bottom_conversation.svg') :
            $rawfile('icons/ic_bottom_profile.svg'))
        .width(22)
        .height(22)
        .fillColor(this.activeTab === tab ? Color.White : '#7B8190')
      Text(tab === 'creation' ? '画图' : tab === 'chat' ? '对话' : '我的')
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
    .scale({ x: this.activeTab === tab ? 1.0 : 0.94, y: this.activeTab === tab ? 1.0 : 0.94 })
    .animation({ duration: 180, curve: Curve.EaseInOut })
    .onClick(() => {
      this.activeTab = tab;
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
      }
    }
    .width('40%')
    .padding({ left: 12, right: 10, top: 16, bottom: 16 })
    .height('100%')
    .backgroundColor(AgentClawDesign.sidebarBackground)
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
  private chatHeader() {
    Row() {
      this.headerIconButton($rawfile('icons/ic_header_sidebar.svg'), 20, () => {
        this.isSidebarVisible = !this.isSidebarVisible;
      })

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
