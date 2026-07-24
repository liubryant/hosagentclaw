import { textToSpeech } from '@kit.CoreSpeechKit';

export interface AvatarSpeechCallbacks {
  onStart: () => void;
  onAudioData?: (audio: ArrayBuffer, audioType: string, sequence: number) => void;
  onComplete: () => void;
  onError: (message: string) => void;
}

export type AvatarSpeechStateListener = (speaking: boolean) => void;

export class AvatarSpeechService {
  private static instance: AvatarSpeechService | null = null;
  private engine: textToSpeech.TextToSpeechEngine | null = null;
  private creating: Promise<textToSpeech.TextToSpeechEngine> | null = null;
  private callbacks: AvatarSpeechCallbacks | null = null;
  private playbackGeneration: number = 0;
  private completedGeneration: number = -1;
  private speaking: boolean = false;
  private stateListeners: Set<AvatarSpeechStateListener> = new Set<AvatarSpeechStateListener>();

  static get shared(): AvatarSpeechService {
    if (AvatarSpeechService.instance === null) {
      AvatarSpeechService.instance = new AvatarSpeechService();
    }
    return AvatarSpeechService.instance;
  }

  get isSpeaking(): boolean {
    return this.speaking;
  }

  addStateListener(listener: AvatarSpeechStateListener): void {
    this.stateListeners.add(listener);
    listener(this.speaking);
  }

  removeStateListener(listener: AvatarSpeechStateListener): void {
    this.stateListeners.delete(listener);
  }

  private setSpeaking(value: boolean): void {
    this.speaking = value;
    this.stateListeners.forEach((listener: AvatarSpeechStateListener): void => listener(value));
  }

  private async ensureEngine(): Promise<textToSpeech.TextToSpeechEngine> {
    if (this.engine !== null) return this.engine;
    if (this.creating !== null) return this.creating;
    this.creating = this.createEngine();
    try {
      this.engine = await this.creating;
      return this.engine;
    } finally {
      this.creating = null;
    }
  }

  private async createEngine(): Promise<textToSpeech.TextToSpeechEngine> {
    const person = 0;
    // Online CoreSpeechKit is restricted to system applications on current
    // devices (error 1002300005). Third-party apps use the installed offline
    // TTS ability. Do not call listVoices: that API is restricted as well.
    const online = 1;
    const engine = await textToSpeech.createEngine({
      language: 'zh-CN',
      person: person,
      online: online
    });
    const listener: textToSpeech.SpeakListener = {
      onStart: (_requestId: string, _response: textToSpeech.StartResponse): void => {
        console.info(`avatar_tts onStart request=${_requestId} type=${_response.audioType} rate=${_response.sampleRate} bit=${_response.sampleBit}`);
        this.setSpeaking(true);
        this.callbacks?.onStart();
      },
      onData: (_requestId: string, audio: ArrayBuffer, response: textToSpeech.SynthesisResponse): void => {
        // The TTS engine performs playback. The returned PCM is forwarded only
        // to Tuanjie for lip sync, avoiding a second renderer and silent streams.
        this.callbacks?.onAudioData?.(audio, response.audioType, response.sequence);
      },
      onComplete: (_requestId: string, _response: textToSpeech.CompleteResponse): void => {
        console.info(`avatar_tts onComplete request=${_requestId} type=${_response.type}`);
        const generation = this.playbackGeneration;
        // type 0 is synthesis completion; type 1 is audible playback completion.
        if (_response.type !== 1 || generation !== this.playbackGeneration ||
          this.completedGeneration === generation) return;
        this.completedGeneration = generation;
        this.setSpeaking(false);
        this.callbacks?.onComplete();
      },
      onStop: (_requestId: string, _response: textToSpeech.StopResponse): void => {
        this.setSpeaking(false);
        this.callbacks?.onComplete();
      },
      onError: (_requestId: string, errorCode: number, errorMessage: string): void => {
        console.error(`avatar_tts onError request=${_requestId} code=${errorCode} message=${errorMessage}`);
        this.setSpeaking(false);
        this.callbacks?.onError(`${errorMessage}（${errorCode}）`);
      }
    };
    engine.setListener(listener);
    console.info(`avatar_tts ready person=${person}`);
    return engine;
  }

  async speak(text: string, callbacks: AvatarSpeechCallbacks): Promise<void> {
    this.stop();
    this.playbackGeneration += 1;
    this.completedGeneration = -1;
    this.callbacks = callbacks;
    this.setSpeaking(true);
    const engine = await this.ensureEngine();
    console.info(`avatar_tts speak chars=${text.length}`);
    engine.speak(text.substring(0, 10000), { requestId: `avatar-${Date.now()}` });
  }

  stop(): void {
    this.playbackGeneration += 1;
    this.setSpeaking(false);
    try {
      if (this.engine?.isBusy()) this.engine.stop();
    } catch (error) {
      console.warn(`avatar_tts stop_failed=${JSON.stringify(error)}`);
    }
  }
}
