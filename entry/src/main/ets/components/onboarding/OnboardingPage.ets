import { common } from '@kit.AbilityKit';
import { AgentClawDesign } from '../../common/Design';

const AGREEMENT_URL = 'https://www.cjym123.cn/agreement_agentclaw.html';
const PRIVACY_URL = 'https://www.cjym123.cn/privacy_agentclaw.html';

/**
 * 对应 iOS OnboardingView.swift。
 */
@Component
export struct OnboardingPage {
  onContinue: () => void = () => {
  };
  @State private showGoodbye: boolean = false;

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.3)')

      Column({ space: 16 }) {
        Column({ space: 10 }) {
          Image($r('app.media.app_icon_display'))
            .width(72)
            .height(72)
            .borderRadius(16)

          Text('个人信息保护提示')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.Black)
        }

        Scroll() {
          Column({ space: 12 }) {
            Text('欢迎来到Agent智能体生活助手！')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.Black)
              .width('100%')

            Column({ space: 6 }) {
              Row({ space: 0 }) {
                Text('我们将通过').fontSize(13).fontColor(AgentClawDesign.secondaryText)
                Text('《用户协议》')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AgentClawDesign.accent)
                  .onClick(() => {
                    this.openLink(AGREEMENT_URL);
                  })
                Text('和').fontSize(13).fontColor(AgentClawDesign.secondaryText)
                Text('《隐私政策》')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AgentClawDesign.accent)
                  .onClick(() => {
                    this.openLink(PRIVACY_URL);
                  })
              }

              Text('帮助您了解我们为您提供的服务、我们如何处理个人信息以及您享有的权利。我们会严格按照相关法律法规要求，采取各种安全措施来保护您的个人信息。')
                .fontSize(13)
                .fontColor(AgentClawDesign.secondaryText)
                .lineHeight(19)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            Text('点击"同意"按钮，表示您已知情并同意以上协议和以下约定。')
              .fontSize(13)
              .fontColor(AgentClawDesign.secondaryText)
              .lineHeight(19)
              .width('100%')

            Column({ space: 8 }) {
              Text('1.   为了保障软件的安全运行和账户安全，我们会申请收集您的设备信息、IP地址、MAC地址。').fontSize(13).fontColor(AgentClawDesign.secondaryText)
              Text('2.   保存图片、视频，需要使用您的存储、相机、麦克风权限。').fontSize(13).fontColor(AgentClawDesign.secondaryText)
              Text('3.   我们可能会申请位置权限，用于为您推荐您可能感兴趣的内容。').fontSize(13).fontColor(AgentClawDesign.secondaryText)
              Text('4.   我们尊重您的选择权，您可以删除您的个人数据并管理，我们也为您提供反馈投诉渠道。').fontSize(13).fontColor(AgentClawDesign.secondaryText)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .padding(16)
        }
        .align(Alignment.TopStart)
        .constraintSize({ maxHeight: 250 })
        .backgroundColor('rgba(0,0,0,0.035)')
        .borderRadius(12)

        Row({ space: 12 }) {
          Text('不同意')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AgentClawDesign.secondaryText)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(48)
            .backgroundColor('rgba(0,0,0,0.06)')
            .borderRadius(10)
            .onClick(() => {
              this.showDisagreeAlert();
            })

          Text('同意')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(48)
            .backgroundColor(AgentClawDesign.accent)
            .borderRadius(10)
            .onClick(() => {
              this.onContinue();
            })
        }
      }
      .padding(24)
      .constraintSize({ maxWidth: 480 })
      .width('86%')
      .backgroundColor(Color.White)
      .borderRadius(16)
      .shadow({ radius: 20, color: 'rgba(0,0,0,0.1)', offsetX: 0, offsetY: 10 })

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

  private openLink(url: string): void {
    const context = getContext(this) as common.UIAbilityContext;
    context.openLink(url).catch(() => {
    });
  }
}
