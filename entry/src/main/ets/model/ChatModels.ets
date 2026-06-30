/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { util } from '@kit.ArkTS';

export enum ChatRole {
  SYSTEM = 'system',
  USER = 'user',
  ASSISTANT = 'assistant',
  TOOL = 'tool'
}

export enum ChatEntryMode {
  DEFAULT = 'default',
  IMAGE = 'image',
  VIDEO = 'video'
}

export function newId(): string {
  return util.generateRandomUUID();
}

export class GeneratedDocument {
  id: string = newId();
  displayName: string = '';
  relativePath: string = '';
  mimeType: string = '';
  createdAt: number = Date.now();

  static fromPlain(plain: GeneratedDocument): GeneratedDocument {
    const doc = new GeneratedDocument();
    doc.id = plain.id;
    doc.displayName = plain.displayName;
    doc.relativePath = plain.relativePath;
    doc.mimeType = plain.mimeType;
    doc.createdAt = plain.createdAt;
    return doc;
  }
}

export class ChatMessage {
  id: string = newId();
  role: ChatRole = ChatRole.USER;
  content: string = '';
  createdAt: number = Date.now();
  generatedDocuments: GeneratedDocument[] = [];

  static fromPlain(plain: ChatMessage): ChatMessage {
    const message = new ChatMessage();
    message.id = plain.id;
    message.role = plain.role;
    message.content = plain.content;
    message.createdAt = plain.createdAt;
    message.generatedDocuments = (plain.generatedDocuments ?? []).map(item => GeneratedDocument.fromPlain(item));
    return message;
  }
}

export class LocalChatSession {
  id: string = newId();
  title: string = '新对话';
  updatedAt: number = Date.now();

  static fromPlain(plain: LocalChatSession): LocalChatSession {
    const session = new LocalChatSession();
    session.id = plain.id;
    session.title = plain.title;
    session.updatedAt = plain.updatedAt;
    return session;
  }
}

export class ChatHistorySnapshot {
  sessions: LocalChatSession[] = [];
  selectedSessionID: string = '';
  messagesBySession: Record<string, ChatMessage[]> = {};
  entryModesBySession: Record<string, ChatEntryMode> = {};
}

export interface ChatCompletionRequestMessage {
  role: string;
  content: string;
}

export interface ChatCompletionRequest {
  model: string;
  stream: boolean;
  responseMode?: string;
  messages: ChatCompletionRequestMessage[];
}

export interface ChatCompletionResponseMessage {
  role?: string;
  content?: string;
}

export interface ChatCompletionResponseChoice {
  message?: ChatCompletionResponseMessage;
}

export interface ChatCompletionResponse {
  choices?: ChatCompletionResponseChoice[];
}

export function firstContentOf(response: ChatCompletionResponse): string {
  if (response.choices === undefined || response.choices.length === 0) {
    return '';
  }
  const message = response.choices[0].message;
  if (message === undefined || message.content === undefined) {
    return '';
  }
  return message.content;
}
