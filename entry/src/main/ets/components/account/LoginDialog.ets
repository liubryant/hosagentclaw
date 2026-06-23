import { common } from '@kit.AbilityKit';
import { AgentClawDesign } from '../../common/Design';
import { Icons } from '../../common/Icons';
import { AppPreferences } from '../../storage/AppPreferences';
import { AuthService } from '../../gateway/AuthService';

const AGREEMENT_URL = 'https://www.cjym123.cn/agreement_agentclaw.html';
const PRIVACY_URL = 'https://www.cjym123.cn/privacy_agentclaw.html';
const CODE_COUNTDOWN_SECONDS = 120;

type LoginSection = 'login' | 'setPassword' | 'loggedIn';

function normalizeMainlandPhone(rawPhone: string): string {
  let result = '';
  for (const ch of rawPhone) {
    if (ch === ' ' || ch === '-' || ch === '\t' || ch === '\n') {
      continue;
    }
    result += ch;
  }
  if (result.startsWith('+86')) {
    result = result.substring(3);
  } else if (result.startsWith('86') && result.length > 11) {
    result = result.substring(2);
  }
  return result;
}

function isReliableMainlandPhone(phone: string): boolean {
  return /^1[3-9]\d{9}$/.test(phone);
}

function isValidLoginCode(code: string): boolean {
  return /^\d{6}$/.test(code);
}

/**
 * 对应安卓版 dialog_login.xml + ShellActivity.kt 里的登录/退出登录/设置密码/注销账号弹窗。
 * 鸿蒙版按用户要求做成可选入口（侧边栏点击才弹出），不会像安卓那样强制弹出阻塞使用。
 */
@Component
export struct LoginDialog {
  onClose: () => void = () => {
  };

  @State private section: LoginSection = 'login';
  @State private loggedInPhone: string = '';

  @State private isCodeMode: boolean = true;
  @State private phoneInput: string = '';
  @State private codeInput: string = '';
  @State private passwordInput: string = '';
  @State private isAgreementChecked: boolean = false;
  @State private loginError: string | null = null;
  @State private isLoggingIn: boolean = false;
  @State private codeButtonText: string = '获取验证码';
  @State private isCodeButtonEnabled: boolean = true;
  private codeCountdownTimer: number = -1;

  @State private setPasswordCode: string = '';
  @State private setPasswordNew: string = '';
  @State private setPasswordError: string | null = null;
  @State private isSettingPassword: boolean = false;
  @State private setPasswordCodeButtonText: string = '获取验证码';
  @State private isSetPasswordCodeButtonEnabled: boolean = true;
  private setPasswordCountdownTimer: number = -1;

  aboutToAppear(): void {
    if (AppPreferences.shared.isLoggedIn) {
      this.loggedInPhone = AppPreferences.shared.userPhone ?? '';
      this.section = 'loggedIn';
    } else {
      this.section = 'login';
    }
  }

  aboutToDisappear(): void {
    this.clearCodeCountdown();
    this.clearSetPasswordCountdown();
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.3)')
        .onClick(this.onClose)

      Column({ space: 0 }) {
        this.header()

        if (this.section === 'loggedIn') {
          this.loggedInSection()
        } else if (this.section === 'setPassword') {
          this.setPasswordSection()
        } else {
          this.loginFormSection()
        }
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

  @Builder
  private header() {
    Row() {
      Column({ space: 6 }) {
        Text('登录').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AgentClawDesign.primaryText)
        Text(this.subtitleText())
          .fontSize(13)
          .fontColor(AgentClawDesign.secondaryText)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(Icons.close)
        .fontSize(15)
        .fontColor(Color.Black)
        .onClick(this.onClose)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  private subtitleText(): string {
    if (this.section === 'setPassword') {
      return '验证手机号后可设置密码，之后可使用密码登录';
    }
    return '使用手机号和密码登录';
  }

  @Builder
  private loggedInSection() {
    Column({ space: 10 }) {
      Text(`已登录账号：${this.loggedInPhone}`)
        .fontSize(15)
        .fontColor(AgentClawDesign.primaryText)
        .width('100%')
        .margin({ top: 22 })

      Text('设置密码')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(46)
        .backgroundColor(AgentClawDesign.accent)
        .borderRadius(8)
        .onClick(() => {
          this.enterSetPasswordSection();
        })

      Text('退出登录')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#E5484D')
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(46)
        .backgroundColor('#FDECEC')
        .borderRadius(8)
        .onClick(() => {
          this.logout();
        })

      Text('注销账号')
        .fontSize(13)
        .fontColor(AgentClawDesign.secondaryText)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 4 })
        .onClick(() => {
          this.onClose();
          this.showDeleteAccountPrompt();
        })
    }
    .width('100%')
  }

  private enterSetPasswordSection(): void {
    this.setPasswordCode = '';
    this.setPasswordNew = '';
    this.setPasswordError = null;
    this.section = 'setPassword';
  }

  private logout(): void {
    AppPreferences.shared.isLoggedIn = false;
    AppPreferences.shared.userPhone = null;
    this.onClose();
  }

  private showDeleteAccountPrompt(): void {
    AlertDialog.show({
      title: '注销账号',
      message: '注销账号前请确认：\n• 账号信息及相关数据将被永久删除，无法恢复。\n• 注销后该手机号可重新注册新账号。\n\n请通过"忘记密码"流程获取验证码后再次点击侧边栏"登录"完成注销，或联系客服处理。',
      confirm: {
        value: '我知道了',
        action: () => {
        }
      }
    });
  }

  @Builder
  private setPasswordSection() {
    Column({ space: 12 }) {
      Text(`已登录账号：${this.loggedInPhone}`)
        .fontSize(14)
        .fontColor(AgentClawDesign.primaryText)
        .width('100%')

      Row({ space: 6 }) {
        TextInput({ text: this.setPasswordCode, placeholder: '请输入验证码' })
          .type(InputType.Number)
          .maxLength(6)
          .fontSize(14)
          .layoutWeight(1)
          .height(46)
          .backgroundColor(AgentClawDesign.controlSurface)
          .borderRadius(8)
          .onChange((value: string) => {
            this.setPasswordCode = value;
          })

        Text(this.setPasswordCodeButtonText)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isSetPasswordCodeButtonEnabled ? AgentClawDesign.accent : AgentClawDesign.secondaryText)
          .textAlign(TextAlign.Center)
          .width(96)
          .height(38)
          .backgroundColor(AgentClawDesign.controlSurface)
          .borderRadius(8)
          .onClick(() => {
            this.requestSetPasswordCode();
          })
      }
      .width('100%')

      TextInput({ text: this.setPasswordNew, placeholder: '请输入新密码（至少6位）' })
        .type(InputType.Password)
        .fontSize(14)
        .width('100%')
        .height(46)
        .backgroundColor(AgentClawDesign.controlSurface)
        .borderRadius(8)
        .onChange((value: string) => {
          this.setPasswordNew = value;
        })

      if (this.setPasswordError !== null) {
        Text(this.setPasswordError).fontSize(12).fontColor('#E5484D').width('100%')
      }

      Text(this.isSettingPassword ? '设置中…' : '确认设置')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(46)
        .backgroundColor(AgentClawDesign.accent)
        .borderRadius(8)
        .opacity(this.isSettingPassword ? 0.6 : 1)
        .onClick(() => {
          this.submitSetPassword();
        })

      Text('返回')
        .fontSize(13)
        .fontColor(AgentClawDesign.secondaryText)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 4 })
        .onClick(() => {
          this.clearSetPasswordCountdown();
          this.section = 'loggedIn';
        })
    }
    .width('100%')
    .margin({ top: 22 })
  }

  private requestSetPasswordCode(): void {
    if (!this.isSetPasswordCodeButtonEnabled || this.loggedInPhone.length === 0) {
      return;
    }
    this.isSetPasswordCodeButtonEnabled = false;
    this.setPasswordCodeButtonText = '发送中…';
    AuthService.shared.sendSmsCode(this.loggedInPhone)
      .then(() => {
        this.startSetPasswordCountdown();
      })
      .catch((error: Error) => {
        this.isSetPasswordCodeButtonEnabled = true;
        this.setPasswordCodeButtonText = '获取验证码';
        this.setPasswordError = error.message;
      });
  }

  private startSetPasswordCountdown(): void {
    let remaining = CODE_COUNTDOWN_SECONDS;
    this.setPasswordCodeButtonText = `${remaining}s后重新获取`;
    this.setPasswordCountdownTimer = setInterval(() => {
      remaining -= 1;
      if (remaining <= 0) {
        this.clearSetPasswordCountdown();
        this.isSetPasswordCodeButtonEnabled = true;
        this.setPasswordCodeButtonText = '获取验证码';
        return;
      }
      this.setPasswordCodeButtonText = `${remaining}s后重新获取`;
    }, 1000);
  }

  private clearSetPasswordCountdown(): void {
    if (this.setPasswordCountdownTimer >= 0) {
      clearInterval(this.setPasswordCountdownTimer);
      this.setPasswordCountdownTimer = -1;
    }
  }

  private submitSetPassword(): void {
    if (this.isSettingPassword) {
      return;
    }
    if (!isValidLoginCode(this.setPasswordCode)) {
      this.setPasswordError = '请输入验证码';
      return;
    }
    if (this.setPasswordNew.length < 6) {
      this.setPasswordError = '请输入新密码（至少6位）';
      return;
    }
    this.isSettingPassword = true;
    this.setPasswordError = null;
    AuthService.shared.setPassword(this.loggedInPhone, this.setPasswordCode, this.setPasswordNew)
      .then(() => {
        this.isSettingPassword = false;
        this.clearSetPasswordCountdown();
        this.section = 'loggedIn';
        AlertDialog.show({
          title: '设置密码',
          message: '密码设置成功',
          confirm: { value: '确定', action: () => {
          } }
        });
      })
      .catch((error: Error) => {
        this.isSettingPassword = false;
        this.setPasswordError = error.message;
      });
  }

  @Builder
  private loginFormSection() {
    Column({ space: 12 }) {
      TextInput({ text: this.phoneInput, placeholder: '请输入手机号' })
        .type(InputType.PhoneNumber)
        .maxLength(11)
        .fontSize(14)
        .width('100%')
        .height(46)
        .backgroundColor(AgentClawDesign.controlSurface)
        .borderRadius(8)
        .onChange((value: string) => {
          this.phoneInput = value;
        })

      if (this.isCodeMode) {
        Row({ space: 6 }) {
          TextInput({ text: this.codeInput, placeholder: '请输入验证码' })
            .type(InputType.Number)
            .maxLength(6)
            .fontSize(14)
            .layoutWeight(1)
            .height(46)
            .backgroundColor(AgentClawDesign.controlSurface)
            .borderRadius(8)
            .onChange((value: string) => {
              this.codeInput = value;
            })

          Text(this.codeButtonText)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isCodeButtonEnabled ? AgentClawDesign.accent : AgentClawDesign.secondaryText)
            .textAlign(TextAlign.Center)
            .width(96)
            .height(38)
            .backgroundColor(AgentClawDesign.controlSurface)
            .borderRadius(8)
            .onClick(() => {
              this.requestLoginCode();
            })
        }
        .width('100%')
      } else {
        TextInput({ text: this.passwordInput, placeholder: '请输入密码' })
          .type(InputType.Password)
          .fontSize(14)
          .width('100%')
          .height(46)
          .backgroundColor(AgentClawDesign.controlSurface)
          .borderRadius(8)
          .onChange((value: string) => {
            this.passwordInput = value;
          })
      }

      if (this.loginError !== null) {
        Text(this.loginError).fontSize(12).fontColor('#E5484D').width('100%')
      }

      Text(this.isLoggingIn ? '登录中…' : '登录')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(46)
        .backgroundColor(AgentClawDesign.accent)
        .borderRadius(8)
        .opacity(this.isAgreementChecked ? 1 : 0.4)
        .onClick(() => {
          this.submitLogin();
        })

      Text(this.isCodeMode ? '使用密码登录' : '使用验证码登录')
        .fontSize(13)
        .fontColor(AgentClawDesign.secondaryText)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 4 })
        .onClick(() => {
          this.isCodeMode = !this.isCodeMode;
          this.loginError = null;
        })

      Row({ space: 6 }) {
        Text(this.isAgreementChecked ? '✓' : '')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .width(16)
          .height(16)
          .backgroundColor(this.isAgreementChecked ? AgentClawDesign.accent : AgentClawDesign.controlSurface)
          .border({ width: 1, color: this.isAgreementChecked ? AgentClawDesign.accent : AgentClawDesign.divider })
          .borderRadius(3)

        Text() {
          Span('我已阅读并同意')
          Span('《用户协议》')
            .fontColor(AgentClawDesign.accent)
            .onClick(() => {
              this.openLink(AGREEMENT_URL);
            })
          Span('和')
          Span('《隐私政策》')
            .fontColor(AgentClawDesign.accent)
            .onClick(() => {
              this.openLink(PRIVACY_URL);
            })
        }
        .fontSize(12)
        .fontColor(AgentClawDesign.secondaryText)
      }
      .width('100%')
      .margin({ top: 6 })
      .onClick(() => {
        this.isAgreementChecked = !this.isAgreementChecked;
      })
    }
    .width('100%')
    .margin({ top: 22 })
  }

  private openLink(url: string): void {
    const context = getContext(this) as common.UIAbilityContext;
    context.openLink(url).catch(() => {
    });
  }

  private requestLoginCode(): void {
    if (!this.isCodeButtonEnabled) {
      return;
    }
    const phone = normalizeMainlandPhone(this.phoneInput);
    if (!isReliableMainlandPhone(phone)) {
      this.loginError = '请输入可靠的手机号';
      return;
    }
    this.loginError = null;
    this.isCodeButtonEnabled = false;
    this.codeButtonText = '发送中…';
    AuthService.shared.sendSmsCode(phone)
      .then(() => {
        this.startCodeCountdown();
      })
      .catch((error: Error) => {
        this.isCodeButtonEnabled = true;
        this.codeButtonText = '获取验证码';
        this.loginError = error.message;
      });
  }

  private startCodeCountdown(): void {
    let remaining = CODE_COUNTDOWN_SECONDS;
    this.codeButtonText = `${remaining}s后重新获取`;
    this.codeCountdownTimer = setInterval(() => {
      remaining -= 1;
      if (remaining <= 0) {
        this.clearCodeCountdown();
        this.isCodeButtonEnabled = true;
        this.codeButtonText = '获取验证码';
        return;
      }
      this.codeButtonText = `${remaining}s后重新获取`;
    }, 1000);
  }

  private clearCodeCountdown(): void {
    if (this.codeCountdownTimer >= 0) {
      clearInterval(this.codeCountdownTimer);
      this.codeCountdownTimer = -1;
    }
  }

  private submitLogin(): void {
    if (this.isLoggingIn) {
      return;
    }
    if (!this.isAgreementChecked) {
      AlertDialog.show({
        title: '提示',
        message: '请先阅读并勾选同意《用户协议》和《隐私政策》',
        confirm: { value: '知道了', action: () => {
        } }
      });
      return;
    }
    const phone = normalizeMainlandPhone(this.phoneInput);
    if (!isReliableMainlandPhone(phone)) {
      this.loginError = '请输入可靠的手机号';
      return;
    }

    if (this.isCodeMode && !isValidLoginCode(this.codeInput)) {
      this.loginError = '请输入验证码';
      return;
    }
    if (!this.isCodeMode && this.passwordInput.length < 6) {
      this.loginError = '密码不能为空';
      return;
    }

    this.isLoggingIn = true;
    this.loginError = null;
    const loginPromise = this.isCodeMode
      ? AuthService.shared.loginByCode(phone, this.codeInput)
      : AuthService.shared.loginByPassword(phone, this.passwordInput);

    loginPromise
      .then((result) => {
        AppPreferences.shared.isLoggedIn = true;
        AppPreferences.shared.userPhone = result.phone;
        this.isLoggingIn = false;
        this.onClose();
      })
      .catch((error: Error) => {
        this.isLoggingIn = false;
        this.loginError = error.message;
      });
  }
}
