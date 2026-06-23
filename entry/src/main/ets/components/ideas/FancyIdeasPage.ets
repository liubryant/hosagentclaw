import { AgentClawDesign } from '../../common/Design';
import { FancyIdea, FancyIdeaGroup, FancyIdeaStore } from './FancyIdeaData';

/**
 * 对应 iOS FancyIdeasView.swift。
 */
@Component
export struct FancyIdeasPage {
  onUseIdea: (idea: FancyIdea) => void = () => {
  };
  private groups: FancyIdeaGroup[] = FancyIdeaStore.groups;

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Text('选择一个灵感，再带入对话细化')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(AgentClawDesign.primaryText)
          .margin({ top: 14 })

        ForEach(this.groups, (group: FancyIdeaGroup) => {
          Column({ space: 6 }) {
            Text(group.title)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(AgentClawDesign.primaryText)
              .margin({ top: 4, bottom: 6 })
              .width('100%')

            this.ideaGrid(group.items)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 18 })
    }
    .backgroundColor(AgentClawDesign.controlSurface)
    .width('100%')
    .height('100%')
  }

  @Builder
  private ideaGrid(items: FancyIdea[]) {
    Column({ space: 10 }) {
      ForEach(this.rows(items), (row: FancyIdea[]) => {
        Row({ space: 10 }) {
          ForEach(row, (idea: FancyIdea) => {
            this.ideaCard(idea)
          }, (idea: FancyIdea) => idea.id)

          if (row.length === 1) {
            Blank().layoutWeight(1)
          }
        }
        .width('100%')
      })
    }
    .width('100%')
  }

  private rows(items: FancyIdea[]): FancyIdea[][] {
    const result: FancyIdea[][] = [];
    for (let index = 0; index < items.length; index += 2) {
      result.push(items.slice(index, Math.min(index + 2, items.length)));
    }
    return result;
  }

  @Builder
  private ideaCard(idea: FancyIdea) {
    Column({ space: 0 }) {
      Image(idea.imageName)
        .width(48)
        .height(40)
        .objectFit(ImageFit.Contain)
        .align(Alignment.TopStart)

      Text(idea.title)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(AgentClawDesign.primaryText)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 14 })

      Text(idea.subtitle)
        .fontSize(12)
        .fontColor(AgentClawDesign.secondaryText)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .constraintSize({ minHeight: 128 })
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.08)', offsetX: 0, offsetY: 3 })
    .onClick(() => {
      this.onUseIdea(idea);
    })
  }
}
