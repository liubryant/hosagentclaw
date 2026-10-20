/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { http } from '@kit.NetworkKit';
import { EnvironmentManager } from '../common/AppConfig';

export interface TodayHotspotItem {
  title: string;
  subtitle: string;
  prompt: string;
}

const CHINA_SPACE_STATION_HOTSPOT: TodayHotspotItem = {
  title: '今晚能看到中国空间站吗？',
  subtitle: '过境时间、方向与手机拍摄技巧',
  prompt: '中国空间站今晚几点从我所在城市上空经过？朝哪个方向看？用手机怎么拍？'
};

interface HotspotRawItem {
  title?: string;
  subtitle?: string;
  promptTemplate?: string;
}

interface HotspotResponse {
  code?: string | number;
  data?: HotspotRawItem[];
}

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
        return [CHINA_SPACE_STATION_HOTSPOT];
      }

      const data = json.data ?? [];
      const remoteItems = data
        .map((item): TodayHotspotItem => ({
          title: item.title ?? '',
          subtitle: item.subtitle ?? '',
          prompt: item.promptTemplate ?? ''
        }))
        .filter((item): boolean => item.title.length > 0);
      return [
        CHINA_SPACE_STATION_HOTSPOT,
        ...remoteItems.filter((item): boolean => item.title !== CHINA_SPACE_STATION_HOTSPOT.title)
      ];
    } catch (e) {
      console.warn('[TodayHotspotService] fetchHotspots failed:', e);
      return [CHINA_SPACE_STATION_HOTSPOT];
    } finally {
      request.destroy();
    }
  }
}
