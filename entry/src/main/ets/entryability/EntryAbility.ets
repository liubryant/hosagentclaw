/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { font, window } from '@kit.ArkUI';
import { AppPreferences } from '../storage/AppPreferences';
import { EnvironmentManager } from '../common/AppConfig';
import { GeneratedDocumentStore } from '../store/GeneratedDocumentStore';
import { WindowStageHolder } from '../common/WindowStageHolder';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    AppPreferences.shared.init(this.context);
    EnvironmentManager.shared.init(this.context);
    GeneratedDocumentStore.shared.init(this.context);
    WindowStageHolder.abilityContext = this.context;
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    WindowStageHolder.windowStage = windowStage;

    font.registerFont({ familyName: 'MiSans', familySrc: $rawfile('fonts/misans_medium.ttf') });
    font.registerFont({ familyName: 'MiSans-DemiBold', familySrc: $rawfile('fonts/misans_demibold.ttf') });
    font.registerFont({ familyName: 'MiSans-Normal', familySrc: $rawfile('fonts/misans_normal.ttf') });

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
