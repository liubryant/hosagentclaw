/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { AgentClawDesign } from '../../common/Design';
import { bundleManager } from '@kit.AbilityKit';
import { AppPreferences } from '../../storage/AppPreferences';
import { LoginDialog } from '../account/LoginDialog';
import { AuthService } from '../../gateway/AuthService';

const AGREEMENT_URL = 'https://www.cjym123.cn/agreement_agentclaw.html';
const PRIVACY_URL = 'https://www.cjym123.cn/privacy_agentclaw.html';
const FEEDBACK_URL = 'https://www.cjym123.cn/feedback_agentclaw.html';
const CODE_COUNTDOWN_SECONDS = 120;

function isValidLoginCode(code: string): boolean {
  return /^\d{6}$/.test(code);
}

@Component
export struct ProfilePage {
  onOpenSettings: () => void = () => {};
  onOpenDocuments: () => void = () => {};
  onOpenWebView: (url: string, title: string) => void = () => {};
  onOpenVip: () => void = () => {};

  @State private isLoggedIn: boolean = false;
  @State private userPhone: string = '';
  @State private isLoginPresented: boolean = false;
  @State private isDeleteAccountPresented: boolean = false;
  @State private deleteCode: string = '';
  @State private deleteError: string | null = null;
  @State private isSendingDeleteCode: boolean = false;
  @State private isDeletingAccount: boolean = false;
  @State private deleteCodeButtonText: string = '获取验证码';
  @State private isDeleteCodeButtonEnabled: boolean = true;
  @State private currentVersionName: string = '--';
  private deleteCodeCountdownTimer: number = -1;

  aboutToAppear(): void {
    this.refreshLoginState();
    this.loadCurrentVersionName();
  }

  aboutToDisappear(): void {
    this.clearDeleteCodeCountdown();
  }

  private refreshLoginState(): void {
    this.isLoggedIn = AppPreferences.shared.isLoggedIn;
    this.userPhone = AppPreferences.shared.userPhone ?? '';
  }

  private loadCurrentVersionName(): void {
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT
      );
      if (bundleInfo.versionName.length > 0) {
        this.currentVersionName = bundleInfo.versionName;
      }
    } catch (_error) {
      this.currentVersionName = '--';
    }
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

          this.vipCard()

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
          Text(`版本 ${this.currentVersionName}`)
            .fontSize(11)
            .fontFamily('MiSans-Normal')
            .fontColor('#A0A0AA')
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 8 })

          Text('注销账号')
            .fontSize(12)
            .fontFamily('MiSans')
            .fontColor('#E5484D')
            .textAlign(TextAlign.Center)
            .width('100%')
            .height(36)
            .margin({ top: 4 })
            .onClick(() => {
              this.openDeleteAccountDialog();
            })
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

      if (this.isDeleteAccountPresented) {
        this.deleteAccountOverlay()
      }

    }
    .width('100%')
    .height('100%')
    .backgroundColor(AgentClawDesign.appBackground)
  }

  @Builder
  private vipCard() {
    Row({ space: 12 }) {
      Column() {
        Text('VIP')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A220D')
      }
      .width(46)
      .height(46)
      .borderRadius(23)
      .justifyContent(FlexAlign.Center)
      .linearGradient({
        angle: 135,
        colors: [['#FFF2BC', 0], ['#D9A64C', 1]] as [string, number][]
      })

      Column({ space: 4 }) {
        Text('AgentClaw 会员')
          .fontSize(16)
          .fontFamily('MiSans-DemiBold')
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFF1C2')
        Text('解锁 AI 图文、视频等高级能力')
          .fontSize(12)
          .fontFamily('MiSans-Normal')
          .fontColor('#CDAF7A')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('开通')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A220D')
        .textAlign(TextAlign.Center)
        .width(58)
        .height(32)
        .backgroundColor('#FEEBB9')
        .borderRadius(16)
    }
    .width('100%')
    .height(82)
    .padding({ left: 16, right: 14 })
    .borderRadius(20)
    .linearGradient({
      angle: 135,
      colors: [['#2A1710', 0], ['#5B3821', 0.65], ['#1B1010', 1]] as [string, number][]
    })
    .border({ width: 1, color: 'rgba(254,235,185,0.2)' })
    .onClick(() => {
      this.onOpenVip();
    })
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
          AppPreferences.shared.userAccessToken = null;
          this.refreshLoginState();
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    });
  }

  private openDeleteAccountDialog(): void {
    this.refreshLoginState();
    if (!this.isLoggedIn || this.userPhone.length === 0) {
      AlertDialog.show({
        title: '注销账号',
        message: '请先登录后再注销账号',
        confirm: {
          value: '去登录',
          action: () => {
            this.isLoginPresented = true;
          }
        }
      });
      return;
    }
    this.deleteCode = '';
    this.deleteError = null;
    this.isDeletingAccount = false;
    this.isSendingDeleteCode = false;
    this.clearDeleteCodeCountdown();
    this.deleteCodeButtonText = '获取验证码';
    this.isDeleteCodeButtonEnabled = true;
    this.isDeleteAccountPresented = true;
  }

  @Builder
  private deleteAccountOverlay() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.3)')
        .onClick(() => {
          this.closeDeleteAccountDialog();
        })

      Column({ space: 14 }) {
        Row() {
          Column({ space: 6 }) {
            Text('注销账号')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(AgentClawDesign.primaryText)
            Text(`验证手机号 ${this.maskedPhone(this.userPhone)} 后将永久注销账号`)
              .fontSize(13)
              .fontColor(AgentClawDesign.secondaryText)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('✕')
            .fontSize(15)
            .fontColor(Color.Black)
            .onClick(() => {
              this.closeDeleteAccountDialog();
            })
        }
        .width('100%')

        Text('注销账号前请确认：\n• 账号信息及相关数据将被永久删除，无法恢复。\n• 注销后该手机号可重新注册新账号。')
          .fontSize(13)
          .fontColor('#E5484D')
          .lineHeight(20)
          .width('100%')
          .padding(12)
          .backgroundColor('#FDECEC')
          .borderRadius(8)

        Row({ space: 6 }) {
          TextInput({ text: this.deleteCode, placeholder: '请输入验证码' })
            .type(InputType.Number)
            .maxLength(6)
            .fontSize(14)
            .layoutWeight(1)
            .height(46)
            .backgroundColor(AgentClawDesign.controlSurface)
            .borderRadius(8)
            .onChange((value: string) => {
              this.deleteCode = value;
            })

          Text(this.isSendingDeleteCode ? '发送中...' : this.deleteCodeButtonText)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isDeleteCodeButtonEnabled && !this.isSendingDeleteCode ? AgentClawDesign.accent : AgentClawDesign.secondaryText)
            .textAlign(TextAlign.Center)
            .width(104)
            .height(38)
            .backgroundColor(AgentClawDesign.controlSurface)
            .borderRadius(8)
            .onClick(() => {
              this.requestDeleteAccountCode();
            })
        }
        .width('100%')

        if (this.deleteError !== null) {
          Text(this.deleteError)
            .fontSize(12)
            .fontColor('#E5484D')
            .width('100%')
        }

        Text(this.isDeletingAccount ? '注销中...' : '注销账号')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(46)
          .backgroundColor('#E5484D')
          .borderRadius(8)
          .opacity(this.isDeletingAccount ? 0.55 : 1)
          .onClick(() => {
            this.confirmDeleteAccount();
          })
      }
      .alignItems(HorizontalAlign.Start)
      .width('86%')
      .constraintSize({ maxWidth: 460 })
      .padding({ left: 28, right: 28, top: 24, bottom: 24 })
      .backgroundColor(Color.White)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
  }

  private closeDeleteAccountDialog(): void {
    if (this.isDeletingAccount) {
      return;
    }
    this.isDeleteAccountPresented = false;
    this.deleteError = null;
    this.deleteCode = '';
    this.isSendingDeleteCode = false;
    this.clearDeleteCodeCountdown();
    this.deleteCodeButtonText = '获取验证码';
    this.isDeleteCodeButtonEnabled = true;
  }

  private requestDeleteAccountCode(): void {
    if (!this.isDeleteCodeButtonEnabled || this.isSendingDeleteCode || this.userPhone.length === 0) {
      return;
    }
    this.deleteError = null;
    this.isSendingDeleteCode = true;
    this.isDeleteCodeButtonEnabled = false;
    this.deleteCodeButtonText = '发送中...';
    AuthService.shared.sendSmsCode(this.userPhone)
      .then(() => {
        this.startDeleteCodeCountdown();
      })
      .catch((error: Error) => {
        this.isDeleteCodeButtonEnabled = true;
        this.deleteCodeButtonText = '获取验证码';
        this.deleteError = error.message;
      })
      .finally(() => {
        this.isSendingDeleteCode = false;
      });
  }

  private startDeleteCodeCountdown(): void {
    this.clearDeleteCodeCountdown();
    let remaining = CODE_COUNTDOWN_SECONDS;
    this.deleteCodeButtonText = `${remaining}s后重新获取`;
    this.isDeleteCodeButtonEnabled = false;
    this.deleteCodeCountdownTimer = setInterval(() => {
      remaining -= 1;
      if (remaining <= 0) {
        this.clearDeleteCodeCountdown();
        this.deleteCodeButtonText = '获取验证码';
        this.isDeleteCodeButtonEnabled = true;
        return;
      }
      this.deleteCodeButtonText = `${remaining}s后重新获取`;
    }, 1000) as number;
  }

  private clearDeleteCodeCountdown(): void {
    if (this.deleteCodeCountdownTimer >= 0) {
      clearInterval(this.deleteCodeCountdownTimer);
      this.deleteCodeCountdownTimer = -1;
    }
  }

  private confirmDeleteAccount(): void {
    if (this.isDeletingAccount) {
      return;
    }
    if (!isValidLoginCode(this.deleteCode)) {
      this.deleteError = '请输入验证码';
      return;
    }
    AlertDialog.show({
      title: '确认注销账号？',
      message: '注销后账号及数据将被永久删除，且无法恢复。',
      primaryButton: {
        value: '确认注销',
        fontColor: '#E5484D',
        action: () => {
          this.executeDeleteAccount();
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    });
  }

  private executeDeleteAccount(): void {
    this.deleteError = null;
    this.isDeletingAccount = true;
    AuthService.shared.deleteAccount(this.userPhone, this.deleteCode)
      .then(() => {
        AppPreferences.shared.isLoggedIn = false;
        AppPreferences.shared.userPhone = null;
        AppPreferences.shared.userAccessToken = null;
        this.refreshLoginState();
        this.clearDeleteCodeCountdown();
        this.isDeleteAccountPresented = false;
        AlertDialog.show({
          title: '注销账号',
          message: '账号已注销',
          confirm: {
            value: '确定',
            action: () => {}
          }
        });
      })
      .catch((error: Error) => {
        this.deleteError = error.message && error.message.length > 0 ? error.message : '注销失败，请稍后重试';
      })
      .finally(() => {
        this.isDeletingAccount = false;
      });
  }

  private openLink(url: string, title: string = ''): void {
    this.onOpenWebView(url, title);
  }
}
