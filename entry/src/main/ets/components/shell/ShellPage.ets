import { AgentClawDesign } from '../../common/Design';
import { Icons } from '../../common/Icons';
import { ChatStore } from '../../store/ChatStore';
import { LocalChatSession } from '../../model/ChatModels';
import { ChatPanel } from '../chat/ChatPanel';
import { FancyIdeasPage } from '../ideas/FancyIdeasPage';
import { FancyIdea } from '../ideas/FancyIdeaData';
import { SettingsPanel } from '../settings/SettingsPanel';
import { DocumentsListPage } from '../documents/DocumentsListPage';
import { LoginDialog } from '../account/LoginDialog';

type ShellDestination = 'chat' | 'ideas';

/**
 * 对应 iOS ShellView.swift。
 */
@Component
export struct ShellPage {
  private store: ChatStore = new ChatStore();
  @State private isSidebarVisible: boolean = true;
  @State private isSettingsPresented: boolean = false;
  @State private isDocumentsPresented: boolean = false;
  @State private isLoginPresented: boolean = false;
  @State private sidebarQuery: string = '';
  @State private destination: ShellDestination = 'chat';

  build() {
    Stack() {
      Row() {
        if (this.isSidebarVisible) {
          this.sidebar()
        }

        Column() {
          this.chatHeader()
          Divider().color(AgentClawDesign.divider)

          if (this.destination === 'chat') {
            ChatPanel({ store: this.store })
              .layoutWeight(1)
          } else {
            FancyIdeasPage({
              onUseIdea: (idea: FancyIdea) => {
                this.destination = 'chat';
                this.store.createSessionWithDraft(idea.prompt);
              }
            })
              .layoutWeight(1)
          }
        }
        .layoutWeight(1)
        .padding(4)
        .backgroundColor(AgentClawDesign.chatSurface)
        .borderRadius(10)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AgentClawDesign.appBackground)

      if (this.isSettingsPresented) {
        SettingsPanel({
          store: this.store,
          onClose: () => {
            this.isSettingsPresented = false;
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
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private sidebar() {
    Column({ space: 12 }) {
      this.searchField()

      Row({ space: 6 }) {
        Text(Icons.newChat).fontSize(13).fontColor(AgentClawDesign.primaryText)
        Text('新对话').fontSize(12).fontWeight(FontWeight.Bold).fontColor(AgentClawDesign.primaryText)
        Blank().layoutWeight(1)
      }
      .padding({ left: 14, right: 14 })
      .height(38)
      .backgroundColor('rgba(255,255,255,0.72)')
      .borderRadius(8)
      .onClick(() => {
        this.destination = 'chat';
        this.store.createSession();
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
          this.destination = 'ideas';
        })
        this.sidebarNavItem(Icons.folder, '文件', '文件与分享', () => {
          this.isDocumentsPresented = true;
        })
        this.sidebarNavItem(Icons.login, '登录', '登录解锁', () => {
          this.isLoginPresented = true;
        })
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
          .fontSize(12)
          .fontWeight(session.id === this.store.selectedSessionID ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(AgentClawDesign.primaryText)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.formattedTime(session.updatedAt))
          .fontSize(11)
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
      this.destination = 'chat';
      this.store.selectSession(session);
    })
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
        action: () => {
        }
      }
    });
  }

  @Builder
  private sidebarNavItem(icon: string, title: string, subtitle: string, action: () => void) {
    Row({ space: 10 }) {
      Text(icon).fontSize(14).fontColor(Color.Black).width(20)

      Column({ space: 2 }) {
        Text(title).fontSize(12).fontWeight(FontWeight.Medium).fontColor(AgentClawDesign.primaryText)
        Text(subtitle).fontSize(11).fontColor(AgentClawDesign.secondaryText)
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
    Row({ space: 8 }) {
      this.headerIconButton(Icons.sidebar, () => {
        this.isSidebarVisible = !this.isSidebarVisible;
      })

      this.headerIconButton(Icons.plusBubble, () => {
        this.destination = 'chat';
        this.store.createSession();
      })

      Blank().layoutWeight(1)

      Row() {
        Image($r('app.media.slide_setting')).width(20).height(20)
      }
      .width(34)
      .height(34)
      .borderRadius(8)
      .backgroundColor('rgba(255,255,255,0.5)')
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.isSettingsPresented = true;
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  @Builder
  private headerIconButton(icon: string, action: () => void) {
    Row() {
      Text(icon).fontSize(16).fontColor(Color.Black)
    }
    .width(34)
    .height(34)
    .borderRadius(8)
    .backgroundColor('rgba(255,255,255,0.5)')
    .justifyContent(FlexAlign.Center)
    .onClick(action)
  }

  private formattedTime(timestamp: number): string {
    const date = new Date(timestamp);
    const pad = (value: number): string => value < 10 ? `0${value}` : `${value}`;
    return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }
}
