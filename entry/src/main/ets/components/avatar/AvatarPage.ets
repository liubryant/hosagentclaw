import { pasteboard } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { inputMethod } from '@kit.IMEKit';
import { Tuanjie, TuanjiePlayerView } from 'tuanjieLib';
import { GatewayClient } from '../../gateway/GatewayClient';
import { ChatMessage, ChatRole, newId } from '../../model/ChatModels';
import { AppPreferences } from '../../storage/AppPreferences';
import { PaymentApi } from '../../pay/PaymentApi';
import { AvatarSpeechService, AvatarSpeechStateListener } from './AvatarSpeechService';
import { AvatarRecognitionService } from './AvatarRecognitionService';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';

const TUANJIE_LOG: string = 'tuanjiehub';
const FREE_AGENT_QUESTION_LIMIT: number = 3;

class AvatarTurn {
  id: string = newId();
  role: ChatRole = ChatRole.USER;
  content: string = '';
  createdAt: number = Date.now();
}

interface AvatarCommandPayload {
  type: string;
  value: string;
  requestId: string;
  loop: boolean;
}

const GREETINGS: string[] = [
  '你好呀，我是你的智能体助手 Lily，今天想聊点什么？',
  '嗨，很高兴见到你。你可以直接说话，也可以输入文字。',
  '今天也要保持好心情，有什么事情都可以告诉我。',
  '我已经准备好了，来和我聊聊你的想法吧。'
];

const THINKING_STATUS_MESSAGES: string[] = [
  '正在调用search工具...',
  '正在联网搜索...',
  '调用knowledge工具中...',
  '执行工具中...',
  '正在执行...',
  '分析数据中...',
  '整理结果中...'
];

@Component
export struct AvatarPage {
  onRequireLogin: () => void = () => {};
  onRequireVip: () => void = () => {};
  @State private turns: AvatarTurn[] = [];
  @State private draft: string = '';
  @State private isThinking: boolean = false;
  @State private isSpeaking: boolean = false;
  @State private errorText: string = '';
  @State private waveActive: boolean = false;
  @State private isListening: boolean = false;
  @State private speakingTurnId: string = '';
  @State private highlightedSegmentIndex: number = -1;
  @State private thinkingStatus: string = THINKING_STATUS_MESSAGES[0];
  @State private thinkingStatusOpacity: number = 1;
  @State private thinkingStatusOffset: number = 0;
  @State private waveHeights: number[] = [8, 14, 10, 18, 11, 15, 9];
  @State private displayIndex: number = 0;
  @State private actionTurnId: string = '';
  private requestSerial: number = 0;
  private scroller: Scroller = new Scroller();
  private speechSegmentCenters: Map<string, number> = new Map<string, number>();
  private conversationViewportHeight: number = 0;
  private conversationViewportCenter: number = 0;
  private base64Helper: util.Base64Helper = new util.Base64Helper();
  private speechHighlightTimers: number[] = [];
  private thinkingTimer: number = -1;
  private thinkingStatusIndex: number = 0;
  private waveTimer: number = -1;
  private mouthTimer: number = -1;
  private mouthFrame: number = 0;
  private recognitionGeneration: number = 0;
  private recognitionService: AvatarRecognitionService = new AvatarRecognitionService();
  private accessCheckInFlight: boolean = false;
  private avatarPageVisible: boolean = false;
  private readonly speechStateListener: AvatarSpeechStateListener = (speaking: boolean): void => {
    this.applySpeechVisualState(speaking);
  };

  aboutToAppear(): void {
    console.info(`${TUANJIE_LOG} avatar_page appear displayIndex=${this.displayIndex}`);
    this.avatarPageVisible = true;
    this.restoreConversation();
    AvatarSpeechService.shared.addStateListener(this.speechStateListener);
    this.restoreSpeechVisualState();
    setTimeout((): void => {
      console.info(`${TUANJIE_LOG} avatar_page ready_probe`);
      this.restoreSpeechVisualState();
    }, 800);
    setTimeout((): void => this.restoreSpeechVisualState(), 1800);
  }

  aboutToDisappear(): void {
    console.info(`${TUANJIE_LOG} avatar_page disappear`);
    this.avatarPageVisible = false;
    AvatarSpeechService.shared.removeStateListener(this.speechStateListener);
    // The native XComponent is removed on tab switches, but CoreSpeechKit owns
    // audible playback and must continue. Stop only page-bound work.
    this.recognitionGeneration += 1;
    if (this.isListening) {
      this.isListening = false;
      this.recognitionService.stop().catch((): void => {});
    }
    this.stopThinkingCycling();
    this.stopWaveAnimation();
    this.stopSyntheticLipSync();
    this.clearSpeechHighlight();
  }

  private restoreSpeechVisualState(): void {
    if (!this.avatarPageVisible) return;
    this.applySpeechVisualState(AvatarSpeechService.shared.isSpeaking);
  }

  private applySpeechVisualState(speaking: boolean): void {
    if (!this.avatarPageVisible) return;
    this.isSpeaking = speaking;
    this.waveActive = speaking;
    if (speaking) {
      this.startWaveAnimation();
      this.startSyntheticLipSync();
      this.sendAvatarCommand('state', 'Speaking');
    } else {
      this.sendAvatarCommand('state', 'Idle');
    }
  }

  private restoreConversation(): void {
    const raw = AppPreferences.shared.avatarConversation;
    if (raw.length > 0) {
      try {
        this.turns = JSON.parse(raw) as AvatarTurn[];
      } catch (_) {
        this.turns = [];
      }
    }
    if (this.turns.length === 0) {
      const welcome = new AvatarTurn();
      welcome.role = ChatRole.ASSISTANT;
      welcome.content = '你好，我是你的智能体助手。\n你可以直接说话，也可以输入文字。';
      this.turns = [welcome];
      this.persistConversation();
    }
  }

  private persistConversation(): void {
    AppPreferences.shared.avatarConversation = JSON.stringify(this.turns.slice(-40));
  }

  private sendAvatarCommand(type: string, value: string = '', requestId: string = ''): void {
    const payload: AvatarCommandPayload = { type: type, value: value, requestId: requestId, loop: false };
    try {
      Tuanjie.TuanjieSendMessage('AvatarRuntime', 'ReceiveCommand', JSON.stringify(payload));
      console.info(`${TUANJIE_LOG} bridge_send target=AvatarRuntime method=ReceiveCommand type=${type} value=${value}`);
    } catch (error) {
      console.error(`${TUANJIE_LOG} bridge_error ${JSON.stringify(error)}`);
    }
  }

  private async submit(): Promise<void> {
    const text = this.draft.trim();
    if (text.length === 0 || this.isThinking || this.accessCheckInFlight) return;
    if (!AppPreferences.shared.isLoggedIn) {
      inputMethod.getController().stopInputSession().catch(() => {});
      this.onRequireLogin();
      return;
    }
    inputMethod.getController().stopInputSession().catch(() => {});
    this.accessCheckInFlight = true;
    let isVip: boolean = false;
    try {
      isVip = await this.refreshVipAccess();
    } finally {
      this.accessCheckInFlight = false;
    }
    if (!isVip && AppPreferences.shared.freeAgentQuestionCount >= FREE_AGENT_QUESTION_LIMIT) {
      this.onRequireVip();
      return;
    }
    if (!isVip) {
      AppPreferences.shared.freeAgentQuestionCount = AppPreferences.shared.freeAgentQuestionCount + 1;
    }
    // Invalidate the active ASR callbacks before clearing the input. The
    // recognizer may still deliver its final result after the send tap; that
    // late result must not put the submitted text back into the editor.
    this.recognitionGeneration += 1;
    if (this.isListening) {
      this.isListening = false;
      this.recognitionService.stop().catch(() => {});
    }
    this.draft = '';
    this.errorText = '';
    const user = new AvatarTurn();
    user.role = ChatRole.USER;
    user.content = text;
    this.turns = [...this.turns, user];
    this.persistConversation();
    this.scrollToBottom();

    this.isThinking = true;
    this.waveActive = true;
    this.startThinkingCycling();
    this.startWaveAnimation();
    this.requestSerial += 1;
    const requestId = `${this.requestSerial}`;
    this.sendAvatarCommand('state', 'Thinking', requestId);
    try {
      const messages: ChatMessage[] = [];
      const system = new ChatMessage();
      system.role = ChatRole.SYSTEM;
      system.content = '你是 AgentClaw 的拟人智能体助手 Lily。请使用自然、口语化、简洁的中文回答，内容适合语音播报。';
      messages.push(system);
      this.turns.slice(-12).forEach((turn: AvatarTurn) => {
        const message = new ChatMessage();
        message.role = turn.role;
        message.content = turn.content;
        messages.push(message);
      });
      const result = (await GatewayClient.shared.sendChat(messages)).trim();
      if (requestId !== `${this.requestSerial}`) return;
      const assistant = new AvatarTurn();
      assistant.role = ChatRole.ASSISTANT;
      assistant.content = result.length > 0 ? result : '我暂时没有获取到回答，请再试一次。';
      this.turns = [...this.turns, assistant];
      this.persistConversation();
      this.isThinking = false;
      this.stopThinkingCycling();
      this.scrollToBottom();
      await this.readAloud(assistant.content, requestId, assistant.id);
    } catch (error) {
      if (requestId !== `${this.requestSerial}`) return;
      this.errorText = (error as Error).message || '智能体请求失败，请稍后重试';
      this.isThinking = false;
      this.stopThinkingCycling();
      this.isSpeaking = false;
      this.waveActive = false;
      this.sendAvatarCommand('state', 'Idle', requestId);
    }
  }

  private async refreshVipAccess(): Promise<boolean> {
    const token = AppPreferences.shared.userAccessToken;
    if (token === null || token.length === 0) {
      AppPreferences.shared.vipActive = false;
      return false;
    }
    try {
      const membership = await PaymentApi.shared.getMembership(token);
      AppPreferences.shared.vipActive = membership.active;
      return membership.active;
    } catch (_) {
      return AppPreferences.shared.vipActive;
    }
  }

  private playGreeting(): void {
    console.info(`${TUANJIE_LOG} greeting requested thinking=${this.isThinking} speaking=${this.isSpeaking}`);
    if (this.isThinking || this.isSpeaking) return;
    const greetingRequestId = `greeting-${Date.now()}`;
    this.isSpeaking = true;
    this.waveActive = true;
    this.startWaveAnimation();
    this.startSyntheticLipSync();
    this.sendAvatarCommand('action', 'Greeting', greetingRequestId);
    this.sendAvatarCommand('state', 'Speaking', greetingRequestId);
    setTimeout((): void => {
      if (this.isSpeaking) this.sendAvatarCommand('state', 'Speaking', greetingRequestId);
    }, 220);
    const greeting = GREETINGS[Math.floor(Math.random() * GREETINGS.length)];
    // Greeting is an avatar interaction, not a conversation turn. Speak it
    // without inserting or persisting a new message bubble.
    this.readAloud(greeting, greetingRequestId);
  }

  private async toggleVoiceInput(): Promise<void> {
    if (this.isThinking || this.isSpeaking) return;
    if (this.isListening) {
      this.recognitionGeneration += 1;
      await this.recognitionService.stop();
      this.isListening = false;
      this.stopWaveAnimation();
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    const manager = abilityAccessCtrl.createAtManager();
    const permission = 'ohos.permission.MICROPHONE' as Permissions;
    const result = await manager.requestPermissionsFromUser(context, [permission]);
    if (result.authResults.length === 0 || result.authResults[0] !== 0) {
      this.errorText = '需要麦克风权限才能使用语音输入';
      return;
    }
    this.errorText = '';
    this.recognitionGeneration += 1;
    const generation = this.recognitionGeneration;
    await this.recognitionService.start({
      onResult: (text: string): void => {
        if (generation !== this.recognitionGeneration) return;
        if (text.trim().length > 0) this.draft = text.trim();
      },
      onState: (listening: boolean): void => {
        if (generation !== this.recognitionGeneration) return;
        this.isListening = listening;
        if (listening) {
          this.startWaveAnimation();
        } else if (!this.isThinking && !this.isSpeaking) {
          this.stopWaveAnimation();
        }
      },
      onError: (message: string): void => {
        if (generation !== this.recognitionGeneration) return;
        this.isListening = false;
        this.stopWaveAnimation();
        this.errorText = `语音识别失败：${message}`;
      }
    });
  }

  private async readAloud(text: string, requestId: string, turnId: string = ''): Promise<void> {
    this.startSpeechHighlight(text, turnId);
    this.isSpeaking = true;
    this.waveActive = true;
    this.startWaveAnimation();
    this.sendAvatarCommand('state', 'Speaking', requestId);
    try {
      await AvatarSpeechService.shared.speak(text, {
        onStart: (): void => {
          this.isSpeaking = true;
          this.waveActive = true;
          this.startWaveAnimation();
          this.startSyntheticLipSync();
          this.sendAvatarCommand('state', 'Speaking', requestId);
        },
        onAudioData: (audio: ArrayBuffer, audioType: string, sequence: number): void => {
          const normalized = audioType.toLowerCase();
          if (!normalized.includes('pcm')) {
            if (sequence === 1) console.info(`${TUANJIE_LOG} tts_stream fallback type=${audioType}`);
            return;
          }
          // Real PCM is preferred whenever the engine provides it.
          this.stopSyntheticLipSync();
          try {
            const base64 = this.base64Helper.encodeToStringSync(this.amplifyPcm16(audio, 3.0));
            Tuanjie.TuanjieSendMessage('AvatarRuntime', 'ReceivePcm16', base64);
            if (sequence === 1) console.info(`${TUANJIE_LOG} tts_stream pcm bytes=${audio.byteLength}`);
          } catch (error) {
            if (sequence === 1) console.warn(`${TUANJIE_LOG} tts_stream bridge_error=${JSON.stringify(error)}`);
          }
        },
        onComplete: (): void => {
          this.isSpeaking = false;
          this.waveActive = false;
          this.stopWaveAnimation();
          this.stopSyntheticLipSync();
          this.clearSpeechHighlight();
          this.sendAvatarCommand('state', 'Idle', requestId);
        },
        onError: (message: string): void => {
          console.warn(`avatar_tts_error ${message}`);
          this.errorText = `语音播报失败：${message}`;
          this.isSpeaking = false;
          this.waveActive = false;
          this.stopWaveAnimation();
          this.stopSyntheticLipSync();
          this.clearSpeechHighlight();
          this.sendAvatarCommand('state', 'Idle', requestId);
        }
      });
    } catch (error) {
      console.warn(`avatar_tts_unavailable=${JSON.stringify(error)}`);
      this.errorText = `语音播报暂不可用：${(error as Error).message ?? `${error}`}`;
      this.isSpeaking = false;
      this.waveActive = false;
      this.stopWaveAnimation();
      this.stopSyntheticLipSync();
      this.clearSpeechHighlight();
      this.sendAvatarCommand('state', 'Idle', requestId);
    }
  }

  private stopCurrentSession(invalidate: boolean = true): void {
    if (invalidate) this.requestSerial += 1;
    this.isThinking = false;
    this.isSpeaking = false;
    this.waveActive = false;
    this.stopThinkingCycling();
    this.stopWaveAnimation();
    this.stopSyntheticLipSync();
    this.clearSpeechHighlight();
    AvatarSpeechService.shared.stop();
    this.sendAvatarCommand('stop_audio');
    this.sendAvatarCommand('state', 'Idle');
  }

  private copyText(content: string): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content);
    pasteboard.getSystemPasteboard().setData(data);
  }

  private replayTurn(turn: AvatarTurn): void {
    if (this.isThinking || this.isSpeaking || turn.content.trim().length === 0) return;
    this.readAloud(turn.content, `replay-${turn.id}-${Date.now()}`, turn.id);
  }

  private startThinkingCycling(): void {
    this.stopThinkingCycling();
    this.thinkingStatusIndex = 0;
    this.thinkingStatus = THINKING_STATUS_MESSAGES[0];
    this.thinkingTimer = setInterval((): void => {
      animateTo({ duration: 180, curve: Curve.EaseIn }, (): void => {
        this.thinkingStatusOpacity = 0;
        this.thinkingStatusOffset = -8;
      });
      setTimeout((): void => {
        this.thinkingStatusIndex = (this.thinkingStatusIndex + 1) % THINKING_STATUS_MESSAGES.length;
        this.thinkingStatus = THINKING_STATUS_MESSAGES[this.thinkingStatusIndex];
        this.thinkingStatusOffset = 8;
        animateTo({ duration: 240, curve: Curve.EaseOut }, (): void => {
          this.thinkingStatusOpacity = 1;
          this.thinkingStatusOffset = 0;
        });
      }, 190);
    }, 2200) as number;
  }

  private stopThinkingCycling(): void {
    if (this.thinkingTimer >= 0) {
      clearInterval(this.thinkingTimer);
      this.thinkingTimer = -1;
    }
    this.thinkingStatusIndex = 0;
    this.thinkingStatus = THINKING_STATUS_MESSAGES[0];
    this.thinkingStatusOpacity = 1;
    this.thinkingStatusOffset = 0;
  }

  private startWaveAnimation(): void {
    if (this.waveTimer >= 0) return;
    let frame = 0;
    const iosHeights: number[] = [16, 30, 21, 34, 24, 30, 18];
    this.waveTimer = setInterval((): void => {
      frame += 1;
      const next: number[] = [];
      for (let index = 0; index < 7; index += 1) {
        // Match iOS: each fixed bar breathes between 45% and 100%, with a
        // staggered phase so it reads as an audio waveform rather than noise.
        const scale = 0.28 + (Math.sin(frame * (0.62 + (index % 3) * 0.08) + index * 0.78) + 1) * 0.36;
        next.push(Math.max(5, Math.round(iosHeights[index] * scale)));
      }
      this.waveHeights = next;
    }, 80) as number;
  }

  private stopWaveAnimation(): void {
    this.waveActive = false;
    if (this.waveTimer >= 0) {
      clearInterval(this.waveTimer);
      this.waveTimer = -1;
    }
    this.waveHeights = [8, 14, 10, 18, 11, 15, 9];
  }

  private startSyntheticLipSync(): void {
    this.stopSyntheticLipSync();
    this.mouthFrame = 0;
    // Offline CoreSpeechKit plays sound itself but does not return onData.
    // Feed short speech-like PCM frames only to Unity's NotifyPcm/mouthA path.
    this.mouthTimer = setInterval((): void => {
      this.mouthFrame += 1;
      const sampleCount = 1440;
      const pcm = new Int16Array(sampleCount);
      const envelope = 0.45 + 0.55 * Math.abs(Math.sin(this.mouthFrame * 0.83));
      for (let index = 0; index < sampleCount; index += 1) {
        const carrier = Math.sin(index * 0.071) + 0.42 * Math.sin(index * 0.137);
        pcm[index] = Math.round(carrier * 12000 * envelope);
      }
      try {
        const base64 = this.base64Helper.encodeToStringSync(new Uint8Array(pcm.buffer));
        Tuanjie.TuanjieSendMessage('AvatarRuntime', 'ReceivePcm16', base64);
        if (this.mouthFrame === 1) {
          console.info(`${TUANJIE_LOG} synthetic_lipsync started bytes=${pcm.byteLength}`);
        }
      } catch (error) {
        console.warn(`${TUANJIE_LOG} synthetic_lipsync error=${JSON.stringify(error)}`);
        this.stopSyntheticLipSync();
      }
    }, 90) as number;
  }

  private stopSyntheticLipSync(): void {
    if (this.mouthTimer >= 0) {
      clearInterval(this.mouthTimer);
      this.mouthTimer = -1;
    }
    if (this.mouthFrame > 0) {
      this.sendAvatarCommand('stop_audio');
    }
    this.mouthFrame = 0;
  }

  private amplifyPcm16(audio: ArrayBuffer, gain: number): Uint8Array {
    const source = new Int16Array(audio);
    const output = new Int16Array(source.length);
    for (let index = 0; index < source.length; index += 1) {
      const amplified = Math.round(source[index] * gain);
      output[index] = Math.max(-32768, Math.min(32767, amplified));
    }
    return new Uint8Array(output.buffer);
  }

  private speechSegments(content: string): string[] {
    const matches = content.match(/[^。！？!?；;\n]+[。！？!?；;\n]?/g);
    return matches !== null && matches.length > 0 ? matches : [content];
  }

  private startSpeechHighlight(content: string, turnId: string): void {
    this.clearSpeechHighlight();
    if (turnId.length === 0) return;
    this.speakingTurnId = turnId;
    const segments = this.speechSegments(content);
    // Show the first selected segment immediately. A zero-delay timer can be
    // lost before ArkUI rebuilds the message bubble on real devices.
    this.highlightedSegmentIndex = 0;
    this.scrollHighlightedSegmentToCenter(turnId, 0);
    let elapsed = 0;
    segments.forEach((segment: string, index: number): void => {
      if (index === 0) {
        elapsed += Math.max(650, Math.round(segment.length / 4.8 * 1000));
        return;
      }
      const timer = setTimeout((): void => {
        if (this.speakingTurnId !== turnId) return;
        this.highlightedSegmentIndex = index;
        this.scrollHighlightedSegmentToCenter(turnId, index);
      }, elapsed);
      this.speechHighlightTimers.push(timer);
      elapsed += Math.max(650, Math.round(segment.length / 4.8 * 1000));
    });
  }

  private scrollHighlightedSegmentToCenter(turnId: string, segmentIndex: number): void {
    // Wait for ArkUI to rebuild the selected segment (its padding changes)
    // before reading the recorded center and starting the scroll.
    setTimeout((): void => {
      if (!this.avatarPageVisible || this.speakingTurnId !== turnId ||
        this.highlightedSegmentIndex !== segmentIndex) return;
      const center = this.speechSegmentCenters.get(`${turnId}-${segmentIndex}`);
      if (center === undefined || this.conversationViewportHeight <= 0) return;
      const currentOffset = this.scroller.currentOffset();
      // A Scroller is detached before delayed callbacks are drained during a
      // fast tab switch. The native API is typed as non-null but returns
      // undefined at runtime in that window.
      if (currentOffset === undefined || currentOffset === null) return;
      const maxOffset = Math.max(0, currentOffset.yOffset + center -
        this.conversationViewportCenter);
      this.scroller.scrollTo({
        xOffset: 0,
        yOffset: maxOffset,
        animation: { duration: 280, curve: Curve.EaseInOut }
      });
    }, 40);
  }

  private clearSpeechHighlight(): void {
    this.speechHighlightTimers.forEach((timer: number): void => clearTimeout(timer));
    this.speechHighlightTimers = [];
    this.speakingTurnId = '';
    this.highlightedSegmentIndex = -1;
  }

  @Builder
  private turnContextMenu(turn: AvatarTurn) {
    Column({ space: 2 }) {
      Row({ space: 10 }) {
        Image($rawfile('icons/ic_avatar_speaker.svg'))
          .width(18)
          .height(18)
        Text('朗读')
          .fontSize(15)
          .fontColor(this.isThinking || this.isSpeaking ? '#A8ADB7' : '#252A35')
      }
      .width('100%')
      .height(44)
      .padding({ left: 14, right: 14 })
      .borderRadius(8)
      .onClick(() => this.replayTurn(turn))

      Divider().color('#ECEEF2').strokeWidth(0.5)

      Row({ space: 10 }) {
        Text('⧉').fontSize(18).fontColor('#6E7685')
        Text('复制').fontSize(15).fontColor('#252A35')
      }
      .width('100%')
      .height(44)
      .padding({ left: 14, right: 14 })
      .borderRadius(8)
      .onClick(() => this.copyText(turn.content))
    }
    .width(154)
    .padding(6)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 12, color: '#22000000', offsetX: 0, offsetY: 4 })
  }

  private scrollToBottom(): void {
    setTimeout((): void => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 60);
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        TuanjiePlayerView({ displayIndex: this.displayIndex })
          .width('100%')
          .height('100%')
          .onAppear((): void => {
            console.info(`${TUANJIE_LOG} player_view appear displayIndex=${this.displayIndex}`);
          })
          .onDisAppear((): void => console.info(`${TUANJIE_LOG} player_view disappear`))

        Row({ space: 10 }) {
          Text() {
            Span('AI数字人').fontColor('#8176EE')
          }
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontFamily('MiSans-DemiBold')
            .fontColor('#8F8BFA')
          Text() {
            Span('L').fontColor('#55C5FA')
            Span('I').fontColor('#55C5FA')
            Span('L').fontColor('#986FEF')
            Span('Y').fontColor('#986FEF')
          }
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.2)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor('#3D000000')
            .borderRadius(12)
        }
        .padding({ left: 17, top: 44 })

        if (this.isSpeaking || this.isListening || this.isThinking) {
          Row({ space: 7 }) {
            ForEach(this.waveHeights, (height: number) => {
              Row()
                .width(4)
                .height(height)
                .borderRadius(2)
                .backgroundColor('#2170F2')
            // Height must participate in the key. ArkUI otherwise reuses the
            // child created for the same index and its layout remains static.
            }, (height: number, index: number): string => `${index}-${height}`)
          }
          .width(96)
          .height(62)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .backgroundColor('#E0FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 10, color: '#14000000', offsetX: 0, offsetY: 3 })
          .position({ x: '39%', y: '76%' })
        }

        Column()
          .width('100%')
          .height('78%')
          .backgroundColor('#01000000')
          .gesture(LongPressGesture({ repeat: false, duration: 500 }).onAction((): void => {
            console.info(`${TUANJIE_LOG} avatar_long_press triggered`);
            this.playGreeting();
          }))

        Row({ space: 3 }) {
          Text('✦').fontSize(10).fontColor(Color.White)
          Text('长按试一试').fontSize(10).fontFamily('MiSans-DemiBold').fontColor(Color.White)
        }
        .padding({ left: 7, right: 7, top: 4, bottom: 4 })
        .linearGradient({
          angle: 90,
          colors: this.isThinking || this.isSpeaking ?
            [['#A7A8AE', 0], ['#BFC0C5', 1]] as [string, number][] :
            [['#B8A4EC', 0], ['#DBC0F5', 1]] as [string, number][]
        })
        .borderRadius(5)
        .position({ x: '72%', y: '88%' })
        .gesture(LongPressGesture({ repeat: false, duration: 500 }).onAction((): void => {
          console.info(`${TUANJIE_LOG} greeting_badge_long_press triggered`);
          this.playGreeting();
        }))
      }
      .width('100%')
      .height('64%')
      .backgroundColor('#4B2E78')

      Scroll(this.scroller) {
        Column({ space: 10 }) {
          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize(13)
              .fontColor('#D94141')
              .padding(10)
              .backgroundColor('#10E24B4B')
              .borderRadius(8)
              .width('100%')
          }
          ForEach(this.turns, (turn: AvatarTurn) => {
            Column({ space: 4 }) {
              Text(turn.role === ChatRole.USER ? '我' : '智能体')
                .fontSize(13)
                .fontColor(turn.role === ChatRole.USER ? '#6482B9' : '#5D6471')
                .width('100%')
              Column({ space: 2 }) {
                ForEach(this.speechSegments(turn.content), (segment: string, index: number) => {
                  Text(segment)
                    .fontSize(16)
                    .fontFamily('MiSans')
                    .fontColor('#1C2230')
                    .lineHeight(23)
                    .padding(this.speakingTurnId === turn.id && this.highlightedSegmentIndex === index ?
                      { left: 4, right: 4, top: 2, bottom: 2 } :
                      { left: 0, right: 0, top: 0, bottom: 0 })
                    .backgroundColor(this.speakingTurnId === turn.id && this.highlightedSegmentIndex === index ?
                      '#DCEAFF' : '#00000000')
                    .borderRadius(5)
                    .width('100%')
                    .onAreaChange((_oldValue: Area, newValue: Area): void => {
                      this.speechSegmentCenters.set(`${turn.id}-${index}`,
                        Number(newValue.globalPosition.y) + Number(newValue.height) / 2);
                    })
                }, (_segment: string, index: number): string => `${turn.id}-${index}`)
              }
              .width('100%')
              if (this.actionTurnId === turn.id) {
                Divider().color('#DDE1E8').strokeWidth(0.5).margin({ top: 5 })
                Row({ space: 8 }) {
                  Row({ space: 5 }) {
                    Image($rawfile('icons/ic_message_read.svg')).width(17).height(17)
                    Text('朗读').fontSize(14).fontColor(this.isThinking || this.isSpeaking ? '#A8ADB7' : '#303641')
                  }
                  .height(34)
                  .padding({ left: 11, right: 11 })
                  .backgroundColor('#FDFDFE')
                  .borderRadius(17)
                  .border({ width: 1, color: '#DDE1E8' })
                  .onClick((): void => {
                    this.actionTurnId = '';
                    this.replayTurn(turn);
                  })

                  Row({ space: 5 }) {
                    Image($rawfile('icons/ic_message_copy.svg')).width(17).height(17)
                    Text('复制').fontSize(14).fontColor('#303641')
                  }
                  .height(34)
                  .padding({ left: 11, right: 11 })
                  .backgroundColor('#FDFDFE')
                  .borderRadius(17)
                  .border({ width: 1, color: '#DDE1E8' })
                  .onClick((): void => {
                    this.copyText(turn.content);
                    this.actionTurnId = '';
                  })
                }
                .width('100%')
                .justifyContent(FlexAlign.Start)
                .padding({ top: 5 })
              }
            }
            .padding({ left: 11, right: 11, top: 8, bottom: 8 })
            .backgroundColor(turn.role === ChatRole.USER ? '#E8F0FF' : '#F1F3F7')
            .borderRadius(8)
            .width(turn.role === ChatRole.USER ? '78%' : '88%')
            .alignSelf(turn.role === ChatRole.USER ? ItemAlign.End : ItemAlign.Start)
            .gesture(LongPressGesture({ repeat: false, duration: 500 }).onAction((): void => {
              this.actionTurnId = this.actionTurnId === turn.id ? '' : turn.id;
            }))
          }, (turn: AvatarTurn) => turn.id)

          if (this.isThinking) {
            Row({ space: 10 }) {
              LoadingProgress()
                .width(20)
                .height(20)
                .color('#7658F7')
                .alignSelf(ItemAlign.Start)
                .margin({ top: 1 })
              Text(this.thinkingStatus)
                .fontSize(13)
                .fontFamily('MiSans')
                .fontWeight(FontWeight.Medium)
                .fontColor('#30313A')
                .lineHeight(20)
                .opacity(this.thinkingStatusOpacity)
                .translate({ y: this.thinkingStatusOffset })
                .layoutWeight(1)
            }
            .width('88%')
            .alignSelf(ItemAlign.Start)
            .alignItems(VerticalAlign.Top)
            .padding({ left: 12, right: 12, top: 11, bottom: 11 })
            .backgroundColor('#F3F1FF')
            .borderRadius(12)
            .border({ width: 1, color: 'rgba(118,88,247,0.18)' })
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12, bottom: 10 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        this.conversationViewportHeight = Number(newValue.height);
        this.conversationViewportCenter = Number(newValue.globalPosition.y) +
          this.conversationViewportHeight / 2;
      })

      Column({ space: 7 }) {
        Row({ space: 7 }) {
          Button() {
            Image($rawfile('icons/ic_avatar_speaker.svg'))
              .width(18)
              .height(18)
          }
            .width(36)
            .height(36)
            .padding(0)
            .backgroundColor(this.isListening ? '#E55353' : '#5A92ED')
            .borderRadius(18)
            .onClick(() => this.toggleVoiceInput())
          TextInput({ placeholder: '和智能体说点什么', text: this.draft })
            .onChange((value: string) => this.draft = value)
            .enterKeyType(EnterKeyType.Send)
            .onSubmit((): void => {
              inputMethod.getController().stopInputSession().catch(() => {});
              this.submit();
            })
            .fontSize(13)
            .height(38)
            .layoutWeight(1)
            .constraintSize({ minWidth: 0 })
            .backgroundColor('#F3F5F8')
            .borderRadius(8)
          Button() {
            Text('➤')
              .fontSize(15)
              .fontColor(Color.White)
          }
            .width(38)
            .height(38)
            .padding(0)
            .backgroundColor(this.draft.trim().length > 0 && !this.isThinking ? '#4D7FF0' : '#D8DCE4')
            .borderRadius(8)
            .enabled(this.draft.trim().length > 0 && !this.isThinking)
            .onClick(() => this.submit())
        }
        if (this.isThinking || this.isSpeaking) {
          Row({ space: 6 }) {
            Text('⊗').fontSize(14).fontColor('#8B909A')
            Text('停止当前会话').fontSize(13).fontColor('#858B96')
          }
          .padding({ top: 4, bottom: 6 })
          .onClick(() => this.stopCurrentSession())
        }
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 7 })
      .backgroundColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}
