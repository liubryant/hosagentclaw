/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { GeneratedDocument, newId } from '../model/ChatModels';

export class GeneratedDocumentSaveResult {
  displayContent: string;
  documents: GeneratedDocument[];

  constructor(displayContent: string, documents: GeneratedDocument[]) {
    this.displayContent = displayContent;
    this.documents = documents;
  }
}

interface FileBlock {
  language: string;
  fileName: string | null;
  content: string;
}

const FILE_BLOCK_PATTERN = /```([A-Za-z0-9_-]+)([^\n`]*)\n([\s\S]*?)```/g;
const REMOVABLE_BLOCK_PATTERN = /```(?:file|html|md|markdown|txt|text)[^\n`]*\n[\s\S]*?```/gi;
const SAVED_LANGUAGES = ['file', 'html', 'md', 'markdown', 'txt', 'text'];
const TEXTUAL_LANGUAGES = ['html', 'md', 'markdown', 'txt', 'text'];

export class GeneratedDocumentStore {
  private static instance: GeneratedDocumentStore | null = null;
  private context: common.UIAbilityContext | null = null;

  private constructor() {
  }

  static get shared(): GeneratedDocumentStore {
    if (GeneratedDocumentStore.instance === null) {
      GeneratedDocumentStore.instance = new GeneratedDocumentStore();
    }
    return GeneratedDocumentStore.instance;
  }

  init(context: common.UIAbilityContext): void {
    this.context = context;
  }

  private get exportsDirectory(): string {
    if (this.context === null) {
      throw new Error('GeneratedDocumentStore.init(context) 尚未调用');
    }
    return `${this.context.filesDir}/Agent/Exports`;
  }

  fileURL(document: GeneratedDocument): string {
    return `${this.exportsDirectory}/${document.relativePath}`;
  }

  async saveNetworkMedia(url: string, defaultPrefix: string, fallbackMimeType: string): Promise<GeneratedDocument> {
    this.createExportsDirectoryIfNeeded();
    const fileName = this.generatedFileName(url, defaultPrefix, fallbackMimeType);
    const finalPath = this.uniquePath(fileName);
    const request = http.createHttp();
    let buffer: ArrayBuffer;
    try {
      const response = await request.request(url, { expectDataType: http.HttpDataType.ARRAY_BUFFER });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`下载失败：HTTP ${response.responseCode}`);
      }
      buffer = response.result as ArrayBuffer;
    } finally {
      request.destroy();
    }

    const file = fileIo.openSync(finalPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, buffer);
    } finally {
      fileIo.closeSync(file);
    }

    const document = new GeneratedDocument();
    document.id = newId();
    document.displayName = this.lastPathComponent(finalPath);
    document.relativePath = this.lastPathComponent(finalPath);
    document.mimeType = this.mimeType(this.fileExtension(finalPath), fallbackMimeType);
    document.createdAt = Date.now();
    return document;
  }

  saveGeneratedDocuments(assistantContent: string, fallbackTitle: string): GeneratedDocumentSaveResult {
    const blocks = this.parseFileBlocks(assistantContent);
    if (blocks.length === 0) {
      return new GeneratedDocumentSaveResult(assistantContent, []);
    }

    this.createExportsDirectoryIfNeeded();
    const saved: GeneratedDocument[] = [];
    blocks.forEach(block => {
      const fileName = this.sanitizedFileName(block.fileName, fallbackTitle, block.language);
      const finalPath = this.uniquePath(fileName);
      try {
        const file = fileIo.openSync(finalPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
        fileIo.writeSync(file.fd, block.content);
        fileIo.closeSync(file);
        const document = new GeneratedDocument();
        document.id = newId();
        document.displayName = this.lastPathComponent(finalPath);
        document.relativePath = this.lastPathComponent(finalPath);
        document.mimeType = this.mimeType(this.fileExtension(finalPath));
        document.createdAt = Date.now();
        saved.push(document);
      } catch (e) {
        // 单个文件写入失败时跳过，不阻塞整体回复展示。
      }
    });

    const display = this.removeFileBlocks(assistantContent).trim();
    const fallbackDisplay = saved.length === 0 ? assistantContent : `已生成 ${saved.length} 个文件。`;
    return new GeneratedDocumentSaveResult(display.length === 0 ? fallbackDisplay : display, saved);
  }

  private parseFileBlocks(text: string): FileBlock[] {
    const blocks: FileBlock[] = [];
    const regex = new RegExp(FILE_BLOCK_PATTERN);
    let match: RegExpExecArray | null;
    while ((match = regex.exec(text)) !== null) {
      const language = match[1].toLowerCase();
      if (!SAVED_LANGUAGES.includes(language)) {
        continue;
      }
      const meta = match[2];
      const content = match[3].replace(/^\n+|\n+$/g, '');
      const fileName = this.extractFileName(meta);
      if (fileName === null && !TEXTUAL_LANGUAGES.includes(language)) {
        continue;
      }
      blocks.push({ language, fileName, content });
    }
    return blocks;
  }

  private removeFileBlocks(text: string): string {
    return text.replace(new RegExp(REMOVABLE_BLOCK_PATTERN), '');
  }

  private extractFileName(metadata: string): string | null {
    const patterns = [
      /path\s*=\s*"([^"]+)"/,
      /filename\s*=\s*"([^"]+)"/,
      /file\s*=\s*"([^"]+)"/,
      /path\s*=\s*(\S+)/,
      /filename\s*=\s*(\S+)/
    ];
    for (const pattern of patterns) {
      const match = pattern.exec(metadata);
      if (match !== null && match.length > 1) {
        return match[1];
      }
    }
    return null;
  }

  private sanitizedFileName(proposed: string | null, fallbackTitle: string, language: string): string {
    let raw: string;
    if (proposed !== null) {
      const parts = proposed.split('/');
      raw = parts[parts.length - 1];
    } else {
      raw = `${fallbackTitle}-${this.timestamp()}.${this.defaultExtension(language)}`;
    }
    const cleaned = raw.replace(/[\\/:*?"<>|]/g, '_').trim();
    const fallback = `document-${this.timestamp()}.${this.defaultExtension(language)}`;
    const named = cleaned.length === 0 ? fallback : cleaned;
    return named.includes('.') ? named : `${named}.${this.defaultExtension(language)}`;
  }

  private uniquePath(fileName: string): string {
    const base = `${this.exportsDirectory}/${fileName}`;
    if (!fileIo.accessSync(base)) {
      return base;
    }
    const dotIndex = fileName.lastIndexOf('.');
    const name = dotIndex >= 0 ? fileName.substring(0, dotIndex) : fileName;
    const ext = dotIndex >= 0 ? fileName.substring(dotIndex + 1) : '';
    let index = 2;
    while (true) {
      const candidateName = ext.length === 0 ? `${name}-${index}` : `${name}-${index}.${ext}`;
      const candidate = `${this.exportsDirectory}/${candidateName}`;
      if (!fileIo.accessSync(candidate)) {
        return candidate;
      }
      index += 1;
    }
  }

  private createExportsDirectoryIfNeeded(): void {
    if (!fileIo.accessSync(this.exportsDirectory)) {
      fileIo.mkdirSync(this.exportsDirectory, true);
    }
  }

  private defaultExtension(language: string): string {
    if (language === 'html') {
      return 'html';
    }
    if (language === 'md' || language === 'markdown') {
      return 'md';
    }
    return 'txt';
  }

  private generatedFileName(url: string, defaultPrefix: string, fallbackMimeType: string): string {
    const cleanURL = url.split('?')[0].split('#')[0];
    const parts = cleanURL.split('/');
    const rawName = decodeURIComponent(parts[parts.length - 1] ?? '').replace(/[\\/:*?"<>|]/g, '_').trim();
    if (rawName.length > 0 && rawName.includes('.')) {
      return rawName;
    }
    const hash = this.simpleHash(url);
    const base = rawName.length > 0 ? rawName : defaultPrefix;
    return `${base}-${hash}.${this.extensionForMimeType(fallbackMimeType)}`;
  }

  private extensionForMimeType(mimeType: string): string {
    const lower = mimeType.toLowerCase();
    if (lower === 'image/jpeg' || lower === 'image/jpg') {
      return 'jpg';
    }
    if (lower === 'image/webp') {
      return 'webp';
    }
    if (lower === 'image/gif') {
      return 'gif';
    }
    if (lower === 'video/mp4') {
      return 'mp4';
    }
    if (lower === 'video/quicktime') {
      return 'mov';
    }
    if (lower === 'video/webm') {
      return 'webm';
    }
    return lower.startsWith('video/') ? 'mp4' : 'png';
  }

  private mimeType(ext: string, fallback: string = 'application/octet-stream'): string {
    const lower = ext.toLowerCase();
    if (lower === 'png') {
      return 'image/png';
    }
    if (lower === 'jpg' || lower === 'jpeg') {
      return 'image/jpeg';
    }
    if (lower === 'webp') {
      return 'image/webp';
    }
    if (lower === 'gif') {
      return 'image/gif';
    }
    if (lower === 'mp4') {
      return 'video/mp4';
    }
    if (lower === 'mov') {
      return 'video/quicktime';
    }
    if (lower === 'webm') {
      return 'video/webm';
    }
    if (lower === 'html' || lower === 'htm') {
      return 'text/html';
    }
    if (lower === 'md' || lower === 'markdown') {
      return 'text/markdown';
    }
    if (lower === 'txt') {
      return 'text/plain';
    }
    return fallback;
  }

  private simpleHash(text: string): string {
    let hash = 0;
    for (let index = 0; index < text.length; index += 1) {
      hash = ((hash << 5) - hash + text.charCodeAt(index)) | 0;
    }
    return Math.abs(hash).toString(16);
  }

  private lastPathComponent(path: string): string {
    const parts = path.split('/');
    return parts[parts.length - 1];
  }

  private fileExtension(path: string): string {
    const name = this.lastPathComponent(path);
    const dotIndex = name.lastIndexOf('.');
    return dotIndex >= 0 ? name.substring(dotIndex + 1) : '';
  }

  private timestamp(): string {
    const now = new Date();
    const pad = (value: number): string => value < 10 ? `0${value}` : `${value}`;
    return `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
  }
}
