/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { AppConfig } from '../common/AppConfig';
import { AppPreferences } from '../storage/AppPreferences';
import { HttpClient } from '../network/HttpClient';
import { MembershipInfo, MembershipInfoJson, VipOrderData, VipProduct, VipProductJson, VipQuotaJson } from './VipProduct';

const AGENTCLAW_ALIPAY_APP_ID = '2021006169619056';

interface ProductListData {
  list?: VipProductJson[];
  products?: VipProductJson[];
  items?: VipProductJson[];
}

type ApiData = VipProductJson[] | ProductListData | MembershipInfoJson | VipOrderData;

interface ApiResponse {
  code?: number | string;
  msg?: string;
  data?: ApiData;
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

function isSuccess(response: ApiResponse): boolean {
  return response.code === 0 || response.code === '0';
}

export class PaymentApiError extends Error {
}

export class PaymentApi {
  private static instance: PaymentApi | null = null;

  static get shared(): PaymentApi {
    if (PaymentApi.instance === null) {
      PaymentApi.instance = new PaymentApi();
    }
    return PaymentApi.instance;
  }

  async getProducts(): Promise<VipProduct[]> {
    const response = await this.getJson('/products');
    const data = response.data;
    let list: VipProductJson[] = [];
    if (Array.isArray(data)) {
      list = data as VipProductJson[];
    } else if (data !== undefined) {
      const productData = data as ProductListData;
      list = productData.list ?? productData.products ?? productData.items ?? [];
    }
    return list.map((item: VipProductJson): VipProduct => VipProduct.from(item))
      .filter((item: VipProduct): boolean => item.id.length > 0);
  }

  async getMembership(accessToken: string): Promise<MembershipInfo> {
    const response = await this.getJson('/membership', accessToken);
    const data = (response.data ?? {}) as MembershipInfoJson;
    this.saveQuotaConfig(data.quota);
    return MembershipInfo.from(data);
  }

  async createOrder(accessToken: string, productId: string): Promise<VipOrderData> {
    const body = JSON.stringify({
      productId: productId,
      payChannel: 'alipay',
      appid: AGENTCLAW_ALIPAY_APP_ID,
      platform: 'harmony'
    });
    const response = await this.postJson('/orders', body, accessToken);
    return (response.data ?? {}) as VipOrderData;
  }

  async queryOrder(accessToken: string, orderId: string): Promise<VipOrderData> {
    const response = await this.getJson(`/orders/${orderId}`, accessToken);
    return (response.data ?? {}) as VipOrderData;
  }

  private async getJson(path: string, accessToken: string | null = null): Promise<ApiResponse> {
    const headers: Record<string, string> = {};
    if (accessToken !== null && accessToken.length > 0) {
      headers['Authorization'] = `Bearer ${accessToken}`;
    }
    const raw = await HttpClient.get(`${rootBaseURL()}/im/bot/navi/vip${path}`, headers, AppConfig.requestTimeoutMs);
    return this.parseResponse(raw, path);
  }

  private async postJson(path: string, body: string, accessToken: string): Promise<ApiResponse> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`
    };
    const raw = await HttpClient.postJson(`${rootBaseURL()}/im/bot/navi/vip${path}`, headers, body, AppConfig.requestTimeoutMs);
    return this.parseResponse(raw, path);
  }

  private parseResponse(raw: string, path: string): ApiResponse {
    const response = JSON.parse(raw) as ApiResponse;
    if (!isSuccess(response)) {
      throw new PaymentApiError(response.msg && response.msg.length > 0 ? response.msg : `请求失败：${path}`);
    }
    return response;
  }

  private saveQuotaConfig(quota: VipQuotaJson | undefined): void {
    if (quota === undefined || quota === null) {
      return;
    }
    const freeVideoDaily = this.quotaNumber(quota.freeVideoDaily);
    const freeImageDaily = this.quotaNumber(quota.freeImageDaily);
    const vipVideoDaily = this.quotaNumber(quota.vipVideoDaily);
    const vipImageDaily = this.quotaNumber(quota.vipImageDaily);
    if (freeVideoDaily !== null) {
      AppPreferences.shared.serverFreeVideoDaily = freeVideoDaily;
    }
    if (freeImageDaily !== null) {
      AppPreferences.shared.serverFreeImageDaily = freeImageDaily;
    }
    if (vipVideoDaily !== null) {
      AppPreferences.shared.serverVipVideoDaily = vipVideoDaily;
    }
    if (vipImageDaily !== null) {
      AppPreferences.shared.serverVipImageDaily = vipImageDaily;
    }
  }

  private quotaNumber(value: number | string | undefined): number | null {
    if (value === undefined) {
      return null;
    }
    const numericValue = typeof value === 'number' ? value : Number(value);
    return Number.isFinite(numericValue) ? numericValue : null;
  }
}
