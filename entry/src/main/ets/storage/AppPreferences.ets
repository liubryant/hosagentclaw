/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AppConfig } from '../common/AppConfig';
import { ChatHistorySnapshot, ChatMessage, ChatEntryMode, LocalChatSession } from '../model/ChatModels';

const PREFS_NAME = 'agent_claw_prefs';
// Version 2 invalidates every consent recorded by builds that could initialize
// device/advertising SDKs before the privacy gate was fully isolated.
export const CURRENT_PRIVACY_POLICY_VERSION: number = 2;

class Key {
  static readonly gatewayURL = 'gateway_url';
  static readonly gatewayToken = 'gateway_token';
  static readonly allowInsecureLocalNetwork = 'allow_insecure_local_network';
  static readonly onboardingCompleted = 'onboarding_completed';
  static readonly privacyConsentVersion = 'privacy_consent_version';
  static readonly chatHistorySnapshot = 'chat_history_snapshot';
  static readonly isLoggedIn = 'is_logged_in';
  static readonly userPhone = 'user_phone';
  static readonly userAccessToken = 'user_access_token';
  static readonly serverFreeVideoDaily = 'server_free_video_daily';
  static readonly serverFreeImageDaily = 'server_free_image_daily';
  static readonly serverVipVideoDaily = 'server_vip_video_daily';
  static readonly serverVipImageDaily = 'server_vip_image_daily';
  static readonly quotaVideoDate = 'quota_video_date';
  static readonly quotaVideoCount = 'quota_video_count';
  static readonly quotaImageDate = 'quota_image_date';
  static readonly quotaImageCount = 'quota_image_count';
  static readonly avatarConversation = 'avatar_conversation';
  static readonly freeAgentQuestionCount = 'free_agent_question_count';
  static readonly vipActive = 'vip_active';
}

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
    // 隐私协议升级后必须重新征得同意。旧版本只有 onboarding_completed，
    // 不再将它视为当前版本的有效授权，避免升级安装绕过新的隐私声明。
    return this.privacyConsentVersion >= CURRENT_PRIVACY_POLICY_VERSION;
  }

  set onboardingCompleted(value: boolean) {
    this.safeStore.putSync(Key.onboardingCompleted, value);
    this.safeStore.putSync(Key.privacyConsentVersion, value ? CURRENT_PRIVACY_POLICY_VERSION : 0);
    this.safeStore.flush();
  }

  get privacyConsentVersion(): number {
    return this.safeStore.getSync(Key.privacyConsentVersion, 0) as number;
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

  get userAccessToken(): string | null {
    const raw = this.safeStore.getSync(Key.userAccessToken, '') as string;
    return raw === '' ? null : raw;
  }

  set userAccessToken(value: string | null) {
    if (value === null || value === '') {
      this.safeStore.deleteSync(Key.userAccessToken);
    } else {
      this.safeStore.putSync(Key.userAccessToken, value);
    }
    this.safeStore.flush();
  }

  get serverFreeVideoDaily(): number {
    return this.safeStore.getSync(Key.serverFreeVideoDaily, -1) as number;
  }

  set serverFreeVideoDaily(value: number) {
    this.safeStore.putSync(Key.serverFreeVideoDaily, value);
    this.safeStore.flush();
  }

  get serverFreeImageDaily(): number {
    return this.safeStore.getSync(Key.serverFreeImageDaily, -1) as number;
  }

  set serverFreeImageDaily(value: number) {
    this.safeStore.putSync(Key.serverFreeImageDaily, value);
    this.safeStore.flush();
  }

  get serverVipVideoDaily(): number {
    return this.safeStore.getSync(Key.serverVipVideoDaily, -1) as number;
  }

  set serverVipVideoDaily(value: number) {
    this.safeStore.putSync(Key.serverVipVideoDaily, value);
    this.safeStore.flush();
  }

  get serverVipImageDaily(): number {
    return this.safeStore.getSync(Key.serverVipImageDaily, -1) as number;
  }

  set serverVipImageDaily(value: number) {
    this.safeStore.putSync(Key.serverVipImageDaily, value);
    this.safeStore.flush();
  }

  get quotaVideoDate(): string {
    return this.safeStore.getSync(Key.quotaVideoDate, '') as string;
  }

  set quotaVideoDate(value: string) {
    this.safeStore.putSync(Key.quotaVideoDate, value);
    this.safeStore.flush();
  }

  get quotaVideoCount(): number {
    return this.safeStore.getSync(Key.quotaVideoCount, 0) as number;
  }

  set quotaVideoCount(value: number) {
    this.safeStore.putSync(Key.quotaVideoCount, value);
    this.safeStore.flush();
  }

  get quotaImageDate(): string {
    return this.safeStore.getSync(Key.quotaImageDate, '') as string;
  }

  set quotaImageDate(value: string) {
    this.safeStore.putSync(Key.quotaImageDate, value);
    this.safeStore.flush();
  }

  get quotaImageCount(): number {
    return this.safeStore.getSync(Key.quotaImageCount, 0) as number;
  }

  set quotaImageCount(value: number) {
    this.safeStore.putSync(Key.quotaImageCount, value);
    this.safeStore.flush();
  }

  get avatarConversation(): string {
    return this.safeStore.getSync(Key.avatarConversation, '') as string;
  }

  set avatarConversation(value: string) {
    this.safeStore.putSync(Key.avatarConversation, value);
    this.safeStore.flush();
  }

  get freeAgentQuestionCount(): number {
    return this.safeStore.getSync(Key.freeAgentQuestionCount, 0) as number;
  }

  set freeAgentQuestionCount(value: number) {
    this.safeStore.putSync(Key.freeAgentQuestionCount, Math.max(0, value));
    this.safeStore.flush();
  }

  get vipActive(): boolean {
    return this.safeStore.getSync(Key.vipActive, false) as boolean;
  }

  set vipActive(value: boolean) {
    this.safeStore.putSync(Key.vipActive, value);
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
