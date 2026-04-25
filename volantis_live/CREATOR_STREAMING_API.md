# Volantis Creator Streaming API Documentation

This document provides a complete reference for implementing creator streaming features in a mobile app, including all API endpoints, WebRTC implementation details, and feature specifications.

---

## Base Configuration

| Setting | Value |
|---------|-------|
| API Base URL | `https://api-dev.volantislive.com` |
| WebRTC STUN Servers | `stun:stun.cloudflare.com:3478`, `stun:stun.l.google.com:19302` |
| Protocol | WHIP (publishing), WHEP (playback) |

---

## Authentication

### Token Storage
Tokens are stored in localStorage with these keys:
- `access_token`
- `refresh_token`
- `token_expires_in`
- `token_timestamp`

### Token Usage
Include in API requests:
```
Authorization: Bearer {access_token}
```

---

## API Endpoints

### 1. Start Audio Stream

**POST** `/livestreams/start/audio`

**Authentication:** Required

**Request (with thumbnail):**
```typescript
// FormData
{
  title: string;           // Required
  description?: string;    // Optional
  thumbnail: File;         // Optional image
}
```

**Request (without thumbnail):**
```typescript
// application/x-www-form-urlencoded
title=Stream+Title&description=Stream+Description
```

**Response:**
```typescript
interface VolLivestreamOut {
  id: number;
  company_id: number;
  company_slug: string | null;
  company_name: string | null;
  title: string;
  slug: string;
  description: string | null;
  stream_type: 'audio' | 'video';
  is_active: boolean;
  start_time: string;
  end_time: string | null;
  cf_live_input_uid: string | null;
  cf_rtmps_url: string | null;
  cf_stream_key: string | null;
  cf_webrtc_publish_url: string | null;   // WHIP publish URL
  cf_webrtc_playback_url: string | null;  // WHEP playback URL
  recording_url: string | null;
  thumbnail_url: string | null;
  viewer_count: number;
  peak_viewers: number;
  created_by_username: string;
  created_at: string;
}
```

---

### 2. Start Video Stream

**POST** `/livestreams/start/video`

**Authentication:** Required

**Request:**
```typescript
// application/x-www-form-urlencoded
title=Stream+Title&description=Stream+Description
```

**Response:** Same as audio stream

---

### 3. Stop Stream

**POST** `/livestreams/{slug}/stop`

**Authentication:** Required

**Response:** `VolLivestreamOut` with `is_active: false`

---

### 4. Get Active Streams (User's Company)

**GET** `/livestreams?limit=50&offset=0`

**Authentication:** Required

**Response:** `VolLivestreamOut[]` (filtered to active only)

---

### 5. Get Livestream by Slug

**GET** `/livestreams/{slug}`

**Authentication:** Required

**Response:** `VolLivestreamOut`

---

### 6. Upload Recording

**POST** `/livestreams/{slug}/upload-recording`

**Authentication:** Required

**Request (FormData):**
```typescript
{
  recording: File;                    // Required
  description?: string;               // Optional
  duration_seconds?: number;          // Optional
}
```

**Response:**
```typescript
{ recording_url: string }
```

---

### 7. Public: Get All Active Streams

**GET** `/livestreams/active?limit=50&offset=0`

**Authentication:** Not required

**Response:**
```typescript
interface ActiveStreamsResponse {
  streams: {
    id: number;
    title: string;
    slug: string;
    company_id: number;
    company_slug: string;
    company_name: string;
    company_logo_url: string | null;
    is_live: boolean;
    viewer_count: number;
    thumbnail_url: string | null;
    started_at: string;
  }[];
  total: number;
}
```

---

### 8. Public: Get Company Live Page

**GET** `/{companySlug}/live`

**Authentication:** Not required

**Response:**
```typescript
interface CompanyLivePageResponse {
  company: {
    id: number;
    name: string;
    slug: string;
    logo_url: string | null;
    description: string | null;
  };
  livestream: {
    id: number;
    title: string;
    slug: string;
    description: string | null;
    is_live: boolean;
    viewer_count: number;
    peak_viewers: number;
    total_views: number;
    webrtc_playback_url: string | null;
    hls_url: string | null;
    started_at: string;
  } | null;
  subscribers_count: number;
}
```

---

### 9. Public: Get Realtime Stats

**GET** `/stream/{slug}/realtime`

**Authentication:** Not required

**Response:**
```typescript
{
  slug: string;
  is_active: boolean;
  viewer_count: number;
  peak_viewers: number;
  total_views: number;
  websocket_url: string;
}
```

---

### 10. Public: Get Viewer Count

**GET** `/livestream/{slug}/viewers/count?company_id={companyId}`

**Authentication:** Not required

**Response:**
```typescript
{
  slug: string;
  is_active: boolean;
  viewer_count: number;
  peak_viewers: number;
  total_views: number;
  websocket_url: string;
}
```

---

### 11. Chat: Get Messages

**GET** `/livestream-chat/{slug}/messages?page=1&size=50`

**Authentication:** Not required

**Response:** `VolChatMessageOut[]`

---

### 12. Chat: Send Message

**POST** `/livestream-chat/{slug}/messages`

**Authentication:** Required

**Request:**
```typescript
{ content: string }
```

**Response:** `VolChatMessageOut`

---

### 13. Chat: Edit Message

**PUT** `/livestream-chat/messages/{messageId}/edit`

**Authentication:** Required

**Request:**
```typescript
{ content: string }
```

---

### 14. Chat: Delete Message

**DELETE** `/livestream-chat/messages/{messageId}`

**Authentication:** Required

---

## WebRTC Implementation

### WHIP Protocol (Publishing)

The WebRTC ingest protocol for publishing audio/video streams.

#### Step 1: Create Peer Connection

```typescript
const ICE_CONFIG: RTCConfiguration = {
  iceServers: [
    { urls: 'stun:stun.cloudflare.com:3478' },
    { urls: 'stun:stun.l.google.com:19302' }
  ],
  iceTransportPolicy: 'all',
  bundlePolicy: 'max-bundle',
  rtcpMuxPolicy: 'require',
};

const pc = new RTCPeerConnection(ICE_CONFIG);
```

#### Step 2: Add Audio Track

```typescript
stream.getAudioTracks().forEach((track) => {
  pc.addTrack(track, stream);
});
```

#### Step 3: Create and Configure Offer

```typescript
const offer = await pc.createOffer({
  offerToReceiveAudio: false,
  offerToReceiveVideo: false,
});

// Apply Opus codec optimization for low latency
const sdpWithOpus = preferOpus(offer.sdp || '');
await pc.setLocalDescription({ type: 'offer', sdp: sdpWithOpus });
```

#### Step 4: Wait for ICE Gathering

```typescript
await waitForIce(pc, 2000);
```

#### Step 5: Send Offer to Server (WHIP)

```typescript
const response = await fetch(publishUrl, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/sdp',
    'Accept': 'application/sdp',
  },
  body: pc.localDescription.sdp,
});

if (!response.ok) {
  throw new Error(`Server error: ${response.status}`);
}

const answerSdp = await response.text();
await pc.setRemoteDescription({ type: 'answer', sdp: answerSdp });
```

---

### WHEP Protocol (Playback)

The WebRTC HTTP egress protocol for playback.

#### Step 1: Create Peer Connection

```typescript
const pc = new RTCPeerConnection(ICE_CONFIG);
```

#### Step 2: Handle Incoming Tracks

```typescript
pc.ontrack = (event) => {
  if (event.streams[0]) {
    // event.streams[0] contains the remote audio stream
    // Use this for audio playback
  }
};
```

#### Step 3: Add Recv-Only Transceiver

```typescript
pc.addTransceiver('audio', { direction: 'recvonly' });
```

#### Step 4: Create Offer

```typescript
const offer = await pc.createOffer();
await pc.setLocalDescription(offer);
```

#### Step 5: Wait for ICE

```typescript
await waitForIce(pc, 2000);
```

#### Step 6: Send Offer to Server (WHEP)

```typescript
const response = await fetch(playbackUrl, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/sdp',
    'Accept': 'application/sdp',
  },
  body: pc.localDescription.sdp,
});

const answerSdp = await response.text();
await pc.setRemoteDescription({ type: 'answer', sdp: answerSdp });
```

---

### Helper Functions

#### Prefer Opus Codec (Low Latency)

```typescript
function preferOpus(sdp: string): string {
  const match = sdp.match(/a=rtpmap:(\d+) opus\/48000\/2/i);
  if (!match) return sdp;
  const pt = match[1];

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

#### Wait for ICE Gathering

```typescript
function waitForIce(pc: RTCPeerConnection, maxMs: number = 2000): Promise<void> {
  return new Promise((resolve) => {
    if (pc.iceGatheringState === 'complete') {
      resolve();
      return;
    }
    const timeout = setTimeout(resolve, maxMs);
    pc.onicegatheringstatechange = () => {
      if (pc.iceGatheringState === 'complete') {
        clearTimeout(timeout);
        resolve();
      }
    };
    pc.onicecandidate = (e) => {
      if (!e.candidate) {
        clearTimeout(timeout);
        resolve();
      }
    };
  });
}
```

---

## Creator Features

### 1. Audio Source Selection

The app supports three audio source configurations:

#### Microphone Only
```typescript
// Capture from specific device
const stream = await navigator.mediaDevices.getUserMedia({
  audio: {
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
    sampleRate: { ideal: 48000 },
    channelCount: { ideal: 1 },
    deviceId: { exact: selectedDeviceId }
  },
  video: false
});
```

#### System Audio Only
```typescript
// Capture system audio via screen sharing
const displayStream = await navigator.mediaDevices.getDisplayMedia({
  video: true,  // Required by browser
  audio: {
    echoCancellation: false,
    noiseSuppression: false,
    autoGainControl: false,
    sampleRate: { ideal: 48000 }
  }
});

// Extract only audio tracks
const audioTracks = displayStream.getAudioTracks();
const audioOnlyStream = new MediaStream(audioTracks);
```

#### Mixed Audio (Microphone + System)
```typescript
// Use Web Audio API to mix multiple streams
const audioCtx = new AudioContext();
const destination = audioCtx.createMediaStreamDestination();

const micSource = audioCtx.createMediaStreamSource(micStream);
const systemSource = audioCtx.createMediaStreamSource(systemStream);

micSource.connect(destination);
systemSource.connect(destination);

const mixedStream = destination.stream;
```

---

### 2. Microphone Device Selection

```typescript
// Get available audio input devices
const devices = await navigator.mediaDevices.enumerateDevices();
const audioInputs = devices.filter(d => d.kind === 'audioinput');

// Request permission and get devices
await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
const devices = await getAudioInputDevices();
```

---

### 3. Audio Visualizer

Real-time audio visualization using Web Audio API:

```typescript
function startVisualizer(stream: MediaStream, canvas: HTMLCanvasElement): () => void {
  const audioCtx = new AudioContext();
  const source = audioCtx.createMediaStreamSource(stream);
  const analyser = audioCtx.createAnalyser();
  analyser.fftSize = 256;
  analyser.smoothingTimeConstant = 0.75;
  source.connect(analyser);

  const bufferLength = analyser.frequencyBinCount;
  const dataArray = new Uint8Array(bufferLength);

  function draw() {
    requestAnimationFrame(draw);
    analyser.getByteFrequencyData(dataArray);

    // Draw frequency bars on canvas
    const ctx = canvas.getContext('2d');
    const W = canvas.width;
    const H = canvas.height;

    ctx.clearRect(0, 0, W, H);

    const barW = (W / bufferLength) * 2.2;
    let x = 0;
    for (let i = 0; i < bufferLength; i++) {
      const barH = (dataArray[i] / 255) * H;
      ctx.fillStyle = '#00e5a0';
      ctx.fillRect(x, H - barH, barW - 1, barH);
      x += barW;
    }
  }

  draw();

  return () => {
    cancelAnimationFrame(draw);
    audioCtx.close();
  };
}
```

---

### 4. Connection Quality Monitoring

Track WebRTC connection statistics:

```typescript
// Get stats every 1.5 seconds
setInterval(async () => {
  const stats = await pc.getStats();
  stats.forEach((r) => {
    if (r.type === 'outbound-rtp' && r.kind === 'audio') {
      const now = r.timestamp;
      const bytes = r.bytesSent;
      // Calculate bitrate (kbps)
      const dt = (Number(now) - lastTs) / 1000;
      const kbps = Math.round(((bytes - lastBytes) * 8) / dt / 1000);
    }
  });
}, 1500);
```

---

### 5. Stream Duration Counter

```typescript
let duration = 0;
const interval = setInterval(() => {
  duration += 1;
  // Format: HH:MM:SS or MM:SS
  const hrs = Math.floor(duration / 3600);
  const mins = Math.floor((duration % 3600) / 60);
  const secs = duration % 60;
}, 1000);
```

---

### 6. Real-Time Viewer Count

Polling approach (every 5 seconds):

```typescript
async function getViewerCount(slug: string, companyId: number) {
  const response = await fetch(
    `/livestream/${slug}/viewers/count?company_id=${companyId}`
  );
  return response.json();
}

// Poll every 5 seconds while streaming
setInterval(async () => {
  const stats = await getViewerCount(slug, companyId);
  setViewerCount(stats.viewer_count);
}, 5000);
```

---

### 7. Live Chat Integration

#### Fetch Messages (Polling every 5 seconds)

```typescript
async function fetchMessages(slug: string) {
  const response = await fetch(`/livestream-chat/${slug}/messages?page=1&size=50`);
  return response.json();
}

// Poll every 5 seconds
setInterval(async () => {
  const messages = await fetchMessages(slug);
  setMessages(messages);
}, 5000);
```

#### Send Message

```typescript
async function sendMessage(slug: string, content: string) {
  const response = await fetch(`/livestream-chat/${slug}/messages`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${access_token}`,
    },
    body: JSON.stringify({ content }),
  });
  return response.json();
}
```

---

### 8. Stream Recording (Client-Side)

Using MediaRecorder API:

```typescript
// Supported MIME types (in order of preference)
const MIME_TYPES = [
  'audio/mp4',
  'audio/x-m4a',
  'audio/webm;codecs=opus',
  'audio/webm',
  'audio/wav'
];

// Initialize recorder
const mediaRecorder = new MediaRecorder(stream, {
  mimeType: supportedMimeType
});

const chunks: Blob[] = [];
mediaRecorder.ondataavailable = (e) => {
  if (e.data.size > 0) {
    chunks.push(e.data);
  }
};

mediaRecorder.onstop = () => {
  const blob = new Blob(chunks, { type: mimeType });
  // Handle the recorded blob
};

// Start/stop recording
mediaRecorder.start(1000); // Collect data every second
mediaRecorder.stop();
```

---

### 9. Auto-Reconnection

Implements exponential backoff reconnection:

```typescript
const MAX_RECONNECT_ATTEMPTS = 5;
const RECONNECT_INTERVAL = 2000; // Base interval in ms

async function retryConnection() {
  for (let attempt = 1; attempt <= MAX_RECONNECT_ATTEMPTS; attempt++) {
    const delay = RECONNECT_INTERVAL * Math.pow(2, attempt - 1);

    await new Promise(resolve => setTimeout(resolve, delay));

    try {
      await startPublishing(stream, publishUrl);
      console.log('Reconnected successfully');
      return;
    } catch (err) {
      console.log(`Reconnection attempt ${attempt} failed`);
    }
  }

  console.log('Max reconnection attempts reached');
}

// Listen for ICE connection state changes
pc.oniceconnectionstatechange = () => {
  if (pc.iceConnectionState === 'failed' ||
      pc.iceConnectionState === 'disconnected') {
    retryConnection();
  }
};
```

---

### 10. Network Status Monitoring

```typescript
// Listen for online/offline events
window.addEventListener('online', () => {
  console.log('Network: Online');
  // Attempt reconnection
  retryConnection();
});

window.addEventListener('offline', () => {
  console.log('Network: Offline');
});
```

---

### 11. Active Stream Detection

Check for existing active streams on app launch:

```typescript
async function checkForActiveStream() {
  const response = await fetch('/livestreams?limit=50&offset=0', {
    headers: {
      'Authorization': `Bearer ${access_token}`,
    },
  });
  const streams = await response.json();

  // Filter to active streams
  const activeStreams = streams.filter(s => s.is_active);

  if (activeStreams.length > 0) {
    // Resume existing stream
    return activeStreams[0];
  }

  return null;
}
```

---

### 12. Thumbnail Upload

```typescript
async function uploadThumbnail(file: File) {
  const formData = new FormData();
  formData.append('title', streamTitle);
  formData.append('description', streamDescription);
  formData.append('thumbnail', file);

  const response = await fetch('/livestreams/start/audio', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${access_token}`,
    },
    body: formData,
  });

  return response.json();
}
```

---

## Connection States

| State | Description |
|-------|-------------|
| `idle` | Not connected |
| `connecting` | Establishing connection |
| `connected` | Successfully connected |
| `reconnecting` | Attempting to reconnect |
| `disconnected` | Connection closed |
| `failed` | Connection failed |

---

## Feature Implementation Checklist

### Pre-Stream
- [ ] User authentication (login/signup)
- [ ] Get access token and store securely
- [ ] Display stream title/description input
- [ ] Optional thumbnail upload
- [ ] Audio source selection UI
- [ ] Microphone device picker

### During Stream
- [ ] Start stream via API
- [ ] Capture audio (mic/system/mixed)
- [ ] Initialize WebRTC (WHIP protocol)
- [ ] Display audio visualizer
- [ ] Show connection quality indicator
- [ ] Track stream duration
- [ ] Poll viewer count (every 5s)
- [ ] Poll chat messages (every 5s)
- [ ] Optional: client-side recording
- [ ] Auto-reconnection on failure

### Post-Stream
- [ ] Stop stream via API
- [ ] Cleanup WebRTC connection
- [ ] Stop audio capture
- [ ] Optional: upload recording

---

## Mobile App Considerations

### Permissions Required
- Microphone (audio capture)
- Camera (for video streams - not implemented in current version)
- Screen recording (for system audio - Android 10+)

### Platform-Specific Notes

**Android:**
- Use `MediaProjection` API for system audio capture
- Handle background audio processing
- Use Foreground Service for reliable streaming

**iOS:**
- System audio capture not available (Safari WebRTC limitation)
- Use `AVAudioSession` for audio routing
- Handle interruptions (calls, other apps)

### Error Handling
- Network loss: Auto-reconnect with exponential backoff
- Permission denied: Show user-friendly message
- Stream failed: Clean up and allow retry

---

## API Client Example (TypeScript)

```typescript
class ApiClient {
  private baseUrl = 'https://api-dev.volantislive.com';

  private getToken(): string | null {
    return localStorage.getItem('access_token');
  }

  async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;

    const config: RequestInit = {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
    };

    const token = this.getToken();
    if (token) {
      config.headers = {
        ...config.headers,
        'Authorization': `Bearer ${token}`,
      };
    }

    const response = await fetch(url, config);

    if (!response.ok) {
      const error = await response.json();
      throw error;
    }

    const text = await response.text();
    return text ? JSON.parse(text) : null;
  }

  async requestFormData<T>(
    endpoint: string,
    data: FormData
  ): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    const token = this.getToken();

    const response = await fetch(url, {
      method: 'POST',
      body: data,
      headers: {
        ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
      },
    });

    const text = await response.text();
    return text ? JSON.parse(text) : null;
  }
}
```

---

## Summary

To implement creator streaming in a mobile app:

1. **Authenticate** the user and store the access token
2. **Start a stream** by calling the API to get publish URL
3. **Capture audio** from microphone or system audio
4. **Connect via WebRTC** using WHIP protocol
5. **Monitor** connection state, viewer count, and chat
6. **Handle reconnection** on network issues
7. **Stop the stream** via API when done
8. **Optionally record** and upload the stream

The key URLs from the API response are:
- `cf_webrtc_publish_url` - For WHIP publishing
- `cf_webrtc_playback_url` - For WHEP playback
- `slug` - For viewer count and chat endpoints