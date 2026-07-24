import { speechRecognizer } from '@kit.CoreSpeechKit';
import { audio } from '@kit.AudioKit';

export interface AvatarRecognitionCallbacks {
  onResult: (text: string, isFinal: boolean) => void;
  onState: (listening: boolean) => void;
  onError: (message: string) => void;
}

export class AvatarRecognitionService {
  private engine?: speechRecognizer.SpeechRecognitionEngine;
  private capturer?: audio.AudioCapturer;
  private sessionId: string = '';
  private listening: boolean = false;

  async start(callbacks: AvatarRecognitionCallbacks): Promise<void> {
    if (this.listening) {
      await this.stop();
      return;
    }
    this.sessionId = `avatar-asr-${Date.now()}`;
    try {
      this.engine = await speechRecognizer.createEngine({
        language: 'zh-CN',
        online: 1,
        extraParams: { 'locate': 'CN', 'recognizerMode': 'short' }
      });
      this.engine.setListener({
        onStart: (): void => {
          this.listening = true;
          callbacks.onState(true);
        },
        onEvent: (): void => {},
        onResult: (_sessionId: string, result: speechRecognizer.SpeechRecognitionResult): void => {
          callbacks.onResult(result.result, result.isFinal || result.isLast);
          if (result.isLast) this.stop();
        },
        onComplete: (): void => {
          this.cleanup(callbacks);
        },
        onError: (_sessionId: string, errorCode: number, errorMessage: string): void => {
          callbacks.onError(`${errorMessage}（${errorCode}）`);
          this.cleanup(callbacks);
        }
      });
      this.capturer = await audio.createAudioCapturer({
        streamInfo: {
          samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
          channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
          encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        },
        capturerInfo: {
          source: audio.SourceType.SOURCE_TYPE_VOICE_MESSAGE,
          capturerFlags: 0
        }
      });
      this.capturer.on('readData', (buffer: ArrayBuffer): void => {
        if (!this.listening || this.engine === undefined) return;
        const source = new Uint8Array(buffer);
        for (let offset = 0; offset + 640 <= source.length; offset += 640) {
          this.engine.writeAudio(this.sessionId, source.slice(offset, offset + 640));
        }
      });
      this.engine.startListening({
        sessionId: this.sessionId,
        audioInfo: { audioType: 'pcm', sampleRate: 16000, soundChannel: 1, sampleBit: 16 },
        extraParams: { 'recognitionMode': 1, 'vadBegin': 4000, 'vadEnd': 1200, 'maxAudioDuration': 60000 }
      });
      this.listening = true;
      callbacks.onState(true);
      await this.capturer.start();
    } catch (error) {
      callbacks.onError((error as Error).message ?? `${error}`);
      await this.cleanup(callbacks);
    }
  }

  async stop(): Promise<void> {
    if (this.engine !== undefined && this.sessionId.length > 0) {
      try {
        this.engine.finish(this.sessionId);
      } catch (_) {}
    }
    if (this.capturer !== undefined) {
      try {
        await this.capturer.stop();
      } catch (_) {}
      try {
        await this.capturer.release();
      } catch (_) {}
    }
    this.capturer = undefined;
    this.listening = false;
  }

  private async cleanup(callbacks: AvatarRecognitionCallbacks): Promise<void> {
    await this.stop();
    if (this.engine !== undefined) {
      try {
        this.engine.shutdown();
      } catch (_) {}
    }
    this.engine = undefined;
    callbacks.onState(false);
  }
}
