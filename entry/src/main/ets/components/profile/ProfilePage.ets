/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { AgentClawDesign } from '../../common/Design';
import { AppPreferences } from '../../storage/AppPreferences';
import { LoginDialog } from '../account/LoginDialog';

const AGREEMENT_URL = 'https://www.cjym123.cn/agreement_agentclaw.html';
const PRIVACY_URL = 'https://www.cjym123.cn/privacy_agentclaw.html';
const FEEDBACK_URL = 'https://www.cjym123.cn/feedback_agentclaw.html';
const APP_VERSION = '1.0.0';

@Component
export struct ProfilePage {
  onOpenSettings: () => void = () => {};
  onOpenDocuments: () => void = () => {};
  onOpenWebView: (url: string, title: string) => void = () => {};

  @State private isLoggedIn: boolean = false;
  @State private userPhone: string = '';
  @State private isLoginPresented: boolean = false;

  aboutToAppear(): void {
    this.refreshLoginState();
  }

  private refreshLoginState(): void {
    this.isLoggedIn = AppPreferences.shared.isLoggedIn;
    this.userPhone = AppPreferences.shared.userPhone ?? '';
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 14 }) {
          // Large title
          Text('我的')
            .fontSize(27)
            .fontWeight(FontWeight.Bold)
            .fontFamily('MiSans-DemiBold')
            .fontColor('#15151A')
            .alignSelf(ItemAlign.Start)
            .margin({ top: 16 })

          // Login card
          this.loginCard()

          // 功能 section
          Text('功能')
            .fontSize(17)
            .fontFamily('MiSans-DemiBold')
            .fontWeight(FontWeight.Bold)
            .fontColor('#202027')
            .alignSelf(ItemAlign.Start)

          // Services card
          Column({ space: 0 }) {
            this.rowItem('📄', '我的作品', () => {
              this.onOpenDocuments();
            })
            Divider()
              .color(AgentClawDesign.divider)
              .margin({ left: 54 })
            this.rowItem('⚙', '设置', () => {
              this.onOpenSettings();
            })
          }
          .width('100%')
          .backgroundColor('#F8F8FA')
          .borderRadius(20)
          .border({ width: 1, color: 'rgba(0,0,0,0.05)' })
          .clip(true)

          // 关于 section
          Text('关于')
            .fontSize(17)
            .fontFamily('MiSans-DemiBold')
            .fontWeight(FontWeight.Bold)
            .fontColor('#202027')
            .alignSelf(ItemAlign.Start)

          // About card
          Column({ space: 0 }) {
            this.rowItem('📋', '用户协议', () => {
              this.openLink(AGREEMENT_URL, '用户协议');
            })
            Divider().color(AgentClawDesign.divider).margin({ left: 54 })
            this.rowItem('🔒', '隐私政策', () => {
              this.openLink(PRIVACY_URL, '隐私政策');
            })
            Divider().color(AgentClawDesign.divider).margin({ left: 54 })
            this.rowItem('💬', '客服反馈', () => {
              this.openLink(FEEDBACK_URL, '客服反馈');
            })
          }
          .width('100%')
          .backgroundColor('#F8F8FA')
          .borderRadius(20)
          .border({ width: 1, color: 'rgba(0,0,0,0.05)' })
          .clip(true)

          // Logout card (only if logged in)
          if (this.isLoggedIn) {
            Column({ space: 0 }) {
              this.rowItem('🚪', '退出登录', () => {
                this.confirmLogout();
              })
            }
            .width('100%')
            .backgroundColor('#F8F8FA')
            .borderRadius(20)
            .border({ width: 1, color: 'rgba(0,0,0,0.05)' })
            .clip(true)
          }

          // Version text
          Text(`版本 ${APP_VERSION}`)
            .fontSize(11)
            .fontFamily('MiSans-Normal')
            .fontColor('#A0A0AA')
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 8 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 28 })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)

      // Login dialog overlay
      if (this.isLoginPresented) {
        LoginDialog({
          onClose: () => {
            this.isLoginPresented = false;
            this.refreshLoginState();
          }
        })
      }

    }
    .width('100%')
    .height('100%')
    .backgroundColor(AgentClawDesign.appBackground)
  }

  @Builder
  private loginCard() {
    Row({ space: 14 }) {
      // Avatar circle with purple gradient
      Column() {
        Text('👤')
          .fontSize(28)
          .fontColor(Color.White)
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .justifyContent(FlexAlign.Center)
      .linearGradient({
        angle: 135,
        colors: [['#D8B4FE', 0], ['#C4B5FD', 1]]
      })

      // Name column
      Column({ space: 4 }) {
        if (this.isLoggedIn && this.userPhone.length > 0) {
          Text(this.maskedPhone(this.userPhone))
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontFamily('MiSans-DemiBold')
            .fontColor(AgentClawDesign.primaryText)
          Text('已登录')
            .fontSize(12)
            .fontFamily('MiSans-Normal')
            .fontColor(AgentClawDesign.secondaryText)
        } else {
          Text('点击登录')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontFamily('MiSans-DemiBold')
            .fontColor(AgentClawDesign.primaryText)
          Text('登录后解锁更多功能')
            .fontSize(12)
            .fontFamily('MiSans-Normal')
            .fontColor(AgentClawDesign.secondaryText)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // Login button
      Text(this.isLoggedIn ? '已登录' : '登录')
        .fontSize(13)
        .fontFamily('MiSans')
        .fontColor(Color.White)
        .padding({ left: 14, right: 14 })
        .height(38)
        .borderRadius(19)
        .linearGradient({
          angle: 135,
          colors: [['#D8B4FE', 0], ['#A78BFA', 1]]
        })
    }
    .width('100%')
    .height(116)
    .padding(16)
    .borderRadius(24)
    .backgroundColor('#F6F2FF')
    .border({ width: 1, color: 'rgba(116,80,245,0.15)' })
    .onClick(() => {
      this.isLoginPresented = true;
    })
  }

  @Builder
  private rowItem(icon: string, title: string, action: () => void) {
    Row({ space: 12 }) {
      Text(icon)
        .fontSize(18)
        .width(30)
        .textAlign(TextAlign.Center)

      Text(title)
        .fontSize(14)
        .fontFamily('MiSans')
        .fontColor(AgentClawDesign.primaryText)
        .layoutWeight(1)

      Text('›')
        .fontSize(18)
        .fontColor(AgentClawDesign.secondaryText)
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.Transparent)
    .onClick(action)
  }

  private maskedPhone(phone: string): string {
    if (phone.length !== 11) {
      return phone;
    }
    return `${phone.substring(0, 3)}****${phone.substring(7)}`;
  }

  private confirmLogout(): void {
    AlertDialog.show({
      title: '退出登录',
      message: '确定要退出登录吗？',
      primaryButton: {
        value: '退出',
        fontColor: '#E5484D',
        action: () => {
          AppPreferences.shared.isLoggedIn = false;
          AppPreferences.shared.userPhone = null;
          this.refreshLoginState();
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    });
  }

  private openLink(url: string, title: string = ''): void {
    this.onOpenWebView(url, title);
  }
}
