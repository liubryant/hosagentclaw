/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { http } from '@kit.NetworkKit';

export class HttpClientError extends Error {
  statusCode: number;

  constructor(statusCode: number, body: string) {
    super(body.length > 0 ? `HTTP ${statusCode}: ${body}` : `HTTP ${statusCode}`);
    this.statusCode = statusCode;
  }
}

export class HttpClient {
  static async get(
    url: string,
    headers: Record<string, string>,
    timeoutMs: number
  ): Promise<string> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        readTimeout: timeoutMs,
        connectTimeout: 15000,
        expectDataType: http.HttpDataType.STRING
      });

      const bodyText = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new HttpClientError(response.responseCode, bodyText);
      }
      return bodyText;
    } finally {
      request.destroy();
    }
  }

  static async postJson(
    url: string,
    headers: Record<string, string>,
    bodyJson: string,
    timeoutMs: number
  ): Promise<string> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: bodyJson,
        readTimeout: timeoutMs,
        connectTimeout: 15000,
        expectDataType: http.HttpDataType.STRING
      });

      const bodyText = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new HttpClientError(response.responseCode, bodyText);
      }
      return bodyText;
    } finally {
      request.destroy();
    }
  }
}
