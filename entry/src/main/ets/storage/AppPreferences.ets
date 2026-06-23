import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AppConfig } from '../common/AppConfig';
import { ChatHistorySnapshot, ChatMessage, ChatEntryMode, LocalChatSession } from '../model/ChatModels';

const PREFS_NAME = 'agent_claw_prefs';

class Key {
  static readonly gatewayURL = 'gateway_url';
  static readonly gatewayToken = 'gateway_token';
  static readonly allowInsecureLocalNetwork = 'allow_insecure_local_network';
  static readonly onboardingCompleted = 'onboarding_completed';
  static readonly chatHistorySnapshot = 'chat_history_snapshot';
  static readonly isLoggedIn = 'is_logged_in';
  static readonly userPhone = 'user_phone';
}

/**
 * 对应 iOS AppPreferences.swift + KeychainStore.swift。
 * 鸿蒙没有与 iOS Keychain 完全对应的能力，网关 Token 本身只是自托管网关的访问凭证，
 * 复杂度上与其敏感级别匹配，因此与其它偏好设置一样存进同一个 Preferences。
 */
export class AppPreferences {
  private static instance: AppPreferences | null = null;
  private store: preferences.Preferences | null = null;

  private constructor() {
  }

  static get shared(): AppPreferences {
    if (AppPreferences.instance === null) {
      AppPreferences.instance = new AppPreferences();
    }
    return AppPreferences.instance;
  }

  init(context: common.UIAbilityContext): void {
    this.store = preferences.getPreferencesSync(context, { name: PREFS_NAME });
  }

  private get safeStore(): preferences.Preferences {
    if (this.store === null) {
      throw new Error('AppPreferences.init(context) 尚未调用');
    }
    return this.store;
  }

  get gatewayURL(): string {
    const raw = this.safeStore.getSync(Key.gatewayURL, '') as string;
    if (raw === '' || raw === 'http://127.0.0.1:18789') {
      return AppConfig.defaultGatewayURL;
    }
    return raw;
  }

  set gatewayURL(value: string) {
    this.safeStore.putSync(Key.gatewayURL, value);
    this.safeStore.flush();
  }

  get gatewayToken(): string | null {
    const raw = this.safeStore.getSync(Key.gatewayToken, '') as string;
    return raw === '' ? null : raw;
  }

  set gatewayToken(value: string | null) {
    if (value === null || value === '') {
      this.safeStore.deleteSync(Key.gatewayToken);
    } else {
      this.safeStore.putSync(Key.gatewayToken, value);
    }
    this.safeStore.flush();
  }

  get allowInsecureLocalNetwork(): boolean {
    return this.safeStore.getSync(Key.allowInsecureLocalNetwork, true) as boolean;
  }

  set allowInsecureLocalNetwork(value: boolean) {
    this.safeStore.putSync(Key.allowInsecureLocalNetwork, value);
    this.safeStore.flush();
  }

  get onboardingCompleted(): boolean {
    return this.safeStore.getSync(Key.onboardingCompleted, false) as boolean;
  }

  set onboardingCompleted(value: boolean) {
    this.safeStore.putSync(Key.onboardingCompleted, value);
    this.safeStore.flush();
  }

  get isLoggedIn(): boolean {
    return this.safeStore.getSync(Key.isLoggedIn, false) as boolean;
  }

  set isLoggedIn(value: boolean) {
    this.safeStore.putSync(Key.isLoggedIn, value);
    this.safeStore.flush();
  }

  get userPhone(): string | null {
    const raw = this.safeStore.getSync(Key.userPhone, '') as string;
    return raw === '' ? null : raw;
  }

  set userPhone(value: string | null) {
    if (value === null || value === '') {
      this.safeStore.deleteSync(Key.userPhone);
    } else {
      this.safeStore.putSync(Key.userPhone, value);
    }
    this.safeStore.flush();
  }

  get chatHistorySnapshot(): ChatHistorySnapshot | null {
    const raw = this.safeStore.getSync(Key.chatHistorySnapshot, '') as string;
    if (raw === '') {
      return null;
    }
    try {
      const plain = JSON.parse(raw) as ChatHistorySnapshot;
      const snapshot = new ChatHistorySnapshot();
      snapshot.sessions = (plain.sessions ?? []).map(item => LocalChatSession.fromPlain(item));
      snapshot.selectedSessionID = plain.selectedSessionID ?? '';
      const messagesBySession: Record<string, ChatMessage[]> = {};
      const rawMessagesBySession = plain.messagesBySession ?? {};
      Object.keys(rawMessagesBySession).forEach(sessionId => {
        messagesBySession[sessionId] = rawMessagesBySession[sessionId].map(item => ChatMessage.fromPlain(item));
      });
      snapshot.messagesBySession = messagesBySession;
      snapshot.entryModesBySession = plain.entryModesBySession ?? {};
      return snapshot;
    } catch (e) {
      return null;
    }
  }

  set chatHistorySnapshot(value: ChatHistorySnapshot | null) {
    if (value === null) {
      this.safeStore.deleteSync(Key.chatHistorySnapshot);
      this.safeStore.flush();
      return;
    }
    this.safeStore.putSync(Key.chatHistorySnapshot, JSON.stringify(value));
    this.safeStore.flush();
  }
}
