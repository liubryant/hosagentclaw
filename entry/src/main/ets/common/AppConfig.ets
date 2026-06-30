import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const PREFS_NAME = 'agent_claw_prefs';
const KEY_APP_ENVIRONMENT = 'app_environment';

/**
 * 运行环境：对应 iOS AppConfig.swift 里的 AppEnvironment。
 */
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

/**
 * 对应 iOS EnvironmentManager：管理当前网关环境并持久化到本地。
 * 直接使用独立的 Preferences 实例（与 AppPreferences 共享同一个存储名），
 * 避免 AppConfig 与 AppPreferences 之间出现循环依赖（与 iOS 用 UserDefaults.standard 一致）。
 */
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

/**
 * 对应 iOS AppConfig.swift。
 */
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
