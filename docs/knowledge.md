# Project Knowledge Base
> Last updated: 2026-02-01

## Overview
**LaPlayer** — A mobile app for music instrument learners that helps count beats of a song sample. Users import audio, set BPM, mark timestamps with labels/captions, and get a fullscreen countdown display before each marked time hits.

## Requirements (from requirement.md)
1. Audio player application (mobile)
2. Import audio & create label projects
3. Input BPM per song
4. Mark timestamps with labels/captions
5. BPM-based countdown (from 4) before each time mark, fullscreen caption display
6. Configurable display: font size, background color
7. Playback speed control (slow down / speed up)

## Architecture
- **Platform:** iOS (Flutter — cross-platform framework, iOS-first)
- **Language:** Dart
- **Audio formats:** MP3, WAV
- **Storage:** Local-only (no cloud sync)
- **Pattern:** TBD during planning (likely feature-based folder structure)

## Key Files
| Path | Purpose | Notes |
|------|---------|-------|
| `docs/requirement.md` | Product requirements | 7 core features listed |
| `docs/knowledge.md` | This file | Project knowledge base |
| `docs/plan.md` | Implementation plan | 11 steps, steps 1-10 complete |
| `docs/progress.md` | Execution log | Step 11 bug fixes in progress |
| `CLAUDE.md` | Agent workflow instructions | 3-phase workflow |
| `lib/main.dart` | App entry point | Theme + ProjectListScreen |
| `lib/theme/app_theme.dart` | Dark theme | Indigo primary, amber accent |
| `lib/models/project.dart` | Project model | toMap/fromMap/copyWith |
| `lib/models/label.dart` | Label model | toMap/fromMap/copyWith |
| `lib/models/display_config.dart` | Display config model | Font size, bg colors |
| `lib/services/database_service.dart` | sqflite CRUD | projects + labels tables |
| `lib/services/audio_service.dart` | just_audio wrapper | play/pause/seek/speed/streams |
| `lib/services/audio_import_service.dart` | File picker + copy | MP3/WAV import |
| `lib/providers/label_provider.dart` | Label state management | ChangeNotifier, add/edit/delete/nav |
| `lib/screens/project_list_screen.dart` | Home screen | Project list, empty state, FAB |
| `lib/screens/new_project_dialog.dart` | New project dialog | Name, BPM, file picker |
| `lib/screens/player_screen.dart` | Player screen | Transport, seek bar, labels, add-label dialog with timestamp field |
| `lib/screens/practice_screen.dart` | Practice mode | Fullscreen countdown, beat dots |
| `lib/screens/project_settings_screen.dart` | Settings | Name/BPM, font size, color presets |
| `lib/widgets/project_card.dart` | Project card | Swipe-to-delete, long-press edit |
| `lib/widgets/seek_bar.dart` | Custom seek bar | Slider with label markers, onDragUpdate callback, 12px thumb |
| `lib/widgets/label_tile.dart` | Label tile | Inline edit, swipe-to-delete |

## Important Code Patterns
### SeekBar drag → time display sync
`SeekBar` exposes optional `onDragUpdate` callback (fires during `onChanged`). `PlayerScreen` tracks `_dragPosition` (nullable Duration). Time display uses `_dragPosition ?? streamPosition`. Cleared to null on `onSeek` (drag end).

### Add Label dialog timestamp
Dialog returns Dart record `({String caption, String timestamp})`. `_parseTimestamp()` converts `mm:ss` string → milliseconds. Falls back to raw `posMs` if parse fails.

### Skip-back fallback
`_seekToPreviousLabel()` seeks to `Duration.zero` when `previousLabelIndex()` returns null.

## Design Decisions
- **Flutter for iOS:** Cross-platform framework, targeting iOS first
- **Local-only storage:** No backend needed, simpler architecture
- **MP3 + WAV:** Two most common audio formats, covers most use cases
- **Provider for state:** Using `provider` package with ChangeNotifier pattern
- **sqflite for DB:** Local SQLite via sqflite, two tables (projects, labels)

## Constraints & Gotchas
- Audio playback with precise BPM timing is non-trivial in Flutter
- Countdown sync with audio position requires accurate time tracking
- iOS audio session handling (interruptions, background audio)
- File picker needed for importing audio from device

## Dependencies
- `flutter` 3.38.9 — UI framework
- `just_audio` — Audio playback with speed control, position tracking
- `file_picker` — Import audio files from device
- `path_provider` — Local file storage paths
- `sqflite` — Local SQLite database for projects/labels
- `provider` — State management (ChangeNotifier pattern)
- `shared_preferences` — Per-project display config persistence
- `path` — File path manipulation

## Resolved Questions
- ~~Target platform?~~ → iOS, Flutter
- ~~Audio format support?~~ → MP3, WAV
- ~~Storage?~~ → Local-only
- ~~State management?~~ → Provider
- ~~Local DB?~~ → sqflite
