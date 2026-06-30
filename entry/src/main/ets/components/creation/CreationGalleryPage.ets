/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { AgentClawDesign } from '../../common/Design';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { media } from '@kit.MediaKit';

const IMAGE_FILES: string[] = [
  '005_realistic_photos_1_5dfc37a87a.png',
  '006_futuristic_7bd187b758.png',
  '010_ai_Art_1_605d893d78.png',
  '011_chatbot_outputs_futuristic_F012_1_5bb2449c7b.jpeg',
  '014_chatbot_outputs_ai_art_A006_1_0deabdb264.jpeg',
  '025_T003_1_331b9b381c.jpeg',
  '026_H001_1_a6ca4e11a3.jpeg',
  '027_H002_1_06a73fec15.jpeg',
  '029_P001_1_1f23bf26f2.jpeg',
  '030_P002_1_89a0b37d93.jpeg',
  '032_chatbot_outputs_futuristic_F002_1_a0dcdcd846.jpeg',
  '034_chatbot_outputs_character_design_C001_1_9f59c78c39.jpeg',
  '035_chatbot_outputs_character_design_C002_1_674bfd08f2.jpeg',
  '042_T002_1_8daf154128.jpeg',
  '110_911054d8-122b-4902-b3e6-a84daecdc26c.jpg',
  'img_0260628060946_255_5.jpg',
  'img_0260628060948_256_5.jpg',
  'img_0260628060951_259_5.jpg',
  'img_0260628060952_260_5.jpg',
  'img_0260628060957_264_5.jpg',
  'IMG_20260628060942_251_5.jpg',
  'img_20260628060943_252_5.jpg',
  'img_20260628060944_253_5.jpg',
  'img_20260628060945_254_5.jpg',
  'img_20260628060949_257_5.jpg',
  'img_20260628060950_258_5.jpg',
  'img_20260628060954_261_5.jpg',
  'img_20260628060956_263_5.jpg'
];

const VIDEO_FILES: string[] = [
  '001_artlist-video.mp4',
  '002_artlist-video.mp4',
  '003_artlist-video.mp4',
  '20260626234950927b87ece9434098_watermark.mp4',
  '279529f6-c941-4c7f-94db-a6b7950eafc4.mp4',
  '29ad9e29-7ef1-4ce1-9356-647e03ee018c.mp4',
  '3e8ad80f-3029-4eea-bd11-f50155f9e9d9.mp4',
  '4efbfd8a-03d6-4313-8ca2-767ea8e1c74d.mp4',
  '58df21e3-e028-4899-b172-a20eef810161.mp4',
  '6ebb541b-fc70-457f-812f-4c2dfed28fcf.mp4',
  '78fd92ec-4344-4e15-ac7d-b2dd413d2ef0.mp4',
  '7f6a1e94-4f6e-48a6-8862-35ef4b0f1246.mp4',
  'a08e1d41-4f21-424d-b1cb-91e14fc7e457.mp4',
  'baf35bab-4786-4158-93b3-d45b94af332b.mp4',
  'beffa399-b85c-448e-9da4-3bbb361d5166.mp4',
  'ca881067-0d79-4191-b34d-17fba770ff16.mp4',
  'video2026-06-28_053455_290.mp4',
  'video2026-06-28_053513_175.mp4',
  'video2026-06-28_053520_974.mp4',
  'video2026-06-28_053528_225.mp4'
];

interface FeatureCard {
  title: string;
  subtitle: string;
  isPrimary: boolean;
  isVideo: boolean;
}

const IMAGE_FEATURE_CARDS: FeatureCard[] = [
  {
    title: '文生图',
    subtitle: '一句灵感，生成视觉作品',
    isPrimary: true,
    isVideo: false
  },
  {
    title: '图生图',
    subtitle: '上传参考图，重新设计',
    isPrimary: false,
    isVideo: false
  }
];

const VIDEO_FEATURE_CARDS: FeatureCard[] = [
  {
    title: '文生视频',
    subtitle: '让文字灵感动起来',
    isPrimary: true,
    isVideo: true
  },
  {
    title: '图生视频',
    subtitle: '让静态画面自然流动',
    isPrimary: false,
    isVideo: true
  }
];

@Component
export struct CreationGalleryPage {
  onLaunchImageChat: () => void = () => {};
  onLaunchVideoChat: () => void = () => {};
  onFullscreenChanged: (isFullscreen: boolean) => void = () => {};

  @State private activeTab: number = 0;
  @State private fullscreenImage: string = '';
  @State private fullscreenVideo: string = '';
  @State private videoThumbnails: (image.PixelMap | undefined)[] = [];

  aboutToAppear(): void {
    this.loadVideoThumbnails();
  }

  private async loadVideoThumbnails(): Promise<void> {
    for (let index = 0; index < VIDEO_FILES.length; index++) {
      const path = 'creation/videos/' + VIDEO_FILES[index];
      const generator = await media.createAVImageGenerator();
      let opened = false;
      try {
        const context = getContext(this) as common.UIAbilityContext;
        const rawFd = await context.resourceManager.getRawFd(path);
        opened = true;
        generator.fdSrc = {
          fd: rawFd.fd,
          offset: rawFd.offset,
          length: rawFd.length
        };
        // 取第 1 秒附近的关键帧，避开部分视频开头的纯黑场。
        const thumbnail = await generator.fetchFrameByTime(
          1000000,
          media.AVImageQueryOptions.AV_IMAGE_QUERY_CLOSEST_SYNC,
          { width: 480, height: 320 }
        );
        const info = await thumbnail.getImageInfo();
        const w = info.size.width;
        const h = info.size.height;
        if (w > h) {
          const cx = Math.floor((w - h) / 2);
          await thumbnail.crop({ x: cx, y: 0, size: { width: h, height: h } });
        } else if (h > w) {
          const cy = Math.floor((h - w) / 2);
          await thumbnail.crop({ x: 0, y: cy, size: { width: w, height: w } });
        }
        const updated = this.videoThumbnails.slice();
        updated[index] = thumbnail;
        this.videoThumbnails = updated;
      } catch (_) {
      } finally {
        await generator.release().catch(() => {});
        if (opened) {
          const context = getContext(this) as common.UIAbilityContext;
          await context.resourceManager.closeRawFd(path).catch(() => {});
        }
      }
    }
  }

  build() {
    Stack() {
      Column() {
        Scroll() {
          Column() {
            Text('今天用AI创作什么？')
              .fontSize(27)
              .fontWeight(FontWeight.Bold)
              .fontFamily('MiSans-DemiBold')
              .fontColor('#6750F5')
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ top: 26, bottom: 0 })
              .padding({ left: 20, right: 20 })

            Row() {
              this.tabPill('图片', 0)
              this.tabPill('视频', 1)
            }
            .width('100%')
            .height(52)
            .backgroundColor('#F0F0F5')
            .borderRadius(14)
            .padding(4)
            .margin({ left: 20, right: 20, top: 18 })
            .constraintSize({ maxWidth: '100%' })

            if (this.activeTab === 0) {
              this.imageTab()
            } else {
              this.videoTab()
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFDFD')

      if (this.fullscreenImage.length > 0) {
        this.fullscreenImageOverlay()
      }

      if (this.fullscreenVideo.length > 0) {
        this.fullscreenVideoOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private tabPill(label: string, index: number) {
    Column() {
      Text(label)
        .fontSize(15)
        .fontFamily('MiSans-DemiBold')
        .fontWeight(FontWeight.Bold)
        .fontColor(this.activeTab === index ? AgentClawDesign.accent : '#8C8C8C')
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .borderRadius(10)
    .backgroundColor(this.activeTab === index ? Color.White : Color.Transparent)
    .shadow(this.activeTab === index ? {
      radius: 4,
      color: 'rgba(0,0,0,0.08)',
      offsetX: 0,
      offsetY: 2
    } : { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 })
    .onClick(() => {
      this.activeTab = index;
    })
  }

  @Builder
  private imageTab() {
    Column({ space: 0 }) {
      // Feature cards row
      Row({ space: 10 }) {
        ForEach(IMAGE_FEATURE_CARDS, (card: FeatureCard) => {
          this.featureCard(card)
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16 })

      // Inspiration section header
      Text('灵感')
        .fontSize(18)
        .fontFamily('MiSans-DemiBold')
        .fontWeight(FontWeight.Bold)
        .fontColor('#1C1C22')
        .alignSelf(ItemAlign.Start)
        .margin({ left: 24, top: 18, bottom: 10 })

      // Image grid (2 columns)
      Grid() {
        ForEach(IMAGE_FILES, (filename: string) => {
          GridItem() {
            Image($rawfile('creation/images/' + filename))
              .width('100%')
              .height(160)
              .objectFit(ImageFit.Cover)
          }
          .width('100%')
          .height(160)
          .backgroundColor('#F0F0F4')
          .borderRadius(10)
          .border({ width: 1, color: 'rgba(0,0,0,0.06)' })
          .clip(true)
          .onClick(() => { this.fullscreenImage = filename; this.onFullscreenChanged(true); })
        }, (filename: string) => filename)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(8)
      .rowsGap(8)
      .padding({ left: 20, right: 20, bottom: 16 })
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private videoTab() {
    Column({ space: 0 }) {
      // Feature cards row
      Row({ space: 10 }) {
        ForEach(VIDEO_FEATURE_CARDS, (card: FeatureCard) => {
          this.featureCard(card)
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16 })

      // Inspiration section header
      Text('灵感')
        .fontSize(18)
        .fontFamily('MiSans-DemiBold')
        .fontWeight(FontWeight.Bold)
        .fontColor('#1C1C22')
        .alignSelf(ItemAlign.Start)
        .margin({ left: 24, top: 18, bottom: 10 })

      // Video grid (2 columns)
      Grid() {
        ForEach(VIDEO_FILES, (filename: string, index: number) => {
          GridItem() {
            Stack({ alignContent: Alignment.TopEnd }) {
              if (this.videoThumbnails[index] !== undefined) {
                Image(this.videoThumbnails[index])
                  .width('100%')
                  .height('100%')
                  .objectFit(ImageFit.Cover)
              } else {
                Column()
                  .width('100%')
                  .height('100%')
                  .linearGradient({
                    angle: 150,
                    colors: [['#7558F7', 0], ['#187FD8', 0.55], ['#5CC6BE', 1]] as [string, number][]
                  })
              }

              Stack() {
                Image($rawfile('icons/ic_creation_play.svg'))
                  .width(20)
                  .height(20)
              }
              .width(42)
              .height(42)
              .borderRadius(21)
              .backgroundColor('rgba(24,25,32,0.72)')
              .border({ width: 1, color: 'rgba(255,255,255,0.33)' })
              .margin({ top: 10, right: 10 })
            }
            .width('100%')
            .height('100%')
          }
          .width('100%')
          .height(160)
          .backgroundColor('#F0F0F4')
          .borderRadius(10)
          .border({ width: 1, color: 'rgba(0,0,0,0.06)' })
          .clip(true)
          .onClick(() => { this.fullscreenVideo = filename; this.onFullscreenChanged(true); })
        }, (filename: string) => filename)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(8)
      .rowsGap(8)
      .padding({ left: 20, right: 20, bottom: 16 })
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private featureCard(card: FeatureCard) {
    Column({ space: 0 }) {
      Blank().layoutWeight(1)

      Image(card.isPrimary ? $rawfile('icons/ic_creation_spark.svg') : $rawfile('icons/ic_creation_layers.svg'))
        .width(27)
        .height(27)

      Text(card.title)
        .fontSize(16)
        .fontFamily('MiSans-DemiBold')
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ top: 7 })

      Text(card.subtitle)
        .fontSize(10)
        .fontFamily('MiSans-Normal')
        .fontColor('rgba(223,255,255,0.87)')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .layoutWeight(1)
    .height(104)
    .borderRadius(22)
    .justifyContent(FlexAlign.End)
    .linearGradient(card.isPrimary ? {
      angle: 315,
      colors: [['#7558F7', 0], ['#9A56EE', 0.5], ['#D06BCB', 1]]
    } : {
      angle: 315,
      colors: [['#187FD8', 0], ['#1EA7D5', 0.5], ['#5CC6BE', 1]]
    })
    .onClick(() => {
      if (card.isVideo) {
        this.onLaunchVideoChat();
      } else {
        this.onLaunchImageChat();
      }
    })
  }

  @Builder
  private fullscreenImageOverlay() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor('#050507')

      Image($rawfile('creation/images/' + this.fullscreenImage))
        .width('100%').height('100%').objectFit(ImageFit.Contain)

      // Controls layer
      Column() {
        Row() {
          Column() {
            Text('✕').fontSize(16).fontColor(Color.White)
          }
          .width(44).height(44).borderRadius(22)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('rgba(34,34,40,0.66)')
          .border({ width: 1, color: 'rgba(255,255,255,0.27)' })
          .onClick(() => { this.fullscreenImage = ''; this.onFullscreenChanged(false); })

          Blank().layoutWeight(1)
        }
        .width('100%').padding({ left: 18, top: 56 })

        Blank().layoutWeight(1)

        Text('创作同款')
          .fontSize(16).fontFamily('MiSans-DemiBold').fontWeight(FontWeight.Bold)
          .fontColor(Color.White).textAlign(TextAlign.Center)
          .width(220).height(54).borderRadius(27)
          .linearGradient({ angle: 0, colors: [['#7658F7', 0], ['#9A51EC', 0.5], ['#D05DC4', 1]] as [string, number][] })
          .onClick(() => { this.fullscreenImage = ''; this.onFullscreenChanged(false); this.onLaunchImageChat(); })

        Blank().height(32)
      }
      .width('100%').height('100%').alignItems(HorizontalAlign.Center)
    }
    .width('100%').height('100%')
  }

  @Builder
  private fullscreenVideoOverlay() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor('#050507')

      Video({ src: $rawfile('creation/videos/' + this.fullscreenVideo) })
        .width('100%').height('100%').objectFit(ImageFit.Contain)
        .controls(false).autoPlay(true).loop(true)

      Column() {
        Row() {
          Column() {
            Text('✕').fontSize(16).fontColor(Color.White)
          }
          .width(44).height(44).borderRadius(22)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('rgba(34,34,40,0.66)')
          .border({ width: 1, color: 'rgba(255,255,255,0.27)' })
          .onClick(() => { this.fullscreenVideo = ''; this.onFullscreenChanged(false); })

          Blank().layoutWeight(1)
        }
        .width('100%').padding({ left: 18, top: 56 })

        Blank().layoutWeight(1)

        Text('创作同款')
          .fontSize(16).fontFamily('MiSans-DemiBold').fontWeight(FontWeight.Bold)
          .fontColor(Color.White).textAlign(TextAlign.Center)
          .width(220).height(54).borderRadius(27)
          .linearGradient({ angle: 0, colors: [['#7658F7', 0], ['#9A51EC', 0.5], ['#D05DC4', 1]] as [string, number][] })
          .onClick(() => { this.fullscreenVideo = ''; this.onFullscreenChanged(false); this.onLaunchVideoChat(); })

        Blank().height(88)
      }
      .width('100%').height('100%').alignItems(HorizontalAlign.Center)
    }
    .width('100%').height('100%')
  }

}
