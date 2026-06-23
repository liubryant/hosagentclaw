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

/**
 * 对应 iOS GatewayClient.swift。
 */
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
}
