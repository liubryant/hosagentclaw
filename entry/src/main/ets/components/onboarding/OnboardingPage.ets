import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { AgentClawDesign } from '../../common/Design';

const AGREEMENT_URL = 'https://www.cjym123.cn/agreement_agentclaw.html';
const PRIVACY_URL = 'https://www.cjym123.cn/privacy_agentclaw.html';

/**
 * 对应 Android TermsDialog：个人信息保护提示，含复选框，协议链接用内置 WebView 打开。
 */
@Component
export struct OnboardingPage {
  onContinue: () => void = () => {};
  @State private showGoodbye: boolean = false;
  @State private isConsentChecked: boolean = false;
  @State private webViewUrl: string = '';
  @State private webViewTitle: string = '';
  @State private webviewController: webview.WebviewController = new webview.WebviewController();

  build() {
    Stack() {
      // Dim background
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.3)')

      // Dialog card
      Column({ space: 16 }) {
        // Icon + title
        Column({ space: 10 }) {
          Image($r('app.media.app_icon_display'))
            .width(72)
            .height(72)
            .borderRadius(16)

          Text('个人信息保护提示')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontFamily('MiSans-DemiBold')
            .fontColor(Color.Black)
        }

        // Scrollable content
        Scroll() {
          Column({ space: 12 }) {
            Text('亲爱的用户，欢迎使用Agent智能体生活助手！为了更好地保障您的权益，为您提供安全、便捷的服务，请您阅读并同意以下相关协议。')
              .fontSize(12)
              .fontFamily('MiSans')
              .fontColor(AgentClawDesign.secondaryText)
              .lineHeight(19)
              .width('100%')

            Flex({ wrap: FlexWrap.Wrap }) {
              Text('为正常提供服务，我们将通过')
                .fontSize(12)
                .fontFamily('MiSans')
                .fontColor(AgentClawDesign.secondaryText)
              Text('《用户协议》')
                .fontSize(12)
                .fontFamily('MiSans')
                .fontColor(AgentClawDesign.accent)
                .onClick(() => {
                  this.webViewUrl = AGREEMENT_URL;
                  this.webViewTitle = '用户协议';
                })
              Text('和')
                .fontSize(12)
                .fontFamily('MiSans')
                .fontColor(AgentClawDesign.secondaryText)
              Text('《隐私政策》')
                .fontSize(12)
                .fontFamily('MiSans')
                .fontColor(AgentClawDesign.accent)
                .onClick(() => {
                  this.webViewUrl = PRIVACY_URL;
                  this.webViewTitle = '隐私政策';
                })
              Text('帮助您了解我们提供的服务及权利。')
                .fontSize(12)
                .fontFamily('MiSans')
                .fontColor(AgentClawDesign.secondaryText)
            }
            .width('100%')

            Column({ space: 6 }) {
              Text('1.   为了保障软件安全运行和账户安全，我们会申请收集您的设备信息、IP地址、MAC地址。').fontSize(12).fontFamily('MiSans').fontColor(AgentClawDesign.secondaryText).lineHeight(18)
              Text('2.   保存图片、视频，需要使用您的存储、相机、麦克风权限。').fontSize(12).fontFamily('MiSans').fontColor(AgentClawDesign.secondaryText).lineHeight(18)
              Text('3.   我们可能会申请位置权限，用于为您推荐感兴趣的内容。').fontSize(12).fontFamily('MiSans').fontColor(AgentClawDesign.secondaryText).lineHeight(18)
              Text('4.   我们尊重您的选择权，您可以管理或删除您的个人数据，并通过反馈渠道联系我们。').fontSize(12).fontFamily('MiSans').fontColor(AgentClawDesign.secondaryText).lineHeight(18)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .padding(16)
        }
        .align(Alignment.TopStart)
        .constraintSize({ maxHeight: 220 })
        .backgroundColor('rgba(0,0,0,0.03)')
        .borderRadius(12)

        // Consent checkbox row (matches Android: "我已阅读并同意上述全部协议")
        Row({ space: 10 }) {
          Column() {
            if (this.isConsentChecked) {
              Text('✓')
                .fontSize(12)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Bold)
            }
          }
          .width(18)
          .height(18)
          .borderRadius(4)
          .justifyContent(FlexAlign.Center)
          .border({ width: 1.5, color: this.isConsentChecked ? AgentClawDesign.accent : '#CCCCCC' })
          .backgroundColor(this.isConsentChecked ? AgentClawDesign.accent : Color.Transparent)

          Text('我已阅读并同意上述全部协议')
            .fontSize(12)
            .fontFamily('MiSans')
            .fontColor('#555555')
            .layoutWeight(1)
        }
        .width('100%')
        .onClick(() => {
          this.isConsentChecked = !this.isConsentChecked;
        })

        // Buttons
        Row({ space: 12 }) {
          Text('不同意')
            .fontSize(14)
            .fontFamily('MiSans')
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(44)
            .backgroundColor('rgba(0,0,0,0.06)')
            .borderRadius(10)
            .onClick(() => {
              this.showDisagreeAlert();
            })

          Text('同意')
            .fontSize(14)
            .fontFamily('MiSans-DemiBold')
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(44)
            .backgroundColor(this.isConsentChecked ? AgentClawDesign.accent : 'rgba(57,120,243,0.38)')
            .borderRadius(10)
            .onClick(() => {
              if (this.isConsentChecked) {
                this.onContinue();
              }
            })
        }
      }
      .padding(24)
      .constraintSize({ maxWidth: 480 })
      .width('90%')
      .backgroundColor(Color.White)
      .borderRadius(16)
      .shadow({ radius: 20, color: 'rgba(0,0,0,0.1)', offsetX: 0, offsetY: 10 })

      // Goodbye screen
      if (this.showGoodbye) {
        Column({ space: 24 }) {
          Text('👋').fontSize(72)
          Column({ space: 12 }) {
            Text('感谢您的访问').fontSize(24).fontWeight(FontWeight.Medium).fontColor(Color.White)
            Text('期待下次与您相见').fontSize(16).fontColor('rgba(255,255,255,0.7)')
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.9)')
      }

      // In-app WebView overlay for agreements
      if (this.webViewUrl.length > 0) {
        Column() {
          Row({ space: 12 }) {
            Text('✕')
              .fontSize(16)
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
      }
    }
    .width('100%')
    .height('100%')
  }

  private showDisagreeAlert(): void {
    AlertDialog.show({
      title: '温馨提示',
      message: '如果您不同意《用户协议》和《隐私政策》，很遗憾我们将无法为您提供服务。',
      primaryButton: {
        value: '同意',
        action: () => {
          this.isConsentChecked = true;
          this.onContinue();
        }
      },
      secondaryButton: {
        value: '放弃使用',
        fontColor: '#D0021B',
        action: () => {
          this.showGoodbye = true;
          setTimeout(() => {
            const context = getContext(this) as common.UIAbilityContext;
            context.terminateSelf();
          }, 2000);
        }
      }
    });
  }
}
