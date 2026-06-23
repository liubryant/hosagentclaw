import { deviceInfo } from '@kit.BasicServicesKit';
import { AppConfig } from '../common/AppConfig';
import { AppPreferences } from '../storage/AppPreferences';
import { HttpClient } from '../network/HttpClient';

/**
 * 对应安卓版 AuthService.kt：手机号短信验证码/密码登录、设置密码、注销账号。
 * 这些接口和 GatewayClient 的聊天鉴权完全独立，登录状态只是本地标记。
 */
export class LoginResult {
  phone: string;
  isNewUser: boolean;

  constructor(phone: string, isNewUser: boolean) {
    this.phone = phone;
    this.isNewUser = isNewUser;
  }
}

interface AuthResponseData {
  phone?: string;
  newUser?: boolean;
}

interface AuthResponse {
  code?: number | string;
  msg?: string;
  data?: AuthResponseData;
}

interface SmsCodeRequestBody {
  phone: string;
}

interface LoginByCodeRequestBody {
  phone: string;
  code: string;
  deviceModel: string;
  osVersion: string;
  appName: string;
}

interface LoginByPasswordRequestBody {
  phone: string;
  password: string;
  deviceModel: string;
  osVersion: string;
  appName: string;
}

interface SetPasswordRequestBody {
  phone: string;
  code: string;
  password: string;
}

interface DeleteAccountRequestBody {
  phone: string;
  code: string;
}

function rootBaseURL(): string {
  let url = AppPreferences.shared.gatewayURL.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (url.toLowerCase().endsWith('/v1')) {
    url = url.substring(0, url.length - 3);
  }
  return url;
}

function isSuccess(response: AuthResponse): boolean {
  return response.code === 0 || response.code === '0';
}

export class AuthServiceError extends Error {
}

export class AuthService {
  private static instance: AuthService | null = null;

  static get shared(): AuthService {
    if (AuthService.instance === null) {
      AuthService.instance = new AuthService();
    }
    return AuthService.instance;
  }

  async sendSmsCode(phone: string): Promise<void> {
    const body: SmsCodeRequestBody = { phone };
    const response = await this.postJson('/im/bot/login-code', JSON.stringify(body));
    if (!isSuccess(response)) {
      throw new AuthServiceError(response.msg && response.msg.length > 0 ? response.msg : '验证码发送失败，请稍后重试');
    }
  }

  async loginByCode(phone: string, code: string): Promise<LoginResult> {
    const body: LoginByCodeRequestBody = {
      phone,
      code,
      deviceModel: deviceInfo.marketName,
      osVersion: deviceInfo.osFullName,
      appName: 'AgentClaw'
    };
    const response = await this.postJson('/im/bot/login-by-code', JSON.stringify(body));
    if (!isSuccess(response)) {
      throw new AuthServiceError(response.msg && response.msg.length > 0 ? response.msg : '登录失败，请稍后重试');
    }
    const data = response.data;
    return new LoginResult(data?.phone && data.phone.length > 0 ? data.phone : phone, data?.newUser ?? false);
  }

  async loginByPassword(phone: string, password: string): Promise<LoginResult> {
    const body: LoginByPasswordRequestBody = {
      phone,
      password,
      deviceModel: deviceInfo.marketName,
      osVersion: deviceInfo.osFullName,
      appName: 'AgentClaw'
    };
    const response = await this.postJson('/im/bot/login-by-password', JSON.stringify(body));
    if (!isSuccess(response)) {
      throw new AuthServiceError(response.msg && response.msg.length > 0 ? response.msg : '登录失败，请稍后重试');
    }
    const data = response.data;
    return new LoginResult(data?.phone && data.phone.length > 0 ? data.phone : phone, data?.newUser ?? false);
  }

  async setPassword(phone: string, code: string, password: string): Promise<void> {
    const body: SetPasswordRequestBody = { phone, code, password };
    const response = await this.postJson('/im/bot/set-password', JSON.stringify(body));
    if (!isSuccess(response)) {
      throw new AuthServiceError(response.msg && response.msg.length > 0 ? response.msg : '设置失败，请稍后重试');
    }
  }

  async deleteAccount(phone: string, code: string): Promise<void> {
    const body: DeleteAccountRequestBody = { phone, code };
    const response = await this.postJson('/im/bot/remove_account', JSON.stringify(body));
    if (!isSuccess(response)) {
      throw new AuthServiceError(response.msg && response.msg.length > 0 ? response.msg : '注销失败，请稍后重试');
    }
  }

  private async postJson(path: string, json: string): Promise<AuthResponse> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    const text = await HttpClient.postJson(`${rootBaseURL()}${path}`, headers, json, AppConfig.requestTimeoutMs);
    return JSON.parse(text) as AuthResponse;
  }
}
