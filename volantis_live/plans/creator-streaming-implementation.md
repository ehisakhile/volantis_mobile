# Creator Streaming Implementation Guide

This document provides a detailed breakdown of the creator streaming implementation for audio-only WebRTC streaming using the WHIP (WebRTC-HTTP Ingest Protocol) protocol. Use this guide to implement similar features in your mobile app.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [WebRTC WHIP/WHEP Protocol Implementation](#whip-whep-protocol-implementation)
3. [Audio Source Management](#audio-source-management)
4. [Audio Mixing Engine](#audio-mixing-engine)
5. [Background Audio Playback](#background-audio-playback)
6. [Stream Recording & Auto-Upload](#stream-recording--auto-upload)
7. [Audio Visualization](#audio-visualization)
8. [Connection Management & Reconnection](#connection-management--reconnection)
9. [State Management](#state-management)
10. [API Integration](#api-integration)

---

## Architecture Overview

The streaming system uses a modular architecture with three main layers:

```
┌─────────────────────────────────────────────────────────────┐
│                    CreatorStreaming.tsx                      │
│              (Main UI Component & Orchestration)            │
└─────────────────────────┬───────────────────────────────────┘
                          │
         ┌────────────────┼────────────────┐
         │                │                │
         ▼                ▼                ▼
┌─────────────────┐ ┌──────────────┐ ┌──────────────────────┐
│ AudioSourceMgr  │ │ MixerEngine  │ │ useStreamRecorder    │
│  (Selection)    │ │  (Mixing)    │ │   (Recording)        │
└────────┬────────┘ └──────┬───────┘ └──────────┬───────────┘
         │                 │                     │
         ▼                 ▼                     ▼
┌─────────────────┐ ┌──────────────┐ ┌──────────────────────┐
│ Mic/System/Audio│ │ WebAudio API │ │  MediaRecorder API   │
│  (MediaStream)  │ │  (AudioCtx)  │ │   (Blob/Upload)      │
└─────────────────┘ └──────┬───────┘ └──────────────────────┘
                          │
                          ▼
               ┌──────────────────────┐
               │   RTCPeerConnection  │
               │   (WebRTC Streaming) │
               └──────────────────────┘
```

---

## WHIP/WHEP Protocol Implementation

### Protocol Overview

WHIP (WebRTC-HTTP Ingest Protocol) is used for publishing audio to the streaming server. The flow is:

1. Create RTCPeerConnection with ICE servers
2. Capture audio from microphone/system
3. Create SDP offer
4. POST offer to WHIP endpoint
5. Receive SDP answer
6. Set remote description
7. ICE connection establishes

### Implementation Details

#### ICE Configuration

```typescript
// src/lib/webrtc-utils.ts
const ICE_CONFIG: RTCConfiguration = {
  iceServers: [
    { urls: 'stun:stun.cloudflare.com:3478' },
    { urls: 'stun:stun.l.google.com:19302' }
  ],
  iceTransportPolicy: 'all',
  bundlePolicy: 'max-bundle',
  rtcpMuxPolicy: 'require',
};
```

#### Creating the WebRTC Connection

```typescript
// Main streaming logic in CreatorStreaming.tsx
const pc = new RTCPeerConnection(ICE_CONFIG);

// Add audio tracks from the mixed stream
outputStream.getAudioTracks().forEach((track) => {
  pc.addTrack(track, outputStream);
});

// Handle ICE state changes
pc.oniceconnectionstatechange = () => {
  console.log(`ICE State: ${pc.iceConnectionState}`);
  if (pc.iceConnectionState === 'connected') {
    // Start stats tracking
    startPubStats();
  } else if (pc.iceConnectionState === 'failed') {
    // Trigger reconnection
    handleReconnect();
  }
};

// Create and configure offer
const offer = await pc.createOffer({
  offerToReceiveAudio: false,
  offerToReceiveVideo: false,
});

// Prefer Opus codec with low-latency settings
const sdpWithOpus = preferOpus(offer.sdp);
await pc.setLocalDescription({ type: offer.type, sdp: sdpWithOpus });

// Wait for ICE gathering to complete
await waitForIce(pc, 2000);

// POST to WHIP endpoint (from API response)
const response = await fetch(streamData.cf_webrtc_publish_url, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/sdp',
    'Accept': 'application/sdp',
  },
  body: pc.localDescription.sdp,
});

// Set remote description from answer
const answerSdp = await response.text();
await pc.setRemoteDescription({ type: 'answer', sdp: answerSdp });
```

#### Opus Codec Configuration

The implementation prefers Opus with low-latency settings:

```typescript
// src/lib/webrtc-utils.ts
function preferOpus(sdp: string): string {
  const match = sdp.match(/a=rtpmap:(\d+) opus\/48000\/2/i);
  if (!match) return sdp;
  const pt = match[1];

  // Configure for low latency
  const opusFmtp = `a=fmtp:${pt} minptime=10;useinbandfec=1;stereo=0;maxaveragebitrate=96000`;

  if (sdp.includes(`a=fmtp:${pt} `)) {
    return sdp.replace(new RegExp(`a=fmtp:${pt} [^\r\n]+`), opusFmtp);
  } else {
    return sdp.replace(
      new RegExp(`(a=rtpmap:${pt} opus[^\r\n]+\r?\n)`),
      `$1${opusFmtp}\r\n`
    );
  }
}
```

---

## Audio Source Management

### Overview

The AudioSourceManager provides a clean abstraction for handling different audio sources:

- **MicrophoneAudioSource**: Captures from device microphone
- **SystemAudioSource**: Captures system audio via screen sharing
- **MixedAudioSource**: Combines multiple sources
- **BackgroundAudioSource**: Plays local audio files

### Implementation

#### AudioSourceManager

```typescript
// src/lib/audio-sources.ts
export class AudioSourceManager {
  private microphoneSource: MicrophoneAudioSource;
  private systemAudioSource: SystemAudioSource;
  private mixedSource: MixedAudioSource | null = null;
  private activeSource: AudioSource | null = null;

  private state: AudioSourceState = {
    useMic: true,
    useSystemAudio: false,
    mixAudio: false,
    selectedMicDevice: '',
  };

  // Configuration methods
  setUseMic(enabled: boolean): void { ... }
  setUseSystemAudio(enabled: boolean): void { ... }
  setMixAudio(enabled: boolean): void { ... }
  setSelectedMicDevice(deviceId: string): void { ... }

  // Capture audio based on current configuration
  async capture(): Promise<AudioSourceResult> { ... }

  // Stop all sources
  stopAll(): void { ... }
}
```

#### Capturing Microphone

```typescript
// src/lib/webrtc-utils.ts
export async function captureMicrophone(deviceId?: string): Promise<MediaStream> {
  const constraints: MediaStreamConstraints = {
    audio: {
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
      sampleRate: { ideal: 48000 },
      channelCount: { ideal: 1 },
      ...(deviceId && { deviceId: { exact: deviceId } })
    },
    video: false
  };
  return await navigator.mediaDevices.getUserMedia(constraints);
}
```

#### Capturing System Audio

```typescript
// src/lib/webrtc-utils.ts
export async function captureSystemAudio(): Promise<MediaStream> {
  const displayStream = await navigator.mediaDevices.getDisplayMedia({
    video: true,  // Required - browser won't let you skip this
    audio: {
      echoCancellation: false,
      noiseSuppression: false,
      autoGainControl: false,
      sampleRate: { ideal: 48000 }
    }
  });

  // Pull only the audio track
  const audioTracks = displayStream.getAudioTracks();
  if (audioTracks.length === 0) {
    throw new Error('No audio captured');
  }

  // Stop the video track we were forced to grab
  displayStream.getVideoTracks().forEach(t => t.stop());

  return new MediaStream(audioTracks);
}
```

#### Getting Audio Input Devices

```typescript
// src/lib/webrtc-utils.ts
export async function getAudioInputDevices(): Promise<MediaDeviceInfo[]> {
  const devices = await navigator.mediaDevices.enumerateDevices();
  return devices.filter(d => d.kind === 'audioinput');
}
```

---

## Audio Mixing Engine

### Overview

The MixerEngine creates a Web Audio API-based mix bus that combines multiple audio sources into a single output stream for WebRTC. This allows real-time mixing of microphone, system audio, and background audio.

### Architecture

```
Mic Source ──┐
             ├──► GainNode ──► MixBus (DestinationNode) ──► RTCPeerConnection
System Src ──┤
             │
Background ──┘
```

### Implementation

```typescript
// src/lib/mixer-engine.ts
export class MixerEngine {
  private audioCtx: AudioContext;
  private destination: MediaStreamAudioDestinationNode;
  private masterGain: GainNode;
  private masterAnalyser: AnalyserNode;
  private channels: Map<string, MixerChannel> = new Map();

  constructor(config?: MixerEngineConfig) {
    // Create AudioContext
    this.audioCtx = new AudioContext({ sampleRate: config?.sampleRate || 44100 });

    // Resume if suspended (browser autoplay policy)
    if (this.audioCtx.state === 'suspended') {
      this.audioCtx.resume();
    }

    // Create master destination node (output to WebRTC)
    this.destination = this.audioCtx.createMediaStreamDestination();

    // Create master gain and analyser
    this.masterGain = this.audioCtx.createGain();
    this.masterGain.gain.value = 1.0;

    this.masterAnalyser = this.audioCtx.createAnalyser();
    this.masterAnalyser.fftSize = 256;
    this.masterAnalyser.smoothingTimeConstant = 0.8;

    // Connect master chain
    this.masterGain.connect(this.masterAnalyser);
    this.masterAnalyser.connect(this.destination);
  }

  // Get output stream for WebRTC
  get outputStream(): MediaStream {
    return this.destination.stream;
  }

  // Add a channel
  addChannel(
    id: string,
    label: string,
    type: ChannelType,
    stream: MediaStream,
    deviceId?: string
  ): MixerChannel {
    const sourceNode = this.audioCtx.createMediaStreamSource(stream);
    const gainNode = this.audioCtx.createGain();
    gainNode.gain.value = 1;

    const analyserNode = this.audioCtx.createAnalyser();
    analyserNode.fftSize = 256;
    analyserNode.smoothingTimeConstant = 0.8;

    // Connect chain: source -> gain -> analyser -> master -> destination
    sourceNode.connect(gainNode);
    gainNode.connect(analyserNode);
    analyserNode.connect(this.masterGain);

    const channel: MixerChannel = {
      id,
      label,
      type,
      gainNode,
      analyserNode,
      sourceNode,
      stream,
      isMuted: false,
      volume: 100,
      deviceId,
    };

    this.channels.set(id, channel);
    return channel;
  }

  // Set volume (0-100) - uses setTargetAtTime for smooth transitions
  setVolume(id: string, volume: number): void {
    const channel = this.channels.get(id);
    if (!channel) return;

    // Map 0-100 to 0.0-1.5 gain
    const gainValue = (volume / 100) * 1.5;
    channel.gainNode.gain.setTargetAtTime(gainValue, this.audioCtx.currentTime, 0.02);
  }

  // Toggle mute
  setMute(id: string, muted: boolean): void {
    const channel = this.channels.get(id);
    if (!channel) return;

    const targetGain = muted ? 0 : (channel.volume / 100) * 1.5;
    channel.gainNode.gain.setTargetAtTime(targetGain, this.audioCtx.currentTime, 0.02);
  }

  // Get audio level for VU meter (0-1)
  getLevel(id: string): number {
    const channel = this.channels.get(id);
    if (!channel) return 0;
    return this.calculateLevel(channel.analyserNode);
  }

  getMasterLevel(): number {
    return this.calculateLevel(this.masterAnalyser);
  }

  private calculateLevel(analyser: AnalyserNode): number {
    const dataArray = new Uint8Array(analyser.frequencyBinCount);
    analyser.getByteFrequencyData(dataArray);

    // Calculate RMS
    let sum = 0;
    for (let i = 0; i < dataArray.length; i++) {
      const normalized = dataArray[i] / 255;
      sum += normalized * normalized;
    }
    const rms = Math.sqrt(sum / dataArray.length);

    return Math.min(1, rms * 2);
  }

  // Remove a channel
  removeChannel(id: string): void {
    const channel = this.channels.get(id);
    if (!channel) return;

    channel.sourceNode.disconnect();
    channel.gainNode.disconnect();
    channel.analyserNode.disconnect();
    channel.stream.getTracks().forEach(track => track.stop());

    this.channels.delete(id);
  }

  // Cleanup
  destroy(): void {
    this.channels.forEach((_, id) => this.removeChannel(id));
    this.masterGain.disconnect();
    this.masterAnalyser.disconnect();
    this.destination.disconnect();
    this.audioCtx.close();
  }
}
```

---

## Background Audio Playback

### Overview

The BackgroundAudioSource class allows playing local audio files (MP3/WAV/OGG) through the AudioContext for mixing with other sources.

### Implementation

```typescript
// src/lib/audio-sources.ts
export class BackgroundAudioSource extends AudioSource {
  private file: File;
  private loop: boolean;
  private audioBuffer: AudioBuffer | null = null;
  private sourceNode: AudioBufferSourceNode | null = null;
  private destinationNode: MediaStreamAudioDestinationNode | null = null;
  private audioContext: AudioContext | null = null;
  private gainNode: GainNode | null = null;

  constructor(file: File, loop = true) {
    super({
      id: 'background',
      name: 'Background Audio',
      isActive: false,
    });
    this.file = file;
    this.loop = loop;
  }

  async capture(): Promise<AudioSourceResult> {
    const audioCtx = new AudioContext();
    this.audioContext = audioCtx;

    if (audioCtx.state === 'suspended') {
      await audioCtx.resume();
    }

    // Decode audio file
    const arrayBuffer = await this.file.arrayBuffer();
    this.audioBuffer = await audioCtx.decodeAudioData(arrayBuffer);

    // Create destination for WebRTC
    this.destinationNode = audioCtx.createMediaStreamDestination();
    this.gainNode = audioCtx.createGain();

    // Create and configure source
    this.sourceNode = audioCtx.createBufferSource();
    this.sourceNode.buffer = this.audioBuffer;
    this.sourceNode.loop = this.loop;

    // Connect: source -> gain -> destination
    this.sourceNode.connect(this.gainNode);
    this.gainNode.connect(this.destinationNode);

    // Start playback
    this.sourceNode.start(0);
    this.config.isActive = true;

    return {
      stream: this.destinationNode.stream,
      cleanup: () => this.stop(),
    };
  }

  // Volume control
  setVolume(volume: number): void {
    if (this.gainNode) {
      this.gainNode.gain.value = volume;
    }
  }

  // Seek to position (0-1)
  seek(position: number): void {
    // Implementation for seeking
  }

  // Pause/Resume
  pause(): void { /* ... */ }
  resume(): void { /* ... */ }

  stop(): void {
    if (this.sourceNode) {
      this.sourceNode.stop();
      this.sourceNode.disconnect();
    }
    if (this.destinationNode) {
      this.destinationNode.disconnect();
    }
    this.config.isActive = false;
  }
}
```

---

## Stream Recording & Auto-Upload

### Overview

The system records the mixed audio stream during streaming and optionally auto-uploads the recording when the stream ends. This uses the MediaRecorder API.

### Recording Hook API

```typescript
// src/hooks/useStreamRecorder.ts
export function useStreamRecorder(options: StreamRecorderOptions = {}): StreamRecorderReturn {
  // Options
  // - onRecordingReady: Callback when recording is ready
  // - onUploadComplete: Callback when upload completes
  // - onUploadError: Callback when upload fails
  // - onAutoUploadComplete: Callback when auto-upload completes

  // State
  const state: StreamRecorderState = {
    wantsToRecord: boolean | null,  // null = not asked, true/false = answered
    isRecording: boolean,
    recordingDuration: number,
    recordedBlob: Blob | null,
    recordedFilename: string | null,
    isUploading: boolean,
    uploadProgress: number,
    error: string | null,
    streamSlug: string | null,
    autoUpload: boolean,           // Auto-upload after stream ends
    isUploaded: boolean,
  };

  // Methods
  return {
    state,
    promptRecording: () => void,           // Show user prompt
    acceptRecording: () => void,           // Accept - save locally only
    acceptRecordingWithAutoUpload: () => void,  // Accept with auto-upload
    declineRecording: () => void,          // Decline recording
    startRecording: (stream, streamSlug, streamTitle) => void,
    stopRecording: () => void,
    uploadRecording: () => Promise<void>,
    downloadRecording: () => void,
    reset: () => void,
    shouldPromptRecording: boolean,        // Check if prompt needed
  };
}
```

### Recording Workflow

1. **Before Stream Starts**: Call `promptRecording()` to ask user
2. **User Accepts**: Set `wantsToRecord = true`, optionally `autoUpload = true`
3. **During Stream**: Call `startRecording(stream, slug, title)` with the mixed audio stream
4. **When Stream Ends**: Call `stopRecording()` which:
   - If `autoUpload = true`: Automatically uploads to server
   - If `autoUpload = false`: Auto-downloads to device

### Implementation Details

#### Starting Recording

```typescript
const startRecording = (stream: MediaStream, streamSlug: string, streamTitle: string) => {
  // Create AudioContext to capture stream
  const audioContext = new AudioContext();
  const destNode = audioContext.createMediaStreamDestination();

  // Connect source to destination
  const source = audioContext.createMediaStreamSource(stream);
  source.connect(destNode);

  // Get supported MIME type
  const mimeType = getSupportedMimeType(); // Prefers audio/mp4, then audio/webm

  // Create MediaRecorder
  const mediaRecorder = new MediaRecorder(destNode.stream, {
    mimeType,
    audioBitsPerSecond: 128000,
  });

  const chunks: Blob[] = [];

  mediaRecorder.ondataavailable = (event) => {
    if (event.data && event.data.size > 0) {
      chunks.push(event.data);
    }
  };

  mediaRecorder.onstop = () => {
    const blob = new Blob(chunks, { type: mimeType });
    const filename = `recording_${streamTitle}_${timestamp}.${extension}`;

    // Auto-download if not auto-uploading
    if (!autoUpload) {
      downloadBlob(blob, filename);
    }
  };

  // Start with 1-second timeslice
  mediaRecorder.start(1000);
};
```

#### Auto-Upload After Stream Ends

```typescript
const stopRecording = async () => {
  // Stop the recorder
  if (mediaRecorderRef.current?.state === 'recording') {
    mediaRecorderRef.current.stop();
  }

  // If auto-upload is enabled
  if (shouldAutoUpload && streamSlug) {
    // Wait for blob to be created
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Upload to server
    const response = await livestreamApi.uploadRecording(
      streamSlug,
      file,
      `Recording of stream: ${streamTitle}`,
      recordingDuration
    );

    // Trigger callback
    onAutoUploadComplete?.(response.recording_url);
  }
};
```

#### API Upload

```typescript
// src/lib/api/livestream.ts
async uploadRecording(
  streamSlug: string,
  file: File,
  description?: string,
  duration?: number
): Promise<{ recording_url: string }> {
  const formData = new FormData();
  formData.append('file', file);
  if (description) formData.append('description', description);
  if (duration) formData.append('duration', String(duration));

  const response = await this.client.post(
    `/livestreams/${streamSlug}/recordings`,
    formData,
    {
      headers: { 'Content-Type': 'multipart/form-data' },
    }
  );
  return response.data;
}
```

### Supported MIME Types

The recorder prefers these formats (in order):

1. `audio/mp4` - MP4 with AAC (preferred)
2. `audio/x-m4a` - M4A variant
3. `audio/webm;codecs=opus` - WebM with Opus
4. `audio/webm` - WebM default
5. `audio/wav` - WAV

---

## Audio Visualization

### Overview

The visualizer uses the Web Audio API's AnalyserNode to display real-time frequency data on an HTML5 Canvas.

### Implementation

```typescript
// src/lib/webrtc-utils.ts
export function startVisualizer(
  stream: MediaStream,
  canvas: HTMLCanvasElement,
  accentColor: string = '#00e5a0'
): () => void {
  const ctx = canvas.getContext('2d');
  if (!ctx) return () => {};

  // Create audio context and analyser
  const audioCtx = new AudioContext();
  const source = audioCtx.createMediaStreamSource(stream);
  const analyser = audioCtx.createAnalyser();

  analyser.fftSize = 256;
  analyser.smoothingTimeConstant = 0.75;
  source.connect(analyser);

  const bufferLength = analyser.frequencyBinCount;
  const dataArray = new Uint8Array(bufferLength);
  let rafId: number;

  function draw() {
    rafId = requestAnimationFrame(draw);

    // Get frequency data
    analyser.getByteFrequencyData(dataArray);

    const W = canvas.width;
    const H = canvas.height;

    ctx.clearRect(0, 0, W, H);

    // Draw frequency bars
    const barW = (W / bufferLength) * 2.2;
    let x = 0;

    for (let i = 0; i < bufferLength; i++) {
      const barH = (dataArray[i] / 255) * H;
      const alpha = 0.4 + (dataArray[i] / 255) * 0.6;

      // Draw bar with accent color and dynamic alpha
      ctx.fillStyle = accentColor + Math.round(alpha * 255).toString(16).padStart(2, '0');
      ctx.beginPath();
      ctx.roundRect(x, H - barH, barW - 1, barH, 2);
      ctx.fill();

      x += barW;
    }
  }

  draw();

  // Return cleanup function
  return () => {
    cancelAnimationFrame(rafId);
    audioCtx.close();
  };
}
```

### Usage in Component

```typescript
// In CreatorStreaming.tsx
const canvasRef = useRef<HTMLCanvasElement | null>(null);
const stopVizRef = useRef<(() => void) | null>(null);

// Start visualizer when streaming begins
if (canvasRef.current) {
  stopVizRef.current = startVisualizer(
    outputStream,        // Mixed audio stream
    canvasRef.current,
    '#00e5a0',          // Accent color
  );
}

// Cleanup when streaming stops
if (stopVizRef.current) {
  stopVizRef.current();
  stopVizRef.current = null;
}
```

### Canvas Configuration

- **Width**: 800px
- **Height**: 128px
- **FFT Size**: 256 (results in 128 frequency bins)
- **Smoothing**: 0.75 (temporal smoothing)
- **Bar Style**: Rounded bars with dynamic alpha based on amplitude

---

## Connection Management & Reconnection

### ICE Connection States

The implementation monitors these ICE connection states:

- `new` - Initial state
- `checking` - Searching for candidates
- `connected` - Connection established
- `completed` - ICE completed
- `disconnected` - Temporarily disconnected
- `failed` - Connection failed
- `closed` - Connection closed

### Automatic Reconnection

```typescript
// Auto-reconnect when connection fails
useEffect(() => {
  if (isStreaming && connectionState === 'failed' && currentStream) {
    const reconnectTimeout = setTimeout(async () => {
      // Check if stream is still active on server
      const activeStreams = await livestreamApi.getActiveStreams(50, 0);
      const myStream = activeStreams.find(s => s.id === currentStream?.id);

      if (myStream) {
        // Reconnect
        handleReconnectToStream();
      } else {
        // Stream ended while offline
        setIsStreaming(false);
        teardownPublish();
      }
    }, 2000);

    return () => clearTimeout(reconnectTimeout);
  }
}, [connectionState, isStreaming, currentStream]);
```

### Network Status Monitoring

```typescript
useEffect(() => {
  const handleOnline = () => {
    setIsOnline(true);
    if (isStreaming && connectionState === 'failed') {
      setNetworkRecovered(true);
    }
  };

  const handleOffline = () => {
    setIsOnline(false);
  };

  window.addEventListener('online', handleOnline);
  window.addEventListener('offline', handleOffline);

  return () => {
    window.removeEventListener('online', handleOnline);
    window.removeEventListener('offline', handleOffline);
  };
}, [isStreaming, connectionState]);
```

### Stats Tracking

```typescript
const startPubStats = () => {
  let lastBytes = 0;
  let lastTs = 0;

  statsTimerRef.current = setInterval(async () => {
    if (!pcRef.current) return;

    const stats = await pcRef.current.getStats();
    stats.forEach((r) => {
      if (r.type === 'outbound-rtp' && r.kind === 'audio') {
        const now = r.timestamp;
        const bytes = r.bytesSent;

        if (lastTs) {
          const dt = (Number(now) - lastTs) / 1000;
          const kbps = Math.round(((bytes - lastBytes) * 8) / dt / 1000);
          setBitrate(kbps + ' kbps');
        }

        lastBytes = Number(bytes);
        lastTs = Number(now);
      }
    });
  }, 1500);
};
```

---

## State Management

### Main Component State

```typescript
// Stream state
const [isStreaming, setIsStreaming] = useState(false);
const [isStarting, setIsStarting] = useState(false);
const [streamTitle, setStreamTitle] = useState('');
const [streamDescription, setStreamDescription] = useState('');
const [currentStream, setCurrentStream] = useState<VolLivestreamOut | null>(null);

// Audio source selection
const [useMic, setUseMic] = useState(true);
const [useSystemAudio, setUseSystemAudio] = useState(false);
const [mixAudio, setMixAudio] = useState(false);

// Device selection
const [micDevices, setMicDevices] = useState<MediaDeviceInfo[]>([]);
const [selectedMicDevice, setSelectedMicDevice] = useState<string>('');

// Stream duration
const [streamDuration, setStreamDuration] = useState(0);

// Connection state
const [connectionState, setConnectionState] = useState<string>('idle');
const [error, setError] = useState<string | null>(null);

// Stats
const [codec, setCodec] = useState<string>('—');
const [bitrate, setBitrate] = useState<string>('—');
const [iceState, setIceState] = useState<string>('—');
```

### Refs for WebRTC Objects

```typescript
const pcRef = useRef<RTCPeerConnection | null>(null);
const pubStreamRef = useRef<MediaStream | null>(null);
const stopVizRef = useRef<(() => void) | null>(null);
const statsTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
const audioSourceManagerRef = useRef<AudioSourceManager | null>(null);
const mixerEngineRef = useRef<MixerEngine | null>(null);
```

---

## API Integration

### Starting a Stream

```typescript
// src/lib/api/livestream.ts
async startAudioStream(params: {
  title: string;
  description?: string;
  thumbnail?: File;
}): Promise<VolLivestreamOut> {
  const formData = new FormData();
  formData.append('title', params.title);
  if (params.description) formData.append('description', params.description);
  if (params.thumbnail) formData.append('thumbnail', params.thumbnail);

  const response = await this.client.post('/livestreams/start', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });

  // Returns stream with cf_webrtc_publish_url for WHIP
  return response.data;
}
```

### Stopping a Stream

```typescript
async stopStream(slug: string): Promise<void> {
  await this.client.post(`/livestreams/${slug}/stop`);
}
```

### Getting Active Streams

```typescript
async getActiveStreams(limit = 50, offset = 0): Promise<VolLivestreamOut[]> {
  const response = await this.client.get('/livestreams/active', {
    params: { limit, offset },
  });
  return response.data;
}
```

### Upload Recording

```typescript
async uploadRecording(
  streamSlug: string,
  file: File,
  description?: string,
  duration?: number
): Promise<{ recording_url: string }> {
  const formData = new FormData();
  formData.append('file', file);
  if (description) formData.append('description', description);
  if (duration) formData.append('duration', String(duration));

  const response = await this.client.post(
    `/livestreams/${streamSlug}/recordings`,
    formData,
    {
      headers: { 'Content-Type': 'multipart/form-data' },
    }
  );
  return response.data;
}
```

---

## Cleanup & Resource Management

### Teardown Function

```typescript
const teardownPublish = () => {
  // Close WebRTC peer connection
  if (pcRef.current) {
    pcRef.current.close();
    pcRef.current = null;
  }

  // Stop main publish stream
  if (pubStreamRef.current) {
    pubStreamRef.current.getTracks().forEach(t => t.stop());
    pubStreamRef.current = null;
  }

  // Stop all audio sources
  if (audioSourceManagerRef.current) {
    audioSourceManagerRef.current.stopAll();
  }

  // Destroy mixer engine
  if (mixerEngineRef.current) {
    mixerEngineRef.current.destroy();
    mixerEngineRef.current = null;
  }

  // Stop visualizer
  if (stopVizRef.current) {
    stopVizRef.current();
    stopVizRef.current = null;
  }

  // Clear stats timer
  if (statsTimerRef.current) {
    clearInterval(statsTimerRef.current);
    statsTimerRef.current = null;
  }
};
```

---

## Mobile App Implementation Notes

### Key Differences for Mobile

1. **WebRTC Support**: Use a mobile WebRTC library like:
   - iOS: WebRTC.framework or ios-webrtc
   - Android: Google WebRTC or libwebrtc

2. **Audio Capture**:
   - iOS: Use AVAudioEngine for low-level audio capture
   - Android: Use AudioRecord API

3. **Background Audio**: Use platform-specific background audio APIs

4. **Screen Sharing (System Audio)**:
   - iOS: Use ReplayKit (RPBroadcastActivity)
   - Android: Use MediaProjection API

5. **Recording**: Use platform media recorders instead of MediaRecorder API

### Recommended Mobile Libraries

- **iOS**:
  - WebRTC.framework (Apple's official)
  - HaishinKit (Swift)
  - GoogleWebRTC

- **Android**:
  - libwebrtc (Google)
  - HaishinKit (Kotlin)
  - android-webrtc

### Protocol Compatibility

The WHIP protocol is HTTP-based and works the same on mobile as web. Ensure your mobile WebRTC implementation:
- Supports STUN/TURN ICE servers
- Supports Opus codec
- Handles ICE candidates properly
- Follows the same SDP exchange flow

---

## Summary

This implementation provides:

1. **WHIP Protocol**: Standard WebRTC ingest over HTTP POST
2. **Audio Sources**: Microphone, system audio, and background music
3. **Mixing**: Real-time Web Audio API-based mixing with volume control
4. **Recording**: MediaRecorder-based with auto-upload capability
5. **Visualization**: Canvas-based frequency visualizer
6. **Resilience**: Automatic reconnection and network status monitoring

For mobile implementation, adapt the WebRTC and audio capture components to use platform-specific APIs while maintaining the same protocol flow and API contracts.