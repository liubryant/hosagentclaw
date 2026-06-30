/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const PREFS_NAME = 'agent_claw_prefs';
const KEY_APP_ENVIRONMENT = 'app_environment';

export enum AppEnvironment {
  PRODUCTION = 'production',
  TESTING = 'testing'
}

export function environmentBaseURL(env: AppEnvironment): string {
  if (env === AppEnvironment.TESTING) {
    return 'https://www.cjym123.cn/v1';
  }
  return 'https://www.cjym123.cn/v1';
}

export function environmentDisplayName(env: AppEnvironment): string {
  return env === AppEnvironment.PRODUCTION ? '生产环境' : '测试环境';
}

export class EnvironmentManager {
  private static instance: EnvironmentManager | null = null;
  private store: preferences.Preferences | null = null;
  private current: AppEnvironment = AppEnvironment.PRODUCTION;

  private constructor() {
  }

  static get shared(): EnvironmentManager {
    if (EnvironmentManager.instance === null) {
      EnvironmentManager.instance = new EnvironmentManager();
    }
    return EnvironmentManager.instance;
  }

  init(context: common.UIAbilityContext): void {
    this.store = preferences.getPreferencesSync(context, { name: PREFS_NAME });
    const raw = this.store.getSync(KEY_APP_ENVIRONMENT, 'production') as string;
    this.current = raw === 'testing' ? AppEnvironment.TESTING : AppEnvironment.PRODUCTION;
  }

  get currentEnvironment(): AppEnvironment {
    return this.current;
  }

  get baseURL(): string {
    return environmentBaseURL(this.current);
  }

  switchEnvironment(env: AppEnvironment): void {
    this.current = env;
    if (this.store === null) {
      return;
    }
    this.store.putSync(KEY_APP_ENVIRONMENT, env === AppEnvironment.TESTING ? 'testing' : 'production');
    this.store.flush();
  }
}

export class AppConfig {
  static readonly appName: string = 'Agent';
  static readonly defaultChatModel: string = 'glm-4.7';
  static readonly requestTimeoutMs: number = 5 * 60 * 1000;
  static readonly documentGenerationRequestTimeoutMs: number = 10 * 60 * 1000;
  static readonly mediaGenerationRequestTimeoutMs: number = 30 * 60 * 1000;

  static get defaultGatewayURL(): string {
    return EnvironmentManager.shared.baseURL;
  }
}
