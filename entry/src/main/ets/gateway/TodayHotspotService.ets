import { http } from '@kit.NetworkKit';
import { EnvironmentManager } from '../common/AppConfig';

export interface TodayHotspotItem {
  title: string;
  subtitle: string;
  prompt: string;
}

interface HotspotRawItem {
  title?: string;
  subtitle?: string;
  promptTemplate?: string;
}

interface HotspotResponse {
  code?: string | number;
  data?: HotspotRawItem[];
}

/**
 * 获取今日热点推荐话题。
 * 对应 Android TodayHotspotService。
 * 调用 /im/bot/navi/hotspots 接口（API root，去掉 /v1 后缀）。
 */
export class TodayHotspotService {
  private static instance: TodayHotspotService | null = null;

  static get shared(): TodayHotspotService {
    if (TodayHotspotService.instance === null) {
      TodayHotspotService.instance = new TodayHotspotService();
    }
    return TodayHotspotService.instance;
  }

  async fetchHotspots(): Promise<TodayHotspotItem[]> {
    const baseURL = EnvironmentManager.shared.baseURL;
    // Strip /v1 suffix to get the API root
    const apiRoot = baseURL.endsWith('/v1') ? baseURL.slice(0, -3) : baseURL;
    const url = `${apiRoot}/im/bot/navi/hotspots`;

    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' },
        readTimeout: 10000,
        connectTimeout: 10000,
        expectDataType: http.HttpDataType.STRING
      });

      const bodyText = typeof response.result === 'string'
        ? response.result
        : JSON.stringify(response.result);

      const json = JSON.parse(bodyText) as HotspotResponse;
      const code = json.code;

      if (code !== '0' && code !== 0) {
        return [];
      }

      const data = json.data ?? [];
      return data
        .map((item): TodayHotspotItem => ({
          title: item.title ?? '',
          subtitle: item.subtitle ?? '',
          prompt: item.promptTemplate ?? ''
        }))
        .filter((item): boolean => item.title.length > 0);
    } catch (e) {
      console.warn('[TodayHotspotService] fetchHotspots failed:', e);
      return [];
    } finally {
      request.destroy();
    }
  }
}
