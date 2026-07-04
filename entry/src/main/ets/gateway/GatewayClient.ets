/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { AppConfig, EnvironmentManager } from '../common/AppConfig';
import { AppPreferences } from '../storage/AppPreferences';
import { HttpClient } from '../network/HttpClient';
import {
  ChatCompletionRequest,
  ChatCompletionRequestMessage,
  ChatCompletionResponse,
  ChatMessage,
  firstContentOf
} from '../model/ChatModels';
import { GatewayConfig } from './GatewayConfig';

const IMAGE_MODE_MARKER = '[[IMAGE_MODE]]';
const VIDEO_MODE_MARKER = '[[VIDEO_MODE]]';
const DOCUMENT_MODE_MARKER = '[[DOCUMENT_MODE]]';
const VIDEO_POLL_INTERVAL_MS = 5000;
const VIDEO_POLL_TIMEOUT_MS = 150000;

type JsonObject = Record<string, Object>;

interface VideoOutput {
  url: string;
  coverURL: string | null;
}

interface ImageOutput {
  url: string;
}

function normalizeGatewayBase(rawURL: string): string {
  let base = rawURL.trim();
  const hashIndex = base.indexOf('#');
  if (hashIndex >= 0) {
    base = base.substring(0, hashIndex);
  }
  const queryIndex = base.indexOf('?');
  if (queryIndex >= 0) {
    base = base.substring(0, queryIndex);
  }
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  return base;
}

function stripModeMarkers(content: string): string {
  return content
    .replace(IMAGE_MODE_MARKER, '')
    .replace(VIDEO_MODE_MARKER, '')
    .replace(DOCUMENT_MODE_MARKER, '')
    .replace(/\s{2,}/g, ' ')
    .trim();
}

export class GatewayClient {
  private static instance: GatewayClient | null = null;

  static get shared(): GatewayClient {
    if (GatewayClient.instance === null) {
      GatewayClient.instance = new GatewayClient();
    }
    return GatewayClient.instance;
  }

  get config(): GatewayConfig {
    return new GatewayConfig(
      AppPreferences.shared.gatewayURL,
      AppPreferences.shared.gatewayToken,
      AppPreferences.shared.allowInsecureLocalNetwork
    );
  }

  saveConfig(config: GatewayConfig): void {
    AppPreferences.shared.gatewayURL = normalizeGatewayBase(config.baseURL);
    AppPreferences.shared.allowInsecureLocalNetwork = config.allowInsecureLocalNetwork;
    AppPreferences.shared.gatewayToken = config.token;
  }

  /**
   * 对应 SettingsPanelView 里隐藏的"运行环境"切换 和 "清除所有数据" 后调用的
   * gatewayViewModel.refreshFromEnvironment()：把网关地址重置为当前环境对应的默认地址。
   */
  refreshFromEnvironment(): void {
    AppPreferences.shared.gatewayURL = normalizeGatewayBase(EnvironmentManager.shared.baseURL);
  }

  private modelForRequest(requestedModel: string, hasImageModeMarker: boolean, hasVideoModeMarker: boolean): string {
    if (hasImageModeMarker) {
      return 'glm-image';
    }
    if (hasVideoModeMarker) {
      return 'cogvideox-3';
    }
    const lower = requestedModel.toLowerCase();
    if (lower === 'glm-image' || lower === 'cogvideox-3') {
      return AppConfig.defaultChatModel;
    }
    return requestedModel;
  }

  async sendChat(messages: ChatMessage[], model: string = AppConfig.defaultChatModel): Promise<string> {
    const hasImageModeMarker = messages.some(item => item.content.includes(IMAGE_MODE_MARKER));
    const hasVideoModeMarker = messages.some(item => item.content.includes(VIDEO_MODE_MARKER));
    const hasDocumentModeMarker = messages.some(item => item.content.includes(DOCUMENT_MODE_MARKER));

    let timeoutMs = AppConfig.requestTimeoutMs;
    if (hasImageModeMarker || hasVideoModeMarker) {
      timeoutMs = AppConfig.mediaGenerationRequestTimeoutMs;
    } else if (hasDocumentModeMarker) {
      timeoutMs = AppConfig.documentGenerationRequestTimeoutMs;
    }

    const url = `${normalizeGatewayBase(this.config.baseURL)}/chat/completions`;
    const requestModel = this.modelForRequest(model, hasImageModeMarker, hasVideoModeMarker);
    const requestMessages: ChatCompletionRequestMessage[] = messages.map((item): ChatCompletionRequestMessage => {
      return { role: item.role, content: stripModeMarkers(item.content) };
    });

    const request: ChatCompletionRequest = {
      model: requestModel,
      stream: false,
      messages: requestMessages
    };
    if (hasVideoModeMarker) {
      request.responseMode = 'video_only';
    }

    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    const token = this.config.token;
    if (token !== null && token.length > 0) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const bodyText = await HttpClient.postJson(url, headers, JSON.stringify(request), timeoutMs);
    const response = JSON.parse(bodyText) as ChatCompletionResponse;
    return firstContentOf(response);
  }

  async generateImageEdit(prompt: string, imageBase64: string): Promise<string> {
    const cleanPrompt = prompt.trim();
    if (cleanPrompt.length === 0) {
      throw new Error('图片编辑描述不能为空');
    }
    if (imageBase64.trim().length === 0) {
      throw new Error('请选择要编辑的图片');
    }

    const body = JSON.stringify({
      prompt: cleanPrompt,
      image: `data:image/jpeg;base64,${imageBase64}`
    });
    const bodyText = await HttpClient.postJson(
      `${normalizeGatewayBase(this.config.baseURL)}/images/edits`,
      this.authHeaders(),
      body,
      AppConfig.mediaGenerationRequestTimeoutMs
    );
    const json = GatewayClient.decodeObject(bodyText);
    const output = GatewayClient.imageOutput(json);
    if (output === null) {
      throw new Error('图片生成完成，但未返回可展示的图片地址');
    }
    return GatewayClient.imageMessage(cleanPrompt, output.url);
  }

  /** Submit a CogVideo task and poll the task endpoint until a playable URL is returned. */
  async generateVideo(prompt: string, onStatus: (status: string) => void = () => {}): Promise<string> {
    const cleanPrompt = prompt.trim();
    if (cleanPrompt.length === 0) {
      throw new Error('视频描述不能为空');
    }

    const baseURL = normalizeGatewayBase(this.config.baseURL);
    const headers = this.authHeaders();
    const body = JSON.stringify({
      model: 'cogvideox-3',
      prompt: cleanPrompt,
      quality: 'speed',
      with_audio: false,
      size: '1280x720',
      fps: 30
    });
    const submittedText = await HttpClient.postJson(
      `${baseURL}/videos/generations`,
      headers,
      body,
      30000
    );
    let latest = GatewayClient.decodeObject(submittedText);
    const immediateOutput = GatewayClient.videoOutput(latest);
    if (immediateOutput !== null) {
      return GatewayClient.videoMessage(cleanPrompt, null, immediateOutput);
    }

    const taskID = GatewayClient.stringValue('id', latest);
    if (taskID === null || taskID.length === 0) {
      throw new Error('视频任务提交失败：未返回任务 ID');
    }
    onStatus(`视频生成任务已提交\n任务ID：${taskID}`);

    const deadline = Date.now() + VIDEO_POLL_TIMEOUT_MS;
    let lastStatus = 'PROCESSING';
    while (Date.now() <= deadline) {
      const status = (GatewayClient.stringValue('task_status', latest) ??
        GatewayClient.stringValue('status', latest) ?? 'PROCESSING').toUpperCase();
      lastStatus = status;
      const output = GatewayClient.videoOutput(latest);
      if (output !== null) {
        return GatewayClient.videoMessage(cleanPrompt, taskID, output);
      }
      if (['FAIL', 'FAILED', 'CANCELED', 'CANCELLED'].includes(status)) {
        throw new Error(`视频生成失败：${status}`);
      }

      onStatus(`视频生成中，请稍候…\n任务ID：${taskID}\n状态：${status}`);
      await GatewayClient.delay(VIDEO_POLL_INTERVAL_MS);
      const pollText = await HttpClient.get(
        `${baseURL}/videos/generations/${encodeURIComponent(taskID)}`,
        headers,
        30000
      );
      latest = GatewayClient.decodeObject(pollText);
    }

    throw new Error(`视频生成时间较长，请稍后再试。任务ID：${taskID}，最后状态：${lastStatus}`);
  }

  private authHeaders(): Record<string, string> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    const token = this.config.token;
    if (token !== null && token.length > 0) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    return headers;
  }

  private static decodeObject(bodyText: string): JsonObject {
    const parsed = JSON.parse(bodyText) as Object;
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new Error('视频接口返回格式不是 JSON 对象');
    }
    return parsed as JsonObject;
  }

  private static payload(json: JsonObject): JsonObject {
    const data = json['data'];
    if (data !== undefined && data !== null && typeof data === 'object' && !Array.isArray(data)) {
      return data as JsonObject;
    }
    return json;
  }

  private static stringValue(key: string, json: JsonObject): string | null {
    const value = GatewayClient.payload(json)[key];
    if (typeof value === 'string') {
      return value;
    }
    if (typeof value === 'number') {
      return `${value}`;
    }
    return null;
  }

  private static videoOutput(json: JsonObject): VideoOutput | null {
    const root = GatewayClient.payload(json);
    const collectionKeys = ['video_result', 'videos', 'results', 'output', 'data'];
    for (const key of collectionKeys) {
      const value = root[key];
      if (Array.isArray(value)) {
        const values = value as Object[];
        for (const item of values) {
          if (item !== null && typeof item === 'object') {
            const found = GatewayClient.videoOutputInItem(item as JsonObject);
            if (found !== null) {
              return found;
            }
          }
        }
      } else if (value !== undefined && value !== null && typeof value === 'object') {
        const found = GatewayClient.videoOutputInItem(value as JsonObject);
        if (found !== null) {
          return found;
        }
      }
    }

    const direct = GatewayClient.videoOutputInItem(root);
    if (direct !== null) {
      return direct;
    }

    const choices = root['choices'];
    if (Array.isArray(choices) && choices.length > 0) {
      const choice = choices[0] as JsonObject;
      const message = choice['message'] as JsonObject;
      const videos = message !== undefined ? message['videos'] : undefined;
      if (Array.isArray(videos)) {
        const videoItems = videos as Object[];
        for (const video of videoItems) {
          if (video !== null && typeof video === 'object') {
            const item = video as JsonObject;
            const nested = item['video_url'];
            if (nested !== undefined && nested !== null && typeof nested === 'object') {
              const url = (nested as JsonObject)['url'];
              if (typeof url === 'string' && url.length > 0) {
                return { url: url, coverURL: null };
              }
            }
          }
        }
      }
    }
    return GatewayClient.deepVideoOutput(root);
  }

  private static imageOutput(json: JsonObject): ImageOutput | null {
    const root = GatewayClient.payload(json);
    for (const key of ['data', 'images']) {
      const value = root[key];
      if (Array.isArray(value)) {
        const items = value as Object[];
        for (const item of items) {
          if (item !== null && typeof item === 'object') {
            const url = (item as JsonObject)['url'];
            if (typeof url === 'string' && url.length > 0) {
              return { url: url };
            }
          }
        }
      }
    }

    const choices = root['choices'];
    if (Array.isArray(choices) && choices.length > 0) {
      const choice = choices[0] as JsonObject;
      const message = choice['message'] as JsonObject;
      const images = message !== undefined ? message['images'] : undefined;
      if (Array.isArray(images)) {
        const imageItems = images as Object[];
        for (const imageItem of imageItems) {
          if (imageItem !== null && typeof imageItem === 'object') {
            const nested = (imageItem as JsonObject)['image_url'];
            if (nested !== undefined && nested !== null && typeof nested === 'object') {
              const url = (nested as JsonObject)['url'];
              if (typeof url === 'string' && url.length > 0) {
                return { url: url };
              }
            }
          }
        }
      }
    }
    return null;
  }

  private static videoOutputInItem(item: JsonObject): VideoOutput | null {
    const coverValue = item['cover_image_url'] ?? item['coverImageUrl'] ?? item['cover_url'];
    const coverURL = typeof coverValue === 'string' && coverValue.length > 0 ? coverValue : null;
    for (const key of ['url', 'video_url', 'videoUrl', 'play_url', 'playUrl', 'output_url', 'file_url', 'download_url']) {
      const value = item[key];
      if (typeof value === 'string' && value.length > 0) {
        return { url: value, coverURL: coverURL };
      }
      if (value !== undefined && value !== null && typeof value === 'object') {
        const nestedURL = (value as JsonObject)['url'];
        if (typeof nestedURL === 'string' && nestedURL.length > 0) {
          return { url: nestedURL, coverURL: coverURL };
        }
      }
    }
    return null;
  }

  private static deepVideoOutput(value: Object): VideoOutput | null {
    if (Array.isArray(value)) {
      const values = value as Object[];
      for (const item of values) {
        if (item !== null && typeof item === 'object') {
          const found = GatewayClient.deepVideoOutput(item);
          if (found !== null) {
            return found;
          }
        } else if (typeof item === 'string' && GatewayClient.isVideoURL(item)) {
          return { url: item, coverURL: null };
        }
      }
      return null;
    }

    if (value === null || typeof value !== 'object') {
      return typeof value === 'string' && GatewayClient.isVideoURL(value) ? { url: value, coverURL: null } : null;
    }

    const object = value as JsonObject;
    const direct = GatewayClient.videoOutputInItem(object);
    if (direct !== null && GatewayClient.isVideoURL(direct.url)) {
      return direct;
    }

    let coverURL: string | null = null;
    for (const coverKey of ['cover_image_url', 'coverImageUrl', 'cover_url']) {
      const coverValue = object[coverKey];
      if (typeof coverValue === 'string' && coverValue.length > 0) {
        coverURL = coverValue;
        break;
      }
    }

    for (const key of Object.keys(object)) {
      const child = object[key];
      if (typeof child === 'string' && GatewayClient.isVideoURL(child)) {
        return { url: child, coverURL: coverURL };
      }
      if (child !== undefined && child !== null && typeof child === 'object') {
        const found = GatewayClient.deepVideoOutput(child);
        if (found !== null) {
          return coverURL !== null && found.coverURL === null ? { url: found.url, coverURL: coverURL } : found;
        }
      }
    }
    return null;
  }

  private static isVideoURL(value: string): boolean {
    const lower = value.toLowerCase();
    return lower.startsWith('http') &&
      (lower.includes('.mp4') || lower.includes('.mov') || lower.includes('.m4v') ||
        lower.includes('.webm') || lower.includes('.m3u8') || lower.includes('video'));
  }

  private static videoMessage(prompt: string, taskID: string | null, output: VideoOutput): string {
    const lines = ['已为你生成视频。', '', `提示词：${prompt}`];
    if (taskID !== null) {
      lines.push('', `任务ID：${taskID}`);
    }
    if (output.coverURL !== null) {
      lines.push('', `视频封面: ${output.coverURL}`);
    }
    lines.push('', `视频链接1: ${output.url}`);
    return lines.join('\n');
  }

  private static imageMessage(prompt: string, url: string): string {
    return `已为你生成图片。\n\n提示词：${prompt}\n\n图片链接1: ${url}`;
  }

  private static delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(resolve, milliseconds);
    });
  }
}
