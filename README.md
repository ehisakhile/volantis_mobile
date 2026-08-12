# Volantis Mobile — Creator Media, Telegram & Playlists API Reference

This document is the mirroring reference for implementing the following **already-deployed web features** in the Volantis mobile app:

1. **Upload recordings** (audio + video files) — creators upload pre-recorded media for on-demand playback.
2. **Telegram integration** — connect a Telegram account, import media from Telegram channels.
3. **Playlists** — create playlists, add uploaded recordings or imported Telegram media, and manage them (reorder, skip, remove, cover art, visibility, loop) — Spotify-style.
4. **Public playlist display** — how playlists are shown on the public channel page.
5. **Seamless audio/video playback** — how the playlist player auto-detects media type and plays tracks back-to-back.

Everything below maps 1:1 to endpoints already live on the backend, so the mobile app only needs to call these APIs.

---

## 1. Base Configuration

| Setting | Value |
|---------|-------|
| API Base URL (dev) | `https://api-dev.volantislive.com` |
| API Base URL (prod) | Overridable via `NEXT_PUBLIC_API_URL` — confirm the prod base with the backend team |
| Protocol | HTTPS / REST + JSON (multipart/form-data for uploads) |

---

## 2. Authentication

All endpoints below require a **Bearer token** except the ones explicitly marked **Public**.

```
Authorization: Bearer {access_token}
```

**Auth flow (login/signup/token refresh)** is already handled in the mobile app. The `access_token` comes from the existing auth session.

**Error shape** (non-2xx): the backend returns a JSON body, typically:

```json
{ "detail": "human readable error message" }
```

The web client parses this `detail` field for error messaging.

---

## 3. Feature 1 — Upload Recordings (Audio + Video)

Web source: `src/app/dashboard/upload-recording/page.tsx` and `src/lib/api/recordings.ts`

### 3.1 Permission Check (before showing upload UI)

**GET** `/api/subscriptions/can-upload`

**Authentication:** Required (creator / company user only — user must have `company_id`)

**Response:**
```json
{
  "allowed": true,
  "reason": ""
}
```

```typescript
interface PermissionCheckResponse {
  allowed: boolean;
  reason: string; // explains why upload is not allowed when allowed === false
}
```

The web app shows a `SubscriptionLimitModal` when `allowed === false`. Only creators (users with a `company_id`) may upload; viewers are redirected away.

### 3.2 Upload Recording

**POST** `/recordings/upload`

**Authentication:** Required

**Content-Type:** `multipart/form-data`

**Form fields:**

| Field             | Type   | Required | Description |
|-------------------|--------|----------|-------------|
| `file`            | binary | Yes      | The audio/video file (see allowed types below) |
| `title`           | string | Yes      | Title (max 100 chars) |
| `description`     | string | No       | Description (max 500 chars) |
| `duration_seconds`| int    | Yes      | Media duration in whole seconds (detected from file metadata client-side) |
| `thumbnail`       | binary | No       | Cover image (JPEG/PNG/WebP, max 10 MB) |

**Allowed file types (client-side validation in web app):**

| Media type | MIME types | Max size |
|------------|-----------|----------|
| Audio | `audio/mpeg`, `audio/mp3`, `audio/wav`, `audio/ogg`, `audio/webm`, `audio/m4a` | 500 MB |
| Video | `video/mp4`, `video/webm`, `video/quicktime` (MOV) | 500 MB |
| Thumbnail | `image/jpeg`, `image/jpg`, `image/png`, `image/webp` | 10 MB |

**Response:**
```json
{
  "id": 12,
  "company_id": 3,
  "livestream_id": null,
  "title": "Sunday Sermon",
  "description": "Full recording",
  "s3_url": "https://cdn.volantislive.com/recordings/company-3/xxx.mp3",
  "streaming_url": "https://cdn.volantislive.com/recordings/company-3/xxx.mp3",
  "duration_seconds": 3600,
  "file_size_bytes": 10485760,
  "is_processed": true,
  "thumbnail_url": "https://cdn.volantislive.com/thumbnails/xxx.jpg",
  "created_at": "2026-01-01T12:00:00Z",
  "replay_count": 0
}
```

```typescript
interface VolRecordingOut {
  id: number;
  company_id: number;
  company_slug?: string | null;
  company_name?: string | null;
  company_logo_url?: string | null;
  livestream_id: number | null;
  title: string;
  description: string | null;
  s3_url: string;
  streaming_url: string;
  duration_seconds: number | null;
  file_size_bytes: number;
  is_processed: boolean;
  thumbnail_url: string | null;
  created_at: string;
  replay_count?: number;
}
```

### 3.3 Duration Detection (client-side)

Before upload, the web app reads the file's duration from the loaded `metadata` event of an `<audio>`/`<video>` element and floors it to whole seconds. On mobile, use your platform's media-info/metadata API (e.g. `MediaInfo`, `video_player`, or ffprobe) to obtain `durationSeconds`.

---

## 4. Feature 2 — Telegram Integration

Web source: `src/app/dashboard/integrations/page.tsx`, `src/app/dashboard/integrations/telegram/[connectionId]/page.tsx`, and `src/lib/api/telegram.ts`

Flow: **Start auth (phone) → Verify code (choose channel) → Connect channel → Browse/import media**.

### 4.1 Start Authentication (send code)

**POST** `/telegram/start`

**Authentication:** Required

**Request:**
```json
{ "phone": "+2348012345678" }
```

**Response:**
```json
{
  "session_id": "abc-123",
  "phone_number": "+2348012345678",
  "requires_password": false,
  "message": "Code sent"
}
```

```typescript
interface TelegramStartAuthRequest { phone: string; }
interface TelegramStartAuthResponse {
  session_id: string;
  phone_number?: string;
  requires_password?: boolean;
  message?: string;
}
```

### 4.2 Verify Code → Get Available Channels

**POST** `/telegram/verify`

**Request:**
```json
{ "session_id": "abc-123", "code": "54321", "phone": "+2348012345678" }
```

**Response:**
```json
{
  "phone_number": "+2348012345678",
  "channels": [
    { "id": 1, "title": "My Channel", "username": "mychannel", "type": "channel" }
  ]
}
```

```typescript
interface TelegramVerifyCodeRequest { session_id: string; code: string; phone?: string; }
interface TelegramChannel {
  id: number;
  title: string;
  username: string | null;
  type: string;
}
interface TelegramVerifyCodeResponse {
  phone_number: string;
  channels: TelegramChannel[];
}
```

UI: the web app shows a picker over `channels`; if empty, shows "No channels found for this account".

### 4.3 Connect Channel

**POST** `/telegram/connect`

**Request:**
```json
{ "channel_id": 1, "session_id": "abc-123" }
```

**Response:**
```json
{
  "id": 5,
  "company_id": 3,
  "telegram_channel_id": 1,
  "channel_title": "My Channel",
  "channel_username": "mychannel",
  "is_active": true,
  "last_sync_at": null,
  "created_at": "2026-01-01T12:00:00Z"
}
```

```typescript
interface TelegramConnectRequest { channel_id: number; session_id: string; }
interface TelegramConnection {
  id: number;
  company_id: number;
  telegram_channel_id: number;
  channel_title: string;
  channel_username: string | null;
  is_active: boolean;
  last_sync_at: string | null;
  created_at: string;
}
```

### 4.4 List Connections

**GET** `/telegram/connections`

**Response:**
```json
{ "connections": [ /* TelegramConnection[] */ ] }
```

### 4.5 Disconnect Channel

**DELETE** `/telegram/connection/{connectionId}`

**Authentication:** Required — returns 204/no body.

### 4.6 Import Media (background jobs)

**POST** `/telegram/{connectionId}/import-history` — import up to `limit` recent media messages.

Request: `{ "limit": 100 }` (optional). Response:

```json
{
  "status": "started",
  "imported_count": 0,
  "failed_count": 0,
  "message": "Import started"
}
```

**POST** `/telegram/{connectionId}/import-new` — import media since last sync (no body).

```typescript
interface TelegramImportStatusResponse {
  status: 'started' | 'completed' | 'failed';
  imported_count: number;
  failed_count: number;
  message?: string;
}
```

These are **async/background** — the UI just shows a success toast; refresh the media list after a short delay.

### 4.7 List Imported Media (per connection)

**GET** `/telegram/{connectionId}/media?limit=50&offset=0`

**Response:**
```json
{
  "media": [
    {
      "id": 77,
      "connection_id": 5,
      "telegram_message_id": 100,
      "telegram_message_link": "https://t.me/mychannel/100",
      "file_name": "podcast_episode.mp3",
      "s3_url": "https://cdn.volantislive.com/telegram/xxx.mp3",
      "media_type": "audio",
      "status": "completed",
      "duration_seconds": 2430,
      "file_size_bytes": 10485760,
      "caption": "Episode 12",
      "telegram_upload_date": "2026-01-01T12:00:00Z",
      "created_at": "2026-01-01T12:05:00Z"
    }
  ],
  "total": 1
}
```

```typescript
interface TelegramMediaItem {
  id: number;
  connection_id: number;
  telegram_message_id: number;
  telegram_message_link: string | null;
  file_name: string;
  s3_url: string;
  media_type: 'audio' | 'video' | 'voice' | 'document';
  status: 'pending' | 'processing' | 'completed' | 'failed';
  duration_seconds: number | null;
  file_size_bytes: number;
  caption: string | null;
  telegram_upload_date: string;
  created_at: string;
}
interface TelegramMediaListResponse { media: TelegramMediaItem[]; total: number; }
```

**Only items with `status === 'completed'` and `media_type` in `audio | video | voice` are addable to playlists.**

### 4.8 List Raw Channel Media (directly from Telegram)

**GET** `/telegram/{connectionId}/channel-media?limit=50&offset=0`

Used for the "Telegram Channel" tab — shows messages in the channel and whether each is already imported.

**Response:**
```json
{
  "media": [
    {
      "message_id": 100,
      "message_date": "2026-01-01T12:00:00Z",
      "media_type": "audio",
      "duration_seconds": 2430,
      "caption": "Episode 12",
      "file_name": "podcast_episode.mp3",
      "file_size": 10485760,
      "is_imported": false,
      "imported_media_id": null
    }
  ],
  "total": 1,
  "connection_id": 5
}
```

```typescript
interface TelegramChannelMediaItem {
  message_id: number;
  message_date: string;
  media_type: string | null;
  duration_seconds: number | null;
  caption: string | null;
  file_name: string | null;
  file_size: number | null;
  is_imported: boolean;
  imported_media_id: number | null;
}
```

### 4.9 Import a Single Media Message

**POST** `/telegram/{connectionId}/import-media/{messageId}`

No body. Import the specific channel message. Refresh imported media afterward.

### 4.10 All Imported Telegram Media (company-wide, used by the playlist "add media" picker)

**GET** `/telegram/media?limit=100&offset=0`

**Response:**
```json
{
  "media": [ /* TelegramMediaItem[] across all connections */ ],
  "total": 1,
  "company_id": 3
}
```

```typescript
interface TelegramMediaByCompanyResponse {
  media: TelegramMediaItem[];
  total: number;
  company_id: number;
}
```

---

## 5. Feature 3 — Playlists (Create, Manage, Add Media)

Web source: `src/lib/api/playlists.ts`, `src/app/dashboard/integrations/page.tsx`, `src/app/dashboard/integrations/playlists/[playlistId]/page.tsx`, and `src/app/dashboard/integrations/telegram/[connectionId]/page.tsx`

Playlists are **unified**: a single playlist can mix `recording` media (creator uploads) and `telegram` media (imported from Telegram). Playlists can contain **both audio and video** items.

### 5.1 Core Types

```typescript
interface PlaylistOut {
  id: number;
  company_id: number;
  name: string;
  description: string | null;
  cover_image_url: string | null;
  category_ids: number[] | null;
  is_active: boolean;          // public (true) vs hidden (false)
  loop_enabled: boolean;       // repeat playlist when finished
  livestream_id: number | null;
  current_media_type: string | null;
  current_media_id: number | null;
  playback_position: number | null;
  media_count: number;         // total items in the playlist
  created_at: string;
}

interface PlaylistResponse {
  playlist: PlaylistOut;
  message: string;
}

interface PlaylistMediaItemOut {
  id: number;                  // playlist_media id (pmId) — used for reorder/skip/remove
  playlist_id: number;
  position: number;            // 1-based order in playlist
  is_skipped: boolean;         // excluded from public playback queue
  media_type: 'recording' | 'telegram';
  media_id: number;            // id of the underlying recording or telegram media
  title: string | null;
  description: string | null;
  thumbnail_url: string | null;
  duration_seconds: number | null;
  s3_url: string | null;       // playback source (preferred)
  streaming_url: string | null;
  media_subtype: string | null; // e.g. 'audio' | 'video' | 'voice' (from telegram)
  caption: string | null;
  file_name: string | null;
  category_ids: number[] | null;
  created_at: string | null;
}

interface PlaylistMediaListResponse {
  playlist_id: number;
  media: PlaylistMediaItemOut[];
  total: number;
}
```

### 5.2 List Playlists (creator dashboard)

**GET** `/playlists?limit=50&offset=0` → `PlaylistOut[]`

### 5.3 Create Playlist

**POST** `/playlists`

**Authentication:** Required

**Request:**
```json
{
  "name": "Sunday Worship Mix",
  "description": "Weekly sermon collection",
  "loop_enabled": true,
  "is_active": true
}
```

**Response:**
```json
{
  "playlist": { /* PlaylistOut */ },
  "message": "Playlist created"
}
```

```typescript
interface PlaylistCreateRequest {
  name: string;
  description?: string;
  loop_enabled?: boolean;
  livestream_id?: number;
  is_active?: boolean;
}
```

**Flow in web UI:** after creating from a Telegram context, the app optionally bulk-adds the currently selected media IDs to the new playlist in one step (see §5.8).

### 5.4 Get / Update / Delete Playlist

| Method | Endpoint | Notes |
|--------|----------|-------|
| GET | `/playlists/{playlistId}` | → `PlaylistOut` |
| PUT | `/playlists/{playlistId}` | → `PlaylistResponse` |
| DELETE | `/playlists/{playlistId}` | 204/no body. Deleting a playlist does **not** delete the media |

**PUT request (all optional):**
```typescript
interface PlaylistUpdateRequest {
  name?: string;
  description?: string | null;
  loop_enabled?: boolean;
  livestream_id?: number | null;
  is_active?: boolean;           // toggle public/hidden
  cover_image_url?: string | null;
}
```

### 5.5 Upload Cover Image

**PUT** `/playlists/{playlistId}/cover-image`

**Content-Type:** `multipart/form-data` — field `cover_image` (JPEG/PNG/WebP). → `PlaylistResponse`

### 5.6 Get Playlist Media

**GET** `/playlists/{playlistId}/media` → `PlaylistMediaListResponse`

### 5.7 Add a Single Media Item

**POST** `/playlists/{playlistId}/media`

**Request:**
```json
{ "media_type": "telegram", "media_id": 77 }
```

```json
{ "media_type": "recording", "media_id": 12, "position": 1 }
```

**Response:** `PlaylistResponse`

```typescript
interface PlaylistMediaAddRequest {
  media_type: 'recording' | 'telegram';
  media_id: number;        // recording.id OR telegram media id
  position?: number;
}
```

### 5.8 Bulk Add Media Items (used everywhere)

**POST** `/playlists/{playlistId}/media/bulk`

**Request:**
```json
{
  "media_items": [
    { "media_type": "telegram", "media_id": 77 },
    { "media_type": "recording", "media_id": 12 }
  ]
}
```

**Response:** `PlaylistResponse`

```typescript
interface PlaylistMediaBulkAddRequest {
  media_items: { media_type: 'recording' | 'telegram'; media_id: number }[];
}
```

This is the primary endpoint for "Add selected media to playlist". The web "Add Media" modal loads **recordings** via `GET /recordings?limit=100&offset=0` and **telegram media** via `GET /telegram/media?limit=100&offset=0` (company-wide), then bulk-adds both selections together. Items already in the playlist are shown greyed-out (keyed by `"recording:{id}"` / `"telegram:{id}"`).

### 5.9 Reorder Media (move up/down — Spotify-style)

**PUT** `/playlists/{playlistId}/media/order`

**Request:** full ordered list with new 1-based positions
```json
{
  "items": [
    { "id": 5, "position": 1 },
    { "id": 8, "position": 2 },
    { "id": 3, "position": 3 }
  ]
}
```

**Response:** `PlaylistMediaListResponse` (re-ordered media list)

```typescript
interface PlaylistReorderItem { id: number; position: number; }
```

### 5.10 Update a Media Item (skip / position)

**PATCH** `/playlists/{playlistId}/media/{pmId}`

`pmId` is the `PlaylistMediaItemOut.id` (not the underlying media id).

**Request:**
```json
{ "is_skipped": true }
```

```typescript
interface PlaylistMediaUpdateRequest { position?: number; is_skipped?: boolean; }
```

**Response:** `PlaylistMediaListResponse`

Skipped items are excluded from the public playback queue (§7).

### 5.11 Remove Media from Playlist

**DELETE** `/playlists/{playlistId}/media/{pmId}` — 204/no body. Does not delete the underlying media.

---

## 6. Feature 4 — Public Channel Page (Playlist Display)

Web source: `src/app/[companySlug]/page.tsx`

### 6.1 Fetch Public Playlists

**GET** `/playlists/public/company/{companySlug}?limit=50&offset=0` → `PlaylistOut[]`

**Public** — no auth. Only `is_active === true` playlists are returned.

### 6.2 Display Pattern (web)

- Section titled **"Playlists"** with a count badge.
- Each playlist is a **card**:
  - Background: `cover_image_url` as a full-bleed image (opacity ~80%, darkened), otherwise a violet/purple→fuchsia gradient.
  - Overlay content: playlist `name`, `description` (1 line clamp), `media_count` ("N tracks"), and a **"Loop"** badge if `loop_enabled`.
  - Hover reveals a centered play button; the whole card navigates to `/{companySlug}/playlist/{playlistId}`.
- Loading state shows skeleton cards (3).

Also on the same page (for parity): **Recordings** section fetched via `GET /recordings/public/company/{slug}?limit=50&offset=0`, each card tagged **Audio** or **Video** by inspecting the recording's `s3_url` file extension (§7.2).

---

## 7. Feature 5 — Seamless Audio/Video Playback

Web source: `src/app/[companySlug]/playlist/[playlistId]/page.tsx`

### 7.1 Load Playlist + Media (parallel, public)

**GET** `/playlists/public/{playlistId}` → `PlaylistOut`
**GET** `/playlists/public/{playlistId}/media` → `PlaylistMediaListResponse`

Both are **public** (no auth) and are fetched together with `Promise.all`.

**Playback queue** = `media.filter(item => !item.is_skipped)`, sorted by `position`.

### 7.2 Video vs Audio Detection (important!)

Media type is **NOT** determined by a `stream_type` field — it is determined **solely by the file extension of `s3_url`**:

```typescript
const VIDEO_EXTENSIONS = ['mp4', 'm4v', 'mov', 'mkv', 'avi'];

function isVideoUrl(url?: string | null): boolean {
  if (!url) return false;
  // take the pathname, lowercase, get extension after last '.'
  return VIDEO_EXTENSIONS.includes(extension);
}
```

Usage: `isVideoRecording({ s3_url: item.s3_url })`. Anything not matching is treated as **audio**.

### 7.3 Playback Source URL

Source is `item.s3_url || item.streaming_url` (web prefers `s3_url`). 

> **Media proxy:** the web app routes playback through a same-origin `/media-proxy?url=...` wrapper to avoid cross-origin range-request/CORS issues with S3/CDN. **The mobile app already handles proxying/streaming natively, so this requirement is skipped here.**

### 7.4 Player Behaviour (seamless, Spotify-like)

- Render **VideoPlayer** when `isVideoItem(item)` is true, otherwise **AudioPlayer**.
- Both players are given the media URL, the `thumbnail_url` as poster/artwork, and the title; both start with `autoPlay` when selected.
- Events wired up:
  - `onPlay` → mark track as playing (animated equalizer bars on the active row).
  - `onPause` → mark track as paused.
  - `onEnded` → advance automatically:
    1. If more items remain → play `currentIndex + 1`.
    2. Else if `playlist.loop_enabled === true` → wrap to index `0`.
    3. Else → stop and reset to the first track.
- Selecting a track in the list plays it immediately at that index.
- UI list shows per item: position number / play icon (or animated bars while active), thumbnail (or an icon: `Music` for telegram audio/voice, `Film` otherwise), title, `media_type` + audio/video label, and formatted `duration_seconds` (`H:MM:SS`).

### 7.5 Duration Formatting

```typescript
function formatDuration(seconds: number | null): string {
  if (!seconds || seconds <= 0) return '0:00';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) return `${h}:${m}:${s}`;  // padded
  return `${m}:${s}`;                  // padded
}
```

---

## 8. Supporting Recording Endpoints (used in the mobile mirror)

From `src/lib/api/recordings.ts`:

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/recordings?limit&offset` | Yes | List current company's recordings (used in "Add Media" picker) |
| GET | `/recordings/{recordingId}` | Yes | Get one recording |
| GET | `/recordings/public/{recordingId}` | Yes | Playback fetch — returns `VolRecordingWithReplayOut`, **increments replay count** |
| GET | `/recordings/public/{recordingId}/stats` | No | Stats for UI display: `{ recording_id, replay_count, unique_viewers, average_watch_duration_seconds, completion_rate }` |
| GET | `/recordings/public/company/{companySlug}?limit&offset` | No | Public recordings list |
| POST | `/recordings/{recordingId}/complete` | Yes | Mark recording completed |
| POST | `/recordings/{recordingId}/position?position_seconds={n}` | Yes | Save watch position (call every ~10s) |
| GET | `/recordings/my/watch-history?status=&limit&offset` | Yes | Watch history |
| GET | `/recordings/my/watching?limit&offset` | Yes | In-progress recordings |
| GET | `/recordings/my/watched?limit&offset` | Yes | Completed recordings |
| DELETE | `/recordings/{recordingId}` | Yes | Delete (admin) |

```typescript
interface VolRecordingWithReplayOut extends VolRecordingOut {
  stream_type: 'audio_only' | 'video' | null;
  replay_count: number;
  watch_status: { status: 'in_progress' | 'completed' | 'not_started'; last_position: number | null; completed_at: string | null } | null;
}
```

---

## 9. Implementation Checklist for the Mobile App

1. **Upload flow:** check `GET /api/subscriptions/can-upload` → pick audio/video file (allowed MIME list, 500 MB cap) → detect duration → `multipart/form-data` POST `/recordings/upload` (optional thumbnail) → show success with returned `VolRecordingOut`.
2. **Telegram:** implement 3-step modal (phone → code → channel picker) using `/telegram/start`, `/telegram/verify`, `/telegram/connect`. List connections via `/telegram/connections`. Trigger `/import-history` or `/import-new` (async), browse imported media via `/telegram/{connectionId}/media`, and browse raw channel media via `/telegram/{connectionId}/channel-media` (single import via `/import-media/{messageId}`).
3. **Playlists (creator):** `GET /playlists`, `POST /playlists`, `PUT /playlists/{id}`, `DELETE /playlists/{id}`, `PUT /playlists/{id}/cover-image`. Manage items via `GET/POST/PUT/PATCH/DELETE /playlists/{id}/media...` (add single, bulk add, reorder, skip, remove).
4. **Public display:** `GET /playlists/public/company/{slug}` cards → navigate to playlist page.
5. **Playback:** load `GET /playlists/public/{id}` + `GET /playlists/public/{id}/media` in parallel; build queue excluding `is_skipped`; detect video via `s3_url` extension; render video/audio player; auto-advance on ended with `loop_enabled` wrap; provide a track list with active-state indicators and durations.

---

## 10. File Reference (where these live in the web app)

| Concern | Web file |
|---------|----------|
| Upload page | `src/app/dashboard/upload-recording/page.tsx` |
| Recordings API + types | `src/lib/api/recordings.ts`, `src/types/livestream.ts` |
| Telegram integration page | `src/app/dashboard/integrations/page.tsx` |
| Telegram channel media page | `src/app/dashboard/integrations/telegram/[connectionId]/page.tsx` |
| Telegram API + types | `src/lib/api/telegram.ts` |
| Playlist manage page | `src/app/dashboard/integrations/playlists/[playlistId]/page.tsx` |
| Playlists API + types | `src/lib/api/playlists.ts` |
| Public channel page (playlist display) | `src/app/[companySlug]/page.tsx` |
| Public playlist playback page | `src/app/[companySlug]/playlist/[playlistId]/page.tsx` |
| Video/audio detection helper | `src/lib/media.ts` |
