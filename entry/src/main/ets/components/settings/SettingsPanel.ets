import { common } from '@kit.AbilityKit';
import { AgentClawDesign } from '../../common/Design';
import { AppEnvironment, EnvironmentManager, environmentDisplayName } from '../../common/AppConfig';
import { AppPreferences } from '../../storage/AppPreferences';
import { GatewayClient } from '../../gateway/GatewayClient';
import { ChatStore } from '../../store/ChatStore';

type SettingsPage = 'skills' | 'about';

interface SkillItem {
  name: string;
  detail: string;
  enabled: boolean;
}

const SKILLS: SkillItem[] = [
  { name: 'PDF', detail: 'PDF 表单识别、图片转换、字段提取', enabled: true },
  { name: 'PPTX', detail: '演示文稿生成、页面编辑、缩略图', enabled: true },
  { name: 'HTML Default', detail: 'Markdown 到 HTML 的基础转换', enabled: true },
  { name: 'Multi Search Engine', detail: '多搜索源查询与整理', enabled: false }
];

const AGREEMENT_URL = 'https://www.cjym123.cn/agreement_agentclaw.html';
const PRIVACY_URL = 'https://www.cjym123.cn/privacy_agentclaw.html';
const ICP_URL = 'https://beian.miit.gov.cn/';

/**
 * 对应 iOS SettingsPanelView.swift（技能管理 / 关于我们 两个页签）。
 */
@Component
export struct SettingsPanel {
  store: ChatStore = new ChatStore();
  onClose: () => void = () => {
  };
  @State private selectedPage: SettingsPage = 'skills';
  @State private showEnvironmentOption: boolean = false;
  @State private currentEnvironment: AppEnvironment = AppEnvironment.PRODUCTION;
  @State private isWideLayout: boolean = false;
  private tapCount: number = 0;
  private lastTapTime: number = Date.now();

  aboutToAppear(): void {
    this.currentEnvironment = EnvironmentManager.shared.currentEnvironment;
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.18)')
        .onClick(this.onClose)

      Column() {
        if (this.isWideLayout) {
          this.wideLayout()
        } else {
          this.compactLayout()
        }
      }
      .padding(10)
      .width('92%')
      .constraintSize({ maxWidth: 600, maxHeight: '78%' })
      .height('70%')
      .backgroundColor('#F5F7FA')
      .borderRadius(14)
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.isWideLayout = Number(newValue.width) >= 560;
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private wideLayout() {
    Row({ space: 10 }) {
      this.menu()

      Column() {
        this.content()
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private compactLayout() {
    Column({ space: 8 }) {
      this.compactHeader()

      Row({ space: 6 }) {
        this.compactMenuButton('skills', $r('app.media.list_skill'), '技能')
        this.compactMenuButton('about', $r('app.media.list_about'), '关于')
      }
      .width('100%')

      Column() {
        this.content()
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private compactHeader() {
    Row() {
      Row({ space: 6 }) {
        Image($r('app.media.slide_setting')).width(18).height(18)
        Text('设置').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#212121')
      }
      Blank().layoutWeight(1)
      Text('✕').fontSize(12).fontWeight(FontWeight.Bold).onClick(this.onClose)
    }
    .width('100%')
  }

  @Builder
  private compactMenuButton(page: SettingsPage, icon: ResourceStr, title: string) {
    Row({ space: 6 }) {
      Image(icon).width(16).height(16)
      Text(title)
        .fontSize(12)
        .fontWeight(this.selectedPage === page ? FontWeight.Bold : FontWeight.Normal)
        .fontColor('#212121')
    }
    .layoutWeight(1)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.selectedPage === page ? 'rgba(255,255,255,0.72)' : Color.Transparent)
    .borderRadius(8)
    .onClick(() => {
      this.selectedPage = page;
    })
  }

  @Builder
  private menu() {
    Column() {
      Row() {
        Row({ space: 8 }) {
          Image($r('app.media.slide_setting')).width(22).height(22)
          Text('设置').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#212121')
        }
        Blank().layoutWeight(1)
        Text('✕').fontSize(13).fontWeight(FontWeight.Bold).onClick(this.onClose)
      }
      .width('100%')
      .margin({ bottom: 40 })

      this.menuButton('skills', $r('app.media.list_skill'), '技能管理')
      this.menuButton('about', $r('app.media.list_about'), '关于我们')

      Blank().layoutWeight(1)
    }
    .alignItems(HorizontalAlign.Start)
    .width(180)
    .height('100%')
    .padding(14)
    .backgroundColor('#F5F7FA')
  }

  @Builder
  private menuButton(page: SettingsPage, icon: ResourceStr, title: string) {
    Row({ space: 10 }) {
      Image(icon).width(20).height(20)
      Text(title)
        .fontSize(12)
        .fontWeight(this.selectedPage === page ? FontWeight.Bold : FontWeight.Normal)
        .fontColor('#212121')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank().layoutWeight(1)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.selectedPage === page ? 'rgba(255,255,255,0.72)' : Color.Transparent)
    .borderRadius(8)
    .onClick(() => {
      this.selectedPage = page;
    })
  }

  @Builder
  private content() {
    Column() {
      if (this.selectedPage === 'skills') {
        this.skillsPage()
      } else {
        this.aboutPage()
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#FAFBFC')
    .borderRadius(12)
  }

  @Builder
  private skillsPage() {
    Column({ space: 14 }) {
      Column({ space: 5 }) {
        Text('技能管理').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#212121')
        Text('扩展智能体的能力：一键集成精选技能与工具')
          .fontSize(12)
          .fontColor(AgentClawDesign.secondaryText)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Scroll() {
        Column({ space: 10 }) {
          ForEach(this.skillRows(), (row: SkillItem[]) => {
            Row({ space: 10 }) {
              ForEach(row, (skill: SkillItem) => {
                this.skillCard(skill)
              }, (skill: SkillItem) => skill.name)

              if (row.length === 1) {
                Blank().layoutWeight(1)
              }
            }
            .width('100%')
          })
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .height('100%')
  }

  private skillRows(): SkillItem[][] {
    const rows: SkillItem[][] = [];
    for (let index = 0; index < SKILLS.length; index += 2) {
      rows.push(SKILLS.slice(index, Math.min(index + 2, SKILLS.length)));
    }
    return rows;
  }

  @Builder
  private skillCard(skill: SkillItem) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Image($r('app.media.icon_skill')).width(23).height(30)
        Text(skill.name)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F1F1F')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Image($r('app.media.icon_remove')).width(16).height(16)
      }
      .width('100%')

      Text(skill.detail)
        .fontSize(12)
        .fontColor('#666666')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({ left: 33 })

      Divider().color('#EEEEEE')

      Row() {
        Text('内置技能')
          .fontSize(12)
          .fontColor(Color.Black)
          .padding({ left: 8, right: 8 })
          .height(24)
          .backgroundColor('#F2F5FA')
          .borderRadius(6)
        Blank().layoutWeight(1)
        Image(skill.enabled ? $r('app.media.switch_on') : $r('app.media.switch_off')).width(24).height(14)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .constraintSize({ minHeight: 130 })
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  private aboutPage() {
    Column() {
      Scroll() {
        Column({ space: 8 }) {
          Image($r('app.media.app_icon_display'))
            .width(59)
            .height(59)
            .margin({ top: 8 })
            .onClick(() => {
              this.handleLogoTap();
            })

          this.versionInfoRow('当前版本', this.appVersion())

          if (this.showEnvironmentOption) {
            this.environmentSwitchRow()
          }

          this.aboutLinkRow('用户协议', AGREEMENT_URL)
          this.aboutLinkRow('隐私政策', PRIVACY_URL)
          this.clearDataButton()
        }
        .width('100%')
      }
      .layoutWeight(1)

      this.icpRow()
    }
    .width('100%')
    .height('100%')
  }

  private appVersion(): string {
    return 'V1.0.0';
  }

  @Builder
  private versionInfoRow(title: string, detail: string) {
    Row({ space: 6 }) {
      Text(title).fontSize(12).fontColor('#212121')
      Text(detail).fontSize(12).fontColor('#212121')
      Blank().layoutWeight(1)
    }
    .width('100%')
    .height(42)
    .padding({ left: 14, right: 14 })
    .backgroundColor(Color.White)
    .borderRadius(8)
  }

  @Builder
  private aboutLinkRow(title: string, url: string) {
    Row() {
      Text(title).fontSize(12).fontColor('#212121')
      Blank().layoutWeight(1)
      Text('〉').fontSize(13).fontColor(AgentClawDesign.secondaryText)
    }
    .width('100%')
    .height(42)
    .padding({ left: 14, right: 14 })
    .backgroundColor(Color.White)
    .borderRadius(8)
    .margin({ top: 8 })
    .onClick(() => {
      const context = getContext(this) as common.UIAbilityContext;
      context.openLink(url).catch(() => {
      });
    })
  }

  @Builder
  private environmentSwitchRow() {
    Row() {
      Text('运行环境').fontSize(12).fontColor('#212121')
      Blank().layoutWeight(1)
      Text(environmentDisplayName(this.currentEnvironment)).fontSize(12).fontColor('#666666')
      Text('〉').fontSize(13).fontColor(AgentClawDesign.secondaryText).margin({ left: 4 })
    }
    .width('100%')
    .height(42)
    .padding({ left: 14, right: 14 })
    .backgroundColor(Color.White)
    .borderRadius(8)
    .margin({ top: 8 })
    .onClick(() => {
      AlertDialog.show({
        title: '选择运行环境',
        message: '切换环境后将使用对应的服务器地址',
        primaryButton: {
          value: '生产环境',
          action: () => {
            this.switchEnvironment(AppEnvironment.PRODUCTION);
          }
        },
        secondaryButton: {
          value: '测试环境',
          action: () => {
            this.switchEnvironment(AppEnvironment.TESTING);
          }
        }
      });
    })
  }

  @Builder
  private clearDataButton() {
    Row() {
      Text('清除所有数据').fontSize(12).fontColor('#212121')
      Blank().layoutWeight(1)
      Text('〉').fontSize(13).fontColor(AgentClawDesign.secondaryText)
    }
    .width('100%')
    .height(42)
    .padding({ left: 14, right: 14 })
    .backgroundColor(Color.White)
    .borderRadius(8)
    .margin({ top: 8 })
    .onClick(() => {
      AlertDialog.show({
        title: '清除所有数据',
        message: '此操作将清除所有聊天记录、网关配置等数据，且无法恢复。确定要继续吗？',
        primaryButton: {
          value: '清除',
          fontColor: '#D0021B',
          action: () => {
            this.clearAllData();
          }
        },
        secondaryButton: {
          value: '取消',
          action: () => {
          }
        }
      });
    })
  }

  @Builder
  private icpRow() {
    Row({ space: 4 }) {
      Text('ICP备案号：').fontSize(12).fontColor('#808080')
      Text('粤ICP备2024188934号-3A')
        .fontSize(12)
        .fontColor('#808080')
        .decoration({ type: TextDecorationType.Underline })
        .onClick(() => {
          const context = getContext(this) as common.UIAbilityContext;
          context.openLink(ICP_URL).catch(() => {
          });
        })
    }
    .width('100%')
    .margin({ top: 30, bottom: 16 })
    .justifyContent(FlexAlign.Center)
  }

  private handleLogoTap(): void {
    const now = Date.now();
    const elapsed = now - this.lastTapTime;
    this.tapCount = elapsed > 500 ? 1 : this.tapCount + 1;
    this.lastTapTime = now;

    if (this.tapCount >= 6) {
      this.showEnvironmentOption = !this.showEnvironmentOption;
      this.tapCount = 0;
    }
  }

  private switchEnvironment(env: AppEnvironment): void {
    this.currentEnvironment = env;
    EnvironmentManager.shared.switchEnvironment(env);
    GatewayClient.shared.refreshFromEnvironment();
  }

  private clearAllData(): void {
    this.store.clearAllData();
    AppPreferences.shared.gatewayToken = null;
    GatewayClient.shared.refreshFromEnvironment();
  }
}
