---
name: volantis-recordings-player
description: >
  Integrates a full podcast-style recordings player into a Volantis Flutter mobile app channel page.
  Use this skill whenever the user wants to add recordings, past streams, audio playback, podcast
  features, watch history, replay counts, or any "listen again" / "recorded streams" functionality
  to a Volantis Flutter channel page. Also trigger when the user asks to build a recordings list,
  a full-screen audio player, a mini-player bottom bar, or anything involving the
  /recordings/public/company/{slug} or /recordings/stream/{id} APIs in Flutter/Dart.
  This skill covers: listing recordings with pagination, a full-screen immersive player widget,
  seek/scrub support, periodic position tracking, replay counting, completion marking,
  and watch history — all implemented in Flutter with Dart.
---

# Volantis Recordings Player — Flutter Skill

Build a sleek, podcast-quality recordings section into an existing Volantis Flutter channel page.
Target feel: Spotify / Pocket Casts — dark, immersive, smooth animations.

---

## Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  just_audio: ^0.9.40          # Audio playback + seeking + speed control
  audio_session: ^0.1.21       # Handles audio focus (calls, other apps)
  cached_network_image: ^3.3.1 # Thumbnail caching with fallback
  dio: ^5.4.0                  # HTTP client (already likely present)
  provider: ^6.1.2             # State management (or use your existing solution)
  intl: ^0.19.0                # Date formatting
```

Run `flutter pub get` after adding.

---

## Design System

Match the existing app's dark theme. Use `Theme.of(context)` tokens — never hardcode colors.

| Role | Flutter token |
|---|---|
| Background | `Theme.of(context).scaffoldBackgroundColor` |
| Surface card | `Theme.of(context).colorScheme.surface` |
| Primary accent | `Theme.of(context).colorScheme.primary` |
| On-surface text | `Theme.of(context).colorScheme.onSurface` |
| Muted text | `Theme.of(context).colorScheme.onSurfaceVariant` |

Use `BorderRadius.circular(16)` for cards, `BorderRadius.circular(24)` for player sheet,
`BorderRadius.circular(999)` for pill buttons.

---

## API Reference

**Base URL:** `https://api-dev.volantislive.com`

### 1. List Recordings (paginated)
```
GET /recordings/public/company/{companySlug}?limit=20&offset=0
```
Returns `List<Recording>`. Key nullable fields: `thumbnail_url`, `duration_seconds`.

### 2. Fetch Single Recording ← **increments replay_count**
```
GET /recordings/public/{id}
```
Call this when the user taps a recording to open the player. Returns full object + `replay_count`, `watch_status`.

### 3. Replay Stats (no side effect)
```
GET /recordings/public/{id}/stats
```
Returns `{ id, title, replay_count, is_processed, created_at }`. Use to show play counts on cards.

### 4. Stream Audio ← **use as audio source**
```
GET /recordings/stream/{id}
```
Proxies S3, supports HTTP Range requests (seeking). **Always use `streaming_url` as the audio src, never `s3_url` directly.**

### 5. Update Position (auth required)
```
POST /recordings/{id}/position?position_seconds={seconds}
Authorization: Bearer {token}
```
Call every 30–60 seconds during playback and on pause/close.

### 6. Mark Complete (auth required)
```
POST /recordings/{id}/complete
Authorization: Bearer {token}
```
Call when playback reaches ≥ 90% of `duration_seconds`.

### 7. Watch History (auth required)
```
GET /recordings/my/watch-history?limit=50&offset=0
GET /recordings/my/watched?limit=50&offset=0
Authorization: Bearer {token}
```
Returns `{ watch_history: [...], total }`. Each item has `status`, `last_position`, `recording_duration`.

---

## Data Models

```dart
// lib/models/recording.dart

class Recording {
  final int id;
  final int companyId;
  final int? livestreamId;
  final String title;
  final String? description;
  final String s3Url;
  final String streamingUrl;   // e.g. "/recordings/stream/28"
  final int? durationSeconds;
  final int? fileSizeBytes;
  final bool isProcessed;
  final String? thumbnailUrl;
  final DateTime createdAt;
  // Only from single-fetch endpoint:
  final int? replayCount;
  final String? watchStatus;  // null | "watching" | "completed"

  const Recording({
    required this.id,
    required this.companyId,
    this.livestreamId,
    required this.title,
    this.description,
    required this.s3Url,
    required this.streamingUrl,
    this.durationSeconds,
    this.fileSizeBytes,
    this.isProcessed = true,
    this.thumbnailUrl,
    required this.createdAt,
    this.replayCount,
    this.watchStatus,
  });

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
    id: json['id'],
    companyId: json['company_id'],
    livestreamId: json['livestream_id'],
    title: json['title'] ?? 'Untitled',
    description: json['description'],
    s3Url: json['s3_url'] ?? '',
    streamingUrl: json['streaming_url'] ?? '',
    durationSeconds: json['duration_seconds'],
    fileSizeBytes: json['file_size_bytes'],
    isProcessed: json['is_processed'] ?? false,
    thumbnailUrl: json['thumbnail_url'],
    createdAt: DateTime.parse(json['created_at']),
    replayCount: json['replay_count'],
    watchStatus: json['watch_status'],
  );
}

class WatchHistoryItem {
  final int recordingId;
  final String recordingTitle;
  final String? recordingThumbnail;
  final int? recordingDuration;
  final String status; // "watching" | "completed"
  final int lastPosition;
  final DateTime? completedAt;
  final DateTime updatedAt;

  const WatchHistoryItem({
    required this.recordingId,
    required this.recordingTitle,
    this.recordingThumbnail,
    this.recordingDuration,
    required this.status,
    required this.lastPosition,
    this.completedAt,
    required this.updatedAt,
  });

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) => WatchHistoryItem(
    recordingId: json['recording_id'],
    recordingTitle: json['recording_title'] ?? 'Untitled',
    recordingThumbnail: json['recording_thumbnail'],
    recordingDuration: json['recording_duration'],
    status: json['status'] ?? 'watching',
    lastPosition: json['last_position'] ?? 0,
    completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
    updatedAt: DateTime.parse(json['updated_at']),
  );
}
```

---

## API Service

```dart
// lib/services/recordings_service.dart
import 'package:dio/dio.dart';

class RecordingsService {
  static const _base = 'https://api-dev.volantislive.com';
  final Dio _dio;
  final String? _authToken;

  RecordingsService(this._dio, {String? authToken}) : _authToken = authToken;

  Options get _authOptions => Options(
    headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : {},
  );

  // 1. List recordings with pagination
  Future<List<Recording>> getRecordings(String companySlug, {int limit = 20, int offset = 0}) async {
    final res = await _dio.get(
      '$_base/recordings/public/company/$companySlug',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return (res.data as List).map((j) => Recording.fromJson(j)).toList();
  }

  // 2. Fetch single recording (increments replay count — call on player open)
  Future<Recording> getRecording(int id) async {
    final res = await _dio.get('$_base/recordings/public/$id');
    return Recording.fromJson(res.data);
  }

  // 3. Stats only (no side effect)
  Future<Map<String, dynamic>> getStats(int id) async {
    final res = await _dio.get('$_base/recordings/public/$id/stats');
    return res.data;
  }

  // 5. Update position
  Future<void> updatePosition(int id, int positionSeconds) async {
    if (_authToken == null) return;
    await _dio.post(
      '$_base/recordings/$id/position',
      queryParameters: {'position_seconds': positionSeconds},
      options: _authOptions,
    );
  }

  // 6. Mark complete
  Future<void> markComplete(int id) async {
    if (_authToken == null) return;
    await _dio.post('$_base/recordings/$id/complete', options: _authOptions);
  }

  // 7. Watch history
  Future<List<WatchHistoryItem>> getWatchHistory({int limit = 50, int offset = 0}) async {
    final res = await _dio.get(
      '$_base/recordings/my/watch-history',
      queryParameters: {'limit': limit, 'offset': offset},
      options: _authOptions,
    );
    final list = res.data['watch_history'] as List;
    return list.map((j) => WatchHistoryItem.fromJson(j)).toList();
  }
}
```

---

## State Management — RecordingsProvider

```dart
// lib/providers/recordings_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class RecordingsProvider extends ChangeNotifier {
  final RecordingsService _service;
  final AudioPlayer _player = AudioPlayer();

  List<Recording> recordings = [];
  bool isLoadingList = false;
  bool hasMore = true;
  int _offset = 0;
  static const _limit = 20;

  Recording? currentRecording;
  bool isPlayerOpen = false;
  bool isFullScreen = true;
  bool isCompleted = false;

  Timer? _positionTimer;
  static const _positionInterval = Duration(seconds: 30);

  RecordingsProvider(this._service) {
    _initAudioSession();
    _player.playerStateStream.listen(_onPlayerState);
    _player.positionStream.listen(_onPosition);
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }

  // --- List ---
  Future<void> loadRecordings(String companySlug, {bool refresh = false}) async {
    if (refresh) { recordings = []; _offset = 0; hasMore = true; }
    if (isLoadingList || !hasMore) return;
    isLoadingList = true;
    notifyListeners();

    final batch = await _service.getRecordings(companySlug, limit: _limit, offset: _offset);
    recordings.addAll(batch);
    _offset += batch.length;
    hasMore = batch.length == _limit;
    isLoadingList = false;
    notifyListeners();
  }

  // --- Player ---
  Future<void> openRecording(int id) async {
    // Fetch single recording — this call increments replay_count
    final recording = await _service.getRecording(id);
    currentRecording = recording;
    isPlayerOpen = true;
    isFullScreen = true;
    isCompleted = false;
    notifyListeners();

    const base = 'https://api-dev.volantislive.com';
    final url = recording.streamingUrl.startsWith('http')
        ? recording.streamingUrl
        : '$base${recording.streamingUrl}';

    await _player.setUrl(url);
    await _player.play();
    _startPositionTimer();
  }

  void minimize() { isFullScreen = false; notifyListeners(); }
  void expand()   { isFullScreen = true;  notifyListeners(); }

  void closePlayer() {
    _savePosition();
    _player.stop();
    _positionTimer?.cancel();
    isPlayerOpen = false;
    currentRecording = null;
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    _player.playing ? await _player.pause() : await _player.play();
    if (!_player.playing) _savePosition();
  }

  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> skipBack(int seconds) async =>
      _player.seek((_player.position - Duration(seconds: seconds))
          .clamp(Duration.zero, _player.duration ?? Duration.zero));
  Future<void> skipForward(int seconds) async =>
      _player.seek(_player.position + Duration(seconds: seconds));
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> markComplete() async {
    if (currentRecording == null || isCompleted) return;
    await _service.markComplete(currentRecording!.id);
    isCompleted = true;
    notifyListeners();
  }

  // Expose streams to UI
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration>  get positionStream      => _player.positionStream;
  Stream<Duration?> get durationStream      => _player.durationStream;
  bool     get isPlaying => _player.playing;
  Duration get position  => _player.position;
  Duration? get duration => _player.duration;

  // --- Internal ---
  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(_positionInterval, (_) => _savePosition());
  }

  void _savePosition() {
    if (currentRecording == null) return;
    _service.updatePosition(currentRecording!.id, _player.position.inSeconds);
  }

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      isCompleted = true;
      _service.markComplete(currentRecording!.id);
      _positionTimer?.cancel();
      notifyListeners();
    }
  }

  void _onPosition(Duration pos) {
    final dur = currentRecording?.durationSeconds;
    if (dur != null && dur > 0 && !isCompleted) {
      if (pos.inSeconds >= (dur * 0.9).toInt()) markComplete();
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}
```

---

## UI Widgets

### RecordingsSection (embed in channel page)

```dart
// lib/widgets/recordings_section.dart

class RecordingsSection extends StatefulWidget {
  final String companySlug;
  const RecordingsSection({required this.companySlug, super.key});

  @override
  State<RecordingsSection> createState() => _RecordingsSectionState();
}

class _RecordingsSectionState extends State<RecordingsSection> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordingsProvider>().loadRecordings(widget.companySlug);
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<RecordingsProvider>().loadRecordings(widget.companySlug);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingsProvider>(
      builder: (context, provider, _) {
        if (provider.recordings.isEmpty && provider.isLoadingList) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: provider.recordings.length + (provider.hasMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            if (i >= provider.recordings.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return RecordingCard(
              recording: provider.recordings[i],
              onTap: () {
                provider.openRecording(provider.recordings[i].id);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ChangeNotifierProvider.value(
                    value: provider,
                    child: const FullScreenPlayerSheet(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
```

### RecordingCard

```dart
class RecordingCard extends StatelessWidget {
  final Recording recording;
  final VoidCallback onTap;
  const RecordingCard({required this.recording, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Thumbnail or fallback
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56, height: 56,
                child: recording.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: recording.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _IconFallback(),
                      )
                    : _IconFallback(),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recording.title,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(recording.createdAt)} · ${_formatDuration(recording.durationSeconds)}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (recording.replayCount != null) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.play_circle_outline, size: 12, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${recording.replayCount} plays',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _IconFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.primary.withOpacity(0.1),
      child: Center(child: Icon(Icons.radio, color: scheme.primary)),
    );
  }
}
```

### FullScreenPlayerSheet

```dart
class FullScreenPlayerSheet extends StatelessWidget {
  const FullScreenPlayerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Consumer<RecordingsProvider>(
      builder: (context, provider, _) {
        final recording = provider.currentRecording;
        if (recording == null) return const SizedBox.shrink();

        return Scaffold(
          backgroundColor: scheme.background,
          body: Stack(
            children: [
              // Ambient glow behind artwork
              Positioned(
                top: MediaQuery.of(context).size.height * 0.15,
                left: -80,
                child: Container(
                  width: 350, height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withOpacity(0.12),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    // Header row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down),
                            onPressed: () {
                              provider.minimize();
                              Navigator.pop(context);
                            },
                          ),
                          Text('Now Playing',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(letterSpacing: 2, color: scheme.onSurfaceVariant)),
                          IconButton(
                            icon: const Icon(Icons.more_horiz),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),

                    // Artwork
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: recording.thumbnailUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: recording.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _AnimatedWaveformArt(),
                                )
                              : _AnimatedWaveformArt(),
                        ),
                      ),
                    ),

                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            recording.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                            textAlign: TextAlign.center,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          if (recording.replayCount != null)
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.play_circle_outline, size: 14, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text('${recording.replayCount} plays',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: scheme.onSurfaceVariant)),
                            ]),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Seek bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: StreamBuilder<Duration>(
                        stream: provider.positionStream,
                        builder: (context, snapshot) {
                          final pos = snapshot.data ?? Duration.zero;
                          final dur = provider.duration
                              ?? Duration(seconds: recording.durationSeconds ?? 0);
                          final progress = dur.inMilliseconds > 0
                              ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                              : 0.0;

                          return Column(children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              ),
                              child: Slider(
                                value: progress.toDouble(),
                                onChanged: (v) => provider.seek(
                                    Duration(milliseconds: (v * dur.inMilliseconds).toInt())),
                              ),
                            ),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(_formatDuration(pos.inSeconds),
                                  style: Theme.of(context).textTheme.bodySmall),
                              Text(_formatDuration(recording.durationSeconds),
                                  style: Theme.of(context).textTheme.bodySmall),
                            ]),
                          ]);
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Playback controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_15),
                          iconSize: 32,
                          onPressed: () => provider.skipBack(15),
                        ),
                        StreamBuilder<PlayerState>(
                          stream: provider.playerStateStream,
                          builder: (context, snapshot) {
                            final playing = snapshot.data?.playing ?? false;
                            return GestureDetector(
                              onTap: provider.togglePlayPause,
                              child: Container(
                                width: 72, height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: scheme.primary,
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.primary.withOpacity(0.4),
                                      blurRadius: 24,
                                    )
                                  ],
                                ),
                                child: Icon(
                                  playing ? Icons.pause : Icons.play_arrow,
                                  size: 36, color: scheme.onPrimary,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_30),
                          iconSize: 32,
                          onPressed: () => provider.skipForward(30),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Secondary actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ActionButton(icon: Icons.share_outlined, label: 'Share', onTap: () {}),
                          _SpeedButton(provider: provider),
                          _ActionButton(
                            icon: provider.isCompleted
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            label: 'Done',
                            color: provider.isCompleted ? scheme.primary : null,
                            onTap: provider.markComplete,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Icon(icon, color: color ?? scheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _SpeedButton extends StatefulWidget {
  final RecordingsProvider provider;
  const _SpeedButton({required this.provider});

  @override
  State<_SpeedButton> createState() => _SpeedButtonState();
}

class _SpeedButtonState extends State<_SpeedButton> {
  final _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  int _idx = 1;

  void _cycle() {
    setState(() => _idx = (_idx + 1) % _speeds.length);
    widget.provider.setSpeed(_speeds[_idx]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _cycle,
      child: Column(children: [
        Text('${_speeds[_idx]}×',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: _idx != 1 ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            )),
        const SizedBox(height: 4),
        Text('Speed',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}
```

### MiniPlayer (persistent bar)

Show at the bottom of the channel page when `isPlayerOpen && !isFullScreen`:

```dart
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingsProvider>(
      builder: (context, provider, _) {
        if (!provider.isPlayerOpen || provider.isFullScreen) return const SizedBox.shrink();
        final recording = provider.currentRecording!;
        final scheme = Theme.of(context).colorScheme;
        final dur = recording.durationSeconds ?? 1;

        return GestureDetector(
          onTap: () {
            provider.expand();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => ChangeNotifierProvider.value(
                value: provider,
                child: const FullScreenPlayerSheet(),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surface.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 40, height: 40,
                      child: recording.thumbnailUrl != null
                          ? CachedNetworkImage(imageUrl: recording.thumbnailUrl!, fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: scheme.primary.withOpacity(0.2),
                                child: Icon(Icons.radio, color: scheme.primary, size: 20)))
                          : Container(
                              color: scheme.primary.withOpacity(0.2),
                              child: Icon(Icons.radio, color: scheme.primary, size: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(recording.title,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  StreamBuilder<PlayerState>(
                    stream: provider.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return IconButton(
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        onPressed: provider.togglePlayPause,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: provider.closePlayer,
                  ),
                ]),
                const SizedBox(height: 6),
                // Progress bar
                StreamBuilder<Duration>(
                  stream: provider.positionStream,
                  builder: (context, snapshot) {
                    final pos = snapshot.data?.inSeconds ?? 0;
                    final progress = (pos / dur).clamp(0.0, 1.0);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress.toDouble(),
                        minHeight: 2,
                        backgroundColor: scheme.onSurface.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(scheme.primary),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

### AnimatedWaveformArt (fallback artwork)

```dart
class _AnimatedWaveformArt extends StatefulWidget {
  @override
  State<_AnimatedWaveformArt> createState() => _AnimatedWaveformArtState();
}

class _AnimatedWaveformArtState extends State<_AnimatedWaveformArt>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _heights = List.generate(20, (i) => 0.2 + (i % 5) * 0.15);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      color: primary.withOpacity(0.08),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_heights.length, (i) {
            final h = (_heights[i] + _ctrl.value * _heights[(i + 3) % _heights.length] * 0.5)
                .clamp(0.05, 0.9);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FractionallySizedBox(
                heightFactor: h,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
}
```

---

## Wiring into the Channel Page

```dart
// In your channel page — wrap with ChangeNotifierProvider
@override
Widget build(BuildContext context) {
  return ChangeNotifierProvider(
    create: (_) => RecordingsProvider(
      RecordingsService(dio, authToken: authToken), // pass your dio + token
    ),
    child: Scaffold(
      body: Stack(
        children: [
          // Existing channel page content + RecordingsSection as a tab or section
          RecordingsSection(companySlug: channel.slug),

          // Mini player floats above bottom nav
          Positioned(
            bottom: bottomNavHeight,
            left: 0, right: 0,
            child: const MiniPlayer(),
          ),
        ],
      ),
    ),
  );
}
```

---

## Utilities

```dart
String _formatDuration(int? seconds) {
  if (seconds == null) return '—';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '$h:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  return '$m:${s.toString().padLeft(2,'0')}';
}

String _formatDate(DateTime dt) {
  return DateFormat('MMM d').format(dt); // requires intl package
}
```

---

## Checklist

Before delivering:
- [ ] `pubspec.yaml` updated with `just_audio`, `audio_session`, `cached_network_image`, `intl`
- [ ] `RecordingsProvider` registered above the channel page in the widget tree
- [ ] `openRecording()` calls `/recordings/public/{id}` first (increments replay_count)
- [ ] Audio src uses `streamingUrl`, prepending base URL if it starts with `/`
- [ ] Position timer fires every 30s, only while audio is playing
- [ ] Auto-complete fires at ≥ 90% of `duration_seconds` (guard against null duration)
- [ ] `duration_seconds: null` → shows `'—'`, no division by zero in progress calc
- [ ] `thumbnail_url: null` → `_IconFallback` or `_AnimatedWaveformArt` shown
- [ ] `.webm` thumbnail URLs have `errorWidget` fallback in `CachedNetworkImage`
- [ ] MiniPlayer only visible when `isPlayerOpen && !isFullScreen`
- [ ] `closePlayer()` cancels timer and saves position before stopping audio
- [ ] Auth token `null` check in `RecordingsService` — position/complete silently skip if unauthenticated
- [ ] Pagination scroll listener loads more when near bottom, `hasMore` flag prevents over-fetching
- [ ] `AudioSession` configured so playback pauses for calls and resumes correctly