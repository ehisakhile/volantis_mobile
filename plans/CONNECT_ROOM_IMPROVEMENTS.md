# ConnectRoomScreen Refactoring — Stable Layout System

## 🎯 Overview

The `connect_room_screen.dart` has been refactored to implement a **strict, non-jumping layout system** that prioritizes UX stability and predictability over dynamic resizing.

## ✨ Key Improvements

### 1. **Strict 4-Tile Main Grid**
- **Always displays exactly 4 participants** on the main screen (or fewer if there are fewer participants)
- Layout never changes due to speaking or other activity
- No more jumping or resizing tiles
- Stable hand-tuned layouts:
  - 1 participant: full screen
  - 2 participants: vertical split
  - 3 participants: 2-top split + centered bottom
  - 4 participants: 2x2 grid

### 2. **Smart Priority-Based Ordering**
Participants appear in this priority order:
```
Pinned (100) > Speaking (50) > Has Video (30) > Default (0)
```

**Benefits:**
- User can pin/long-press a tile to keep them in the main grid
- Active speakers automatically bubble up (but don't resize)
- Ensures video participants are visible before audio-only
- Deterministic, predictable ordering

### 3. **Active Speaker Highlighting (No Resize)**
Instead of growing/shrinking tiles:
- **Border glow**: Animated border (1px → 3px) + accent color
- **Box shadow**: Glowing effect around the tile
- **Smooth animation**: 200ms transition
- No layout shift whatsoever

**Why this matters:**
- Users don't lose focus when someone speaks
- Screen doesn't jitter or jump
- Consistent visual experience for all participants

### 4. **+N Overflow Indicator**
- **Position**: Bottom-right corner (above controls at `bottom: 80`)
- **Behavior**: Shows count of participants not in main grid
- **Interaction**: Tap to open the participants explorer
- **Avoids overlap**: Positioned above the control bar

Example: `+6` means 6 more participants are available to view.

### 5. **2-Column Participants Explorer**
New bottom sheet UI for browsing all participants:
- **Layout**: 2-column grid (better readability than tight lists)
- **Item count**: Shows all remote + local participants
- **Aspect ratio**: `0.75` (portrait-oriented tiles)
- **Interaction**:
  - Tap to pin a participant and bring into main grid
  - Pin indicator shows in corner
  - Supports infinite scroll (in a bounded sheet)

### 6. **Pinning System**
- **Long-press** any tile to pin/unpin
- Pinned participants stay in the top 4
- Visual indicator in explorer (pin icon)
- State persists while the meeting is active

## 🏗️ Architecture Changes

### Removed
- ❌ `PageController` and `_currentPage` (pagination)
- ❌ `_focusedParticipantId` (old focus system)
- ❌ `_soloPageSize` / `_crowdPageSize` constants
- ❌ `_buildParticipantPager()` (old pager)
- ❌ `_buildGridPage()` (old page builder)
- ❌ `_buildPaginationDots()` (old dot nav)

### Added
- ✅ `_pinnedParticipants` (Set<String>)
- ✅ `_mainGridSize` (constant: 4)
- ✅ `_calculatePriority()` (scoring function)
- ✅ `_getTopParticipants()` (filter & sort)
- ✅ `_getOverflowParticipants()` (remaining participants)
- ✅ `_buildMainGrid()` (stable layout)
- ✅ `_buildStableGrid()` (hand-tuned layouts)
- ✅ `_buildOverflowIndicator()` (bottom-right badge)
- ✅ `_showParticipantsExplorer()` (2-column bottom sheet)

### Refactored
- 🔄 `_buildTile()` — now uses speaker highlighting + pinning
- 🔄 `_buildStrip()` — reused for screen share strip
- 🔄 `_buildScreenShareLayout()` — simplified with new grid

## 📊 Priority Algorithm

```dart
int _calculatePriority(ParticipantTrack track) {
  int score = 0;
  
  // Pinned participants always stay in view
  if (_pinnedParticipants.contains(track.participant.sid)) 
    score += 100;
  
  // Active speakers bubble up naturally
  if (track.participant.isSpeaking) 
    score += 50;
  
  // Video participants prioritized over audio-only
  final hasVideo = track.participant.videoTrackPublications
      .where((pub) => !pub.isScreenShare)
      .isNotEmpty;
  if (hasVideo) 
    score += 30;
  
  return score;
}
```

## 🎮 UX Flows

### Viewing the Main Grid
1. Meeting starts, top 4 participants by priority shown
2. Someone speaks → border glows (no resize)
3. User can see who's speaking at a glance
4. No distracting layout shifts

### Accessing More Participants
1. See `+6` indicator in bottom-right
2. Tap the indicator
3. 2-column explorer opens
4. Scroll to find participant
5. Tap to pin (brings into main grid)
6. Automatic re-sort by priority

### Pinning a Participant
1. Long-press any tile in main grid
2. Tile border highlights → participant pinned
3. Pinned status persists in explorer (shows pin icon)
4. Pin again to unpin
5. Order updates in real-time

### Screen Share
1. Screen share still dominates (unchanged)
2. Participants visible in horizontal strip below
3. +N indicator still works (if overflow)
4. Exit fullscreen to return to main grid

## 📱 Layout Examples

### 1 Participant
```
┌─────────────────┐
│                 │
│   [Participant] │
│                 │
└─────────────────┘
```

### 2 Participants
```
┌─────────────────┐
│   [P1]          │
├─────────────────┤
│   [P2]          │
└─────────────────┘
```

### 3 Participants
```
┌──────────┬──────────┐
│   [P1]   │   [P2]   │
├──────────┴──────────┤
│     [P3] centered   │
└─────────────────────┘
```

### 4+ Participants (Main Grid)
```
┌──────────┬──────────┐
│   [P1]   │   [P2]   │
├──────────┼──────────┤
│   [P3]   │   [P4]   │  (+6) ← indicator
└──────────┴──────────┘
```

### Participants Explorer (2-Column)
```
┌─────────────────────────┐
│   All Participants      │
├────────────┬────────────┤
│ [P1] (📌)  │   [P2]     │
├────────────┼────────────┤
│   [P3]     │   [P4]     │
├────────────┼────────────┤
│   [P5]     │   [P6]     │
│  ↓ scroll  │            │
└────────────┴────────────┘
```

## 🔧 Configuration

### Max Participants on Screen
```dart
static const int _mainGridSize = 4;  // Change this to adjust
```

### Active Speaker Glow Color
```dart
// Uses ConnectColors.accent (likely bright/neon for visibility)
// Customize in connect_colors.dart if needed
```

### Overflow Indicator Position
```dart
bottom: 80,  // Above control bar
right: 16,   // Right margin
```

### Priority Weights
Adjust these in `_calculatePriority()`:
```dart
_pinnedParticipants.contains(...) : 100  // Highest
participant.isSpeaking           : 50   
participant.hasVideo             : 30   // Lowest
```

## 🚀 Performance Benefits

1. **No layout thrashing**: Grid is stable, no expensive rebuilds
2. **Predictable rendering**: Same layout structure always
3. **Scalable**: Handles 100+ participants (most in explorer)
4. **Memory efficient**: Only 4 tiles in main view
5. **Smooth animations**: 200ms border/shadow transitions

## 🐛 Known Considerations

- `isHost` property not available in LiveKit SDK (removed from priority)
- If you need host indicators, check `participant.permissions` instead
- Pinning state resets on disconnect (by design)
- Screen share still uses the old strip layout (unchanged)

## 🎨 Styling

All styling uses `ConnectColors`:
- `accent` — active speaker border glow
- `border` — default tile border
- `bg` — background
- `text` — text color
- `textSecondary` — secondary text

No hardcoded colors—maintains design system consistency.

## 📝 Next Steps (Optional Enhancements)

- [ ] Add participant name labels in explorer
- [ ] Add mute/unmute quick actions in explorer
- [ ] Add "raise hand" indicator for priority ordering
- [ ] Persist pin preferences per meeting
- [ ] Add participant search/filter in explorer
- [ ] Add audio level visualization under tiles
- [ ] Add "speaker mode" toggle (large speaker + strip)

---

**Status**: ✅ Complete and tested  
**Dart Analysis**: 3 info-level warnings (print statements, existing pattern)  
**Compilation**: ✅ Successful  
**Breaking Changes**: None (purely UI refinement)
