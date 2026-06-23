import { http } from '@kit.NetworkKit';

/**
 * 对应 iOS HTTPClient.swift 的 HTTPClientError.statusCode。
 */
export class HttpClientError extends Error {
  statusCode: number;

  constructor(statusCode: number, body: string) {
    super(body.length > 0 ? `HTTP ${statusCode}: ${body}` : `HTTP ${statusCode}`);
    this.statusCode = statusCode;
  }
}

/**
 * 对应 iOS URLSessionHTTPClient.swift，用 @ohos.net.http 实现一个轻量 JSON POST 客户端。
 */
export class HttpClient {
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
        connectTimeout: timeoutMs,
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
