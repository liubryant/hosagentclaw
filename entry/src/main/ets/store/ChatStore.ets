/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import {
  ChatEntryMode,
  ChatHistorySnapshot,
  ChatMessage,
  ChatRole,
  GeneratedDocument,
  LocalChatSession,
  newId
} from '../model/ChatModels';
import { AppPreferences } from '../storage/AppPreferences';
import { GatewayClient } from '../gateway/GatewayClient';
import { GeneratedDocumentStore } from './GeneratedDocumentStore';

const DOCUMENT_GENERATION_INSTRUCTION = `你正在为鸿蒙客户端生成可导出的文档文件。
当用户要求生成文档、报告、文章、Markdown、HTML、README 或文件时，必须把最终文件内容放进代码块，不要只在聊天里输出正文。
如果用户没有指定格式，默认生成 HTML。
文件内容控制在适合手机预览的长度，优先完整、简洁、可打开，不要输出超长正文。
格式必须是：
\`\`\`file path="文件名.html"
<!doctype html>
...
\`\`\`
或：
\`\`\`file path="文件名.md"
# Markdown 内容
\`\`\`
代码块外只保留一句简短说明。`;

const AGENT_STATUS_MESSAGES: string[] = [
  '正在调用search工具...',
  '正在联网搜索...',
  '调用knowledge工具中...',
  '执行工具中...',
  '正在执行...',
  '分析数据中...',
  '整理结果中...',
];

const DOCUMENT_KEYWORDS = [
  '文档', '报告', '简报', '文章', '文件', '导出',
  'html', 'markdown', '.md', 'md文件', 'readme',
  'document', 'report', 'file'
];

@ObservedV2
export class ChatStore {
  @Trace sessions: LocalChatSession[] = [];
  @Trace selectedSessionID: string = '';
  @Trace messages: ChatMessage[] = [];
  @Trace draft: string = '';
  @Trace isSending: boolean = false;
  @Trace generationStatus: string = '';
  @Trace errorMessage: string | null = null;
  @Trace attachedImageBase64: string | null = null;
  @Trace currentEntryMode: ChatEntryMode = ChatEntryMode.DEFAULT;

  private statusTimer: number = -1;
  private statusMsgIndex: number = 0;
  private messagesBySession: Record<string, ChatMessage[]> = {};
  private entryModesBySession: Record<string, ChatEntryMode> = {};

  constructor() {
    const snapshot = AppPreferences.shared.chatHistorySnapshot;
    if (snapshot !== null && snapshot.sessions.length > 0) {
      this.sessions = snapshot.sessions;
      const hasSelected = snapshot.sessions.some(item => item.id === snapshot.selectedSessionID);
      this.selectedSessionID = hasSelected ? snapshot.selectedSessionID : snapshot.sessions[0].id;
      this.messagesBySession = snapshot.messagesBySession;
      this.entryModesBySession = snapshot.entryModesBySession;
      snapshot.sessions.forEach(session => {
        if (this.messagesBySession[session.id] === undefined) {
          this.messagesBySession[session.id] = [];
        }
        if (this.entryModesBySession[session.id] === undefined) {
          this.entryModesBySession[session.id] = ChatEntryMode.DEFAULT;
        }
      });
      this.messages = this.messagesBySession[this.selectedSessionID] ?? [];
      this.currentEntryMode = this.entryModesBySession[this.selectedSessionID] ?? ChatEntryMode.DEFAULT;
    } else {
      const initialSession = new LocalChatSession();
      this.sessions = [initialSession];
      this.selectedSessionID = initialSession.id;
      this.messagesBySession[initialSession.id] = [];
      this.entryModesBySession[initialSession.id] = ChatEntryMode.DEFAULT;
      this.messages = [];
      this.saveHistory();
    }
  }

  get allDocuments(): GeneratedDocument[] {
    const all: GeneratedDocument[] = [];
    Object.keys(this.messagesBySession).forEach(sessionId => {
      this.messagesBySession[sessionId].forEach(message => {
        message.generatedDocuments.forEach(doc => all.push(doc));
      });
    });
    return all;
  }

  get selectedSession(): LocalChatSession | null {
    const found = this.sessions.find(item => item.id === this.selectedSessionID);
    return found === undefined ? null : found;
  }

  get selectedEntryMode(): ChatEntryMode {
    return this.currentEntryMode;
  }

  createSession(entryMode: ChatEntryMode = ChatEntryMode.DEFAULT): void {
    const session = new LocalChatSession();
    this.sessions = [session, ...this.sessions];
    this.selectedSessionID = session.id;
    this.messagesBySession[session.id] = [];
    this.entryModesBySession[session.id] = entryMode;
    this.currentEntryMode = entryMode;
    this.messages = [];
    this.draft = '';
    this.attachedImageBase64 = null;
    this.errorMessage = null;
    this.saveHistory();
  }

  /**
   * 清除当前会话的入口模式（恢复为 DEFAULT）并清除图片附件。
   * 用于热点话题卡片点击时先重置模式再填入 prompt。
   */
  resetToDefaultMode(): void {
    if (this.selectedSessionID.length > 0) {
      this.entryModesBySession[this.selectedSessionID] = ChatEntryMode.DEFAULT;
    }
    this.currentEntryMode = ChatEntryMode.DEFAULT;
    this.attachedImageBase64 = null;
    this.saveHistory();
  }

  updateEntryMode(mode: ChatEntryMode): void {
    if (this.selectedSessionID.length > 0) {
      this.entryModesBySession[this.selectedSessionID] = mode;
    }
    this.currentEntryMode = mode;
  }

  createSessionWithDraft(draftText: string, entryMode: ChatEntryMode = ChatEntryMode.DEFAULT): void {
    this.createSession(entryMode);
    this.draft = draftText;
  }

  selectSession(session: LocalChatSession): void {
    this.selectedSessionID = session.id;
    this.messages = this.messagesBySession[session.id] ?? [];
    this.currentEntryMode = this.entryModesBySession[session.id] ?? ChatEntryMode.DEFAULT;
    this.draft = '';
    this.errorMessage = null;
    this.saveHistory();
  }

  deleteSession(session: LocalChatSession): void {
    if (this.sessions.length <= 1) {
      this.messagesBySession[session.id] = [];
      this.messages = [];
      this.saveHistory();
      return;
    }

    this.sessions = this.sessions.filter(item => item.id !== session.id);
    this.messagesBySession = ChatStore.omitKey(this.messagesBySession, session.id);
    this.entryModesBySession = ChatStore.omitKey(this.entryModesBySession, session.id);
    if (this.selectedSessionID === session.id) {
      this.selectedSessionID = this.sessions[0].id;
      this.messages = this.messagesBySession[this.selectedSessionID] ?? [];
    }
    this.saveHistory();
  }

  send(): void {
    const text = this.draft.trim();
    const hasAttachment = this.attachedImageBase64 !== null;
    if ((text.length === 0 && !hasAttachment) || this.isSending) {
      return;
    }

    this.draft = '';
    this.errorMessage = null;
    // Capture and clear image before building messages
    const imageBase64 = this.attachedImageBase64;
    this.attachedImageBase64 = null;

    const userMessage = new ChatMessage();
    userMessage.id = newId();
    userMessage.role = ChatRole.USER;
    userMessage.content = text;
    this.append(userMessage);
    this.updateSelectedSessionTitleIfNeeded(text.length > 0 ? text : '（图片）');
    this.saveHistory();
    const entryMode = this.selectedEntryMode;
    this.isSending = true;
    if (entryMode === ChatEntryMode.VIDEO) {
      this.generationStatus = '正在提交视频生成任务…';
    } else if (entryMode === ChatEntryMode.IMAGE || imageBase64 !== null) {
      this.generationStatus = '正在生成图片...';
    } else {
      this.startStatusCycling();
    }

    const sessionIdAtSend = this.selectedSessionID;
    const requestMessages = (this.messagesBySession[sessionIdAtSend] ?? []).map((message): ChatMessage => {
      if (message.id !== userMessage.id) {
        return message;
      }
      const outbound = ChatMessage.fromPlain(message);
      outbound.content = this.outboundContent(text, entryMode, imageBase64);
      return outbound;
    });

    const generation = entryMode === ChatEntryMode.VIDEO && imageBase64 === null
      ? GatewayClient.shared.generateVideo(text, (status: string) => {
        this.generationStatus = status;
      })
      : GatewayClient.shared.sendChat(requestMessages);

    generation
      .then((reply: string) => {
        const fallbackTitle = this.selectedSession?.title ?? 'document';
        const saveResult = GeneratedDocumentStore.shared.saveGeneratedDocuments(reply, fallbackTitle);
        const assistantMessage = new ChatMessage();
        assistantMessage.id = newId();
        assistantMessage.role = ChatRole.ASSISTANT;
        assistantMessage.content = saveResult.displayContent;
        assistantMessage.generatedDocuments = saveResult.documents;
        this.appendToSession(sessionIdAtSend, assistantMessage);
      })
      .catch((error: Error) => {
        this.errorMessage = error.message;
      })
      .finally(() => {
        this.isSending = false;
        this.stopStatusCycling();
      });
  }

  private startStatusCycling(): void {
    this.stopStatusCycling();
    this.statusMsgIndex = 0;
    this.generationStatus = AGENT_STATUS_MESSAGES[0];
    this.statusTimer = setInterval(() => {
      this.statusMsgIndex = (this.statusMsgIndex + 1) % AGENT_STATUS_MESSAGES.length;
      this.generationStatus = AGENT_STATUS_MESSAGES[this.statusMsgIndex];
    }, 3000) as number;
  }

  private stopStatusCycling(): void {
    if (this.statusTimer >= 0) {
      clearInterval(this.statusTimer);
      this.statusTimer = -1;
    }
    this.generationStatus = '';
  }

  clearAllData(): void {
    const initialSession = new LocalChatSession();
    this.sessions = [initialSession];
    this.selectedSessionID = initialSession.id;
    const messagesBySession: Record<string, ChatMessage[]> = {};
    messagesBySession[initialSession.id] = [];
    this.messagesBySession = messagesBySession;
    const entryModesBySession: Record<string, ChatEntryMode> = {};
    entryModesBySession[initialSession.id] = ChatEntryMode.DEFAULT;
    this.entryModesBySession = entryModesBySession;
    this.messages = [];
    this.draft = '';
    this.errorMessage = null;
    AppPreferences.shared.chatHistorySnapshot = null;
  }

  private outboundContent(text: string, entryMode: ChatEntryMode, imageBase64: string | null = null): string {
    // Always route to image API when an image is attached, regardless of entry mode
    if (imageBase64 !== null) {
      const imageDataUri = `data:image/jpeg;base64,${imageBase64}`;
      return `[[IMAGE_MODE]] ${imageDataUri}\n${text}`;
    }
    if (entryMode === ChatEntryMode.IMAGE) {
      return `[[IMAGE_MODE]] ${text}`;
    }
    if (entryMode === ChatEntryMode.VIDEO) {
      return `[[VIDEO_MODE]] ${text}`;
    }
    if (this.shouldRequestDocumentFile(text)) {
      return `[[DOCUMENT_MODE]] ${DOCUMENT_GENERATION_INSTRUCTION}\n\n用户需求：${text}`;
    }
    return text;
  }

  private shouldRequestDocumentFile(text: string): boolean {
    const lower = text.toLowerCase();
    return DOCUMENT_KEYWORDS.some(keyword => lower.includes(keyword));
  }

  private append(message: ChatMessage): void {
    this.appendToSession(this.selectedSessionID, message);
  }

  private appendToSession(sessionId: string, message: ChatMessage): void {
    const next = [...(this.messagesBySession[sessionId] ?? []), message];
    this.messagesBySession[sessionId] = next;
    if (sessionId === this.selectedSessionID) {
      this.messages = next;
    }
    this.touchSession(sessionId);
    this.saveHistory();
  }

  private updateSelectedSessionTitleIfNeeded(text: string): void {
    const index = this.sessions.findIndex(item => item.id === this.selectedSessionID);
    if (index < 0) {
      return;
    }
    const nextSessions = [...this.sessions];
    if (nextSessions[index].title === '新对话') {
      nextSessions[index].title = text.length > 18 ? `${text.substring(0, 18)}...` : text;
    }
    nextSessions[index].updatedAt = Date.now();
    this.sessions = nextSessions;
  }

  private touchSession(sessionId: string): void {
    const index = this.sessions.findIndex(item => item.id === sessionId);
    if (index < 0) {
      return;
    }
    const nextSessions = [...this.sessions];
    nextSessions[index].updatedAt = Date.now();
    nextSessions.sort((a, b) => b.updatedAt - a.updatedAt);
    this.sessions = nextSessions;
  }

  private saveHistory(): void {
    const snapshot = new ChatHistorySnapshot();
    snapshot.sessions = this.sessions;
    snapshot.selectedSessionID = this.selectedSessionID;
    snapshot.messagesBySession = this.messagesBySession;
    snapshot.entryModesBySession = this.entryModesBySession;
    AppPreferences.shared.chatHistorySnapshot = snapshot;
  }

  private static omitKey<T>(record: Record<string, T>, key: string): Record<string, T> {
    const next: Record<string, T> = {};
    Object.keys(record).forEach(existingKey => {
      if (existingKey !== key) {
        next[existingKey] = record[existingKey];
      }
    });
    return next;
  }
}
