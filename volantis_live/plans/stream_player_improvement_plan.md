# Stream Player Improvement Plan

## Issues Identified

1. **Back button stops stream**: When user taps back arrow in AppBar, stream stops instead of minimizing to mini-player
2. **Missing play/pause button**: Full-screen player only has mute, refresh, and minimize controls
3. **WebRTC connection tied to screen**: The AudioWebRTCPlayer is created inside StreamPlayerScreen, so when screen is disposed, WebRTC connection stops

## Solution Architecture

### Current Flow (Broken)
```
User taps Back → Navigator.pop() → Stream stops ❌
```

### Target Flow (Fixed)
```
User taps Back → provider.minimize() → Navigator.pop() → Mini player shows → Stream continues ✅
```

## Changes Required

### 1. StreamPlayerScreen (volantis_live/lib/features/streams/presentation/screens/stream_player_screen.dart)

#### Change 1: Fix back button behavior
- **Location**: Line 135-138 (AppBar leading)
- **Current**: `onPressed: () => Navigator.pop(context)`
- **Change to**: `onPressed: _onBackPressed`

```dart
void _onBackPressed() {
  // Minimize the player instead of stopping it
  context.read<StreamsProvider>().minimize();
  Navigator.of(context).pop();
}
```

#### Change 2: Add play/pause button
- **Location**: Lines 340-373 (playback controls row)
- **Add**: Play/pause IconButton between mute and refresh buttons

```dart
IconButton(
  onPressed: () {
    final provider = context.read<StreamsProvider>();
    provider.togglePlayPause();
    setState(() {
      _isPlaying = provider.isPlaying;
    });
  },
  icon: Icon(
    _isPlaying ? Icons.pause : Icons.play_arrow,
    color: Colors.white,
  ),
  style: IconButton.styleFrom(
    backgroundColor: AppColors.primary.withOpacity(0.3),
  ),
),
```

### 2. LiveStreamMiniPlayer (volantis_live/lib/features/streams/presentation/widgets/live_stream_mini_player.dart)

The mini player already has the correct implementation:
- It uses `provider.togglePlayPause()` for play/pause
- It uses `provider.toggleMute()` for mute
- It uses `provider.closePlayer()` to stop the stream
- It properly checks `provider.isPlayerOpen` and `provider.currentStream`

**No changes needed** - this widget is already correct!

### 3. StreamsProvider (volantis_live/lib/features/streams/presentation/providers/streams_provider.dart)

The provider already has all required methods:
- `minimize()` - sets `isPlayerExpanded = false`
- `expand()` - sets `isPlayerExpanded = true`
- `togglePlayPause()` - toggles playing state
- `toggleMute()` - toggles mute state
- `closePlayer()` - stops stream and closes player

**No changes needed** - the provider is already correct!

### 4. MainScreen (volantis_live/lib/routes/main_screen.dart)

The main screen already shows the mini player when:
- `streamsProvider.hasActivePlayer` is true
- The mini player appears at bottom above navbar

**No changes needed** - this is already correct!

## Implementation Steps

1. **Modify StreamPlayerScreen**:
   - Add `_onBackPressed` method
   - Update AppBar leading to use `_onBackPressed`
   - Add play/pause button to controls row
   - Ensure state syncs with provider

2. **Test the flow**:
   - Open stream → Stream plays
   - Tap minimize → Mini player shows, stream continues
   - Tap back → Mini player shows, stream continues
   - Tap play/pause in full screen → Stream pauses/resumes
   - Tap play/pause in mini player → Stream pauses/resumes
   - Tap close in mini player → Stream stops

## Key Insight

The issue was that when the user taps back, the stream stops because:
1. The `StreamPlayerScreen` is popped from navigation
2. The `AudioWebRTCPlayer` widget is disposed
3. The WebRTC connection is closed

The fix ensures that:
1. Instead of just popping, we call `provider.minimize()` first
2. This sets `isPlayerExpanded = false` but keeps `isPlayerOpen = true`
3. The `LiveStreamMiniPlayer` in `main_screen.dart` shows because `hasActivePlayer` is true
4. The stream continues playing

However, there's still one issue: **The WebRTC connection is still tied to the screen lifecycle**. For true background playback (when app is minimized), the WebRTC logic would need to be moved to a service that persists. But for the use case described (minimizing to mini-player, not full app background), the current fix should work if we ensure the WebRTC player is not recreated unnecessarily.

Actually, looking more carefully at the code - the WebRTC connection IS tied to the screen. When the screen is popped, the connection will be closed. To truly fix this, we would need to either:
1. Keep the StreamPlayerScreen in the navigation stack but hidden
2. Extract WebRTC logic to a service

For now, the simplest fix is to ensure the mini-player can re-establish the connection if needed, or to restructure the navigation so the player screen doesn't get disposed.

Let me proceed with the implementation and see how it works in practice.
