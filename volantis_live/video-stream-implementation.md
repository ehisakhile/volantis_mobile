# Video Stream Player Implementation Analysis

## Overview

The Next.js web application uses **WebRTC** (specifically **WHEP protocol**) to receive live video/audio streams from a server. The implementation is split between two files:
- `src/hooks/useWebRTC.ts` - Core WebRTC logic
- `src/app/[companySlug]/[streamSlug]/page.tsx` - UI layer

---

## Architecture

### Protocol: WHEP (WebRTC-HTTP Egress Protocol)

WHEP is the standard streaming protocol for WebRTC playback:
1. Client creates an SDP offer
2. Client sends POST request with offer to server
3. Server responds with SDP answer
4. ICE negotiation establishes peer-to-peer connection
5. Media tracks flow from server to client

### Key Components

```
Streamer → [RTMP/Ingest] → Server → [WHEP Endpoint] → Client (WebRTC)
```

---

## WebRTC Flow

### 1. Setup (useWebRTC.ts:349-450)

```typescript
// Create peer connection with optimized ICE config
const ICE_CONFIG = {
  iceServers: [
    { urls: 'stun:stun.cloudflare.com:3478' },
    { urls: 'stun:stun.l.google.com:19302' },
  ],
  iceTransportPolicy: 'all',
  bundlePolicy: 'max-bundle',  // Bundle audio+video on single transport
  rtcpMuxPolicy: 'require',    // Require RTCP muxing
};
```

### 2. Create MediaStream for incoming tracks

```typescript
// Stable MediaStream - never replaced, tracks added in-place
const incomingStream = new MediaStream();
setRemoteStream(incomingStream);

// Debounce state updates for batched audio+video track updates
let updatePending = false;
let pendingTimer: ReturnType<typeof setTimeout> | null = null;

const flushRemoteStream = () => {
  updatePending = false;
  clearTimeout(pendingTimer);
  setRemoteStream(new MediaStream(incomingStream.getTracks()));
};

// Handle incoming tracks
pc.ontrack = (event) => {
  const existing = incomingStream.getTracks().find(t => t.id === event.track.id);
  if (!existing) {
    incomingStream.addTrack(event.track);
  }
  if (pendingTimer) clearTimeout(pendingTimer);
  pendingTimer = setTimeout(flushRemoteStream, 0);
};
```

### 3. Create WHEP Offer

```typescript
// Add recvonly transceivers for both audio and video
pc.addTransceiver('video', { direction: 'recvonly' });
pc.addTransceiver('audio', { direction: 'recvonly' });

// Create offer
const offer = await pc.createOffer();

// Apply Opus optimization only for audio (don't break video codec negotiation)
const sdpWithAudio = preferOpus(offer.sdp || '');
await pc.setLocalDescription({ type: offer.type, sdp: sdpWithAudio });
```

### 4. WHEP Signaling - Send Offer, Receive Answer

```typescript
// Send SDP offer to server
const response = await fetch(url, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/sdp',
    'Accept': 'application/sdp',
  },
  body: localDescription.sdp,
});

const answerSDP = await response.text();

// Apply answer
await pc.setRemoteDescription({
  type: 'answer',
  sdp: answerSDP,
});
```

### 5. ICE Configuration (Opus Low-Latency)

```typescript
function preferOpus(sdp: string): string {
  const match = sdp.match(/a=rtpmap:(\d+) opus\/48000\/2/i);
  if (!match) return sdp;
  const pt = match[1];

  // Optimize Opus for low latency
  const opusFmtp = `a=fmtp:${pt} minptime=10;useinbandfec=1;stereo=0;maxaveragebitrate=96000`;
  // ... replace/append fmtp line
}
```

---

## Video Track Detection in UI

### Page Component (page.tsx:560-569)

```typescript
const [hasVideoTrack, setHasVideoTrack] = useState(false);

// Detect if remote stream has video tracks
useEffect(() => {
  if (remoteStream) {
    const videoTracks = remoteStream.getVideoTracks();
    setHasVideoTrack(videoTracks.length > 0);
    console.log('[StreamPage] Remote stream video tracks:', videoTracks.length);
  } else {
    setHasVideoTrack(false);
  }
}, [remoteStream]);
```

### VideoPlayerLayout Component (page.tsx:436-458)

```typescript
useEffect(() => {
  if (!remoteStream) { setHasVideoTracks(false); return; }
  const videoTracks = remoteStream.getVideoTracks();
  const has = videoTracks.length > 0;
  setHasVideoTracks(has);

  // Assign srcObject immediately when video track arrives
  if (has && videoRef.current && videoRef.current.srcObject !== remoteStream) {
    videoRef.current.srcObject = remoteStream;
    videoRef.current.muted = true; // start muted for autoplay policy
    videoRef.current.play().catch(err => {
      // Handle autoplay failure - try muted play
      videoRef.current!.muted = true;
      videoRef.current!.play();
    });
  }
}, [remoteStream]);
```

---

## Connection State Management

### State Types

```typescript
type ConnectionStatus = 'idle' | 'connecting' | 'connected' | 'reconnecting' | 'failed' | 'disconnected';

function mapIceConnectionState(state: RTCIceConnectionState): ConnectionStatus {
  switch (state) {
    case 'connected':
    case 'completed': return 'connected';
    case 'checking': return 'connecting';
    case 'disconnected': return 'reconnecting';
    case 'failed': return 'failed';
    case 'closed': return 'disconnected';
    default: return 'idle';
  }
}
```

### Auto-Play Flow

```typescript
// Video streams auto-start when playback URL is available
useEffect(() => {
  if (stream?.stream_type === 'video' && stream?.cf_webrtc_playback_url &&
      !autoPlayAttemptedRef.current && connectionState !== 'connected' &&
      connectionState !== 'connecting') {
    autoPlayAttemptedRef.current = true;
    setIsPlaying(true);
    startPlayback(stream.cf_webrtc_playback_url);
  }
}, [stream?.stream_type, stream?.cf_webrtc_playback_url]);
```

---

## Flutter Implementation Guide

### Required Packages

```yaml
dependencies:
  flutter_webrtc: ^0.12.0+cardinal
  http: ^1.2.0
```

### 1. Setup RTCPeerConnection

```dart
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoStreamService {
  RTCPeerConnection? _pc;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _renderer;

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.cloudflare.com:3478'},
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    'iceTransportPolicy': 'all',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
  };

  // Initialize renderer
  void initRenderer(RTCVideoRenderer renderer) async {
    _renderer = renderer;
    _remoteStream = await createLocalMediaStream('remote');
  }
}
```

### 2. Start Playback with WHEP

```dart
Future<void> startPlayback(String playbackUrl) async {
  // Create peer connection
  _pc = await createPeerConnection(_iceServers);

  // Set up remote stream
  _pc!.onTrack = (RTCTrackEvent event) async {
    if (event.streams.isNotEmpty) {
      _remoteStream = event.streams[0];
      await _renderer?.setSrcStream(_remoteStream!);
    } else {
      _remoteStream!.addTrack(event.track!);
      await _renderer?.setSrcStream(_remoteStream!);
    }
  };

  // Addrecvonly transceivers
  await _pc!.addTransceiver(
    track: null,
    kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
    streamId: _remoteStream!.id,
  );
  await _pc!.addTransceiver(
    track: null,
    kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
    streamId: _remoteStream!.id,
  );

  // Create offer
  RTCSessionDescription offer = await _pc!.createOffer();

  // Set local description
  await _pc!.setLocalDescription(offer);

  // Send offer to server (WHEP)
  final response = await http.post(
    Uri.parse(playbackUrl),
    headers: {
      'Content-Type': 'application/sdp',
      'Accept': 'application/sdp',
    },
    body: offer.sdp,
  );

  if (response.statusCode == 200) {
    // Apply answer from server
    await _pc!.setRemoteDescription(
      RTCSessionDescription(response.body, 'answer'),
    );
  }
}
```

### 3. Detect Video Tracks

```dart
void checkVideoTracks() {
  _remoteStream?.getVideoTracks().then((tracks) {
    bool hasVideo = tracks.isNotEmpty;
    // Update UI state
    // Show/hide video player based on hasVideo
  });
}
```

### 4. Handle Connection State

```dart
_pc!.onIceConnectionState = (RTCIceConnectionState state) {
  switch (state) {
    case RTCIceConnectionState.RTCIceConnectionStateConnected:
    case RTCIceConnectionState.RTCIceConnectionStateCompleted:
      // UI: Show "Connected" status
      break;
    case RTCIceConnectionState.RTCIceConnectionStateChecking:
      // UI: Show "Connecting..." status
      break;
    case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
    case RTCIceConnectionState.RTCIceConnectionStateFailed:
      // UI: Show "Reconnecting..." or auto-retry
      break;
    case RTCIceConnectionState.RTCIceConnectionStateClosed:
      // UI: Show "Disconnected" status
      break;
  }
};
```

### 5. Connection Recovery

```dart
bool _isManuallyStopped = false;

Future<void> retryConnection() async {
  if (_isManuallyStopped) return;
  await Future.delayed(Duration(seconds: 2));
  await startPlayback(_playbackUrl);
}

void stop() {
  _isManuallyStopped = true;
  _pc?.close();
  _pc = null;
  _remoteStream?.dispose();
  _remoteStream = null;
}
```

---

## Summary

| Aspect | Implementation |
|--------|----------------|
| **Protocol** | WHEP (WebRTC-HTTP Egress Protocol) |
| **Signaling** | HTTP POST with SDP offer/answer |
| **ICE** | STUN servers (Cloudflare, Google) |
| **Codec** | Opus for audio (low latency), H.264/VP8 for video |
| **Bundle** | max-bundle, rtcpMuxPolicy require |
| **Auto-play** | Muted by default, unmute on user interaction |
| **Track handling** | Stable MediaStream, debounced state updates |
| **Recovery** | Auto-reconnect on disconnect with exponential backoff |