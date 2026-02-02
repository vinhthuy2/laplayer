# Implementation Plan — Iteration 2
> Created: 2026-02-01 (revised: anchor timestamp + millisecond-precision timestamps)
> Goal: Fix practice mode bugs, add per-label color, improve label editing, fix seek bar with BPM-quantized grid anchored to a user-set beat reference, millisecond-precision timestamps, platform enhancements

## Summary
Address 7 bugs, 2 change requests, and 3 major enhancements found during device testing. Key additions: (1) **millisecond-precision timestamps** (`mm:ss.SSS`) throughout all display and input, (2) an **anchor timestamp** per project so the BPM grid aligns with the actual music. Work is grouped into 10 steps ordered by dependency.

## Millisecond Timestamp Format
- **Display format:** `mm:ss.SSS` (e.g., `01:23.456`)
- **Affected locations (current → new):**
  | Location | File | Current |
  |----------|------|---------|
  | Time display (player) | `player_screen.dart:_formatDuration()` | `mm:ss` |
  | Timestamp parse (player) | `player_screen.dart:_parseTimestamp()` | `mm:ss` |
  | Add Label dialog pre-fill | `player_screen.dart:_addLabel()` | `mm:ss` |
  | Label tile subtitle | `label_tile.dart:_formatTimestamp()` | `mm:ss` |
  | Practice waiting state | `practice_screen.dart` line 225 | `mm:ss` |
  | Anchor display (settings) | `project_settings_screen.dart` (new) | `mm:ss` |
- **Shared helper:** Create a top-level utility to avoid duplicating format/parse logic

## Anchor Timestamp Concept
- **What:** A per-project timestamp (in ms) marking where a known beat falls in the audio
- **Default:** 0 (assumes beat 1 at start of file)
- **Beat grid formula:** `beatN = anchorMs + n × (60000 / BPM)` for all integers n (including negative)
- **Snap-to-beat:** `nearestBeat = anchor + round((timestamp - anchor) / beatInterval) × beatInterval`
- **Set by user:** In player screen, tap a "Set Anchor" button to capture current playback position; or type a value in project settings

## Steps

### Step 1: Millisecond-precision timestamp utilities
- **File(s):** `lib/utils/time_format.dart` (new), `lib/screens/player_screen.dart`, `lib/widgets/label_tile.dart`, `lib/screens/practice_screen.dart`
- **Action:** Create + Modify
- **Details:**
  - **Create `lib/utils/time_format.dart`:**
    ```dart
    /// Format milliseconds as "mm:ss.SSS"
    String formatTimestamp(int ms) {
      final totalSeconds = ms ~/ 1000;
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      final millis = ms % 1000;
      return '${minutes.toString().padLeft(2, '0')}:'
             '${seconds.toString().padLeft(2, '0')}.'
             '${millis.toString().padLeft(3, '0')}';
    }

    /// Format Duration as "mm:ss.SSS"
    String formatDuration(Duration d) {
      return formatTimestamp(d.inMilliseconds);
    }

    /// Parse "mm:ss.SSS" or "mm:ss" back to milliseconds. Returns null on failure.
    int? parseTimestamp(String text) {
      final match = RegExp(r'^(\d+):(\d{1,2})(?:\.(\d{1,3}))?$').firstMatch(text);
      if (match == null) return null;
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final millisStr = (match.group(3) ?? '0').padRight(3, '0');
      final millis = int.parse(millisStr);
      return (minutes * 60 + seconds) * 1000 + millis;
    }
    ```
  - **Migrate `player_screen.dart`:**
    - Remove `_formatDuration()` and `_parseTimestamp()` methods
    - Import `../utils/time_format.dart`
    - Replace `_formatDuration(pos)` → `formatDuration(pos)`
    - Replace `_formatDuration(dur)` → `formatDuration(dur)`
    - Replace `_parseTimestamp(...)` → `parseTimestamp(...)`
    - Replace `_formatDuration(posDuration)` in `_addLabel()` → `formatTimestamp(posMs)`
  - **Migrate `label_tile.dart`:**
    - Remove `_formatTimestamp()` method
    - Import `../utils/time_format.dart`
    - Replace `_formatTimestamp(widget.label.timestampMs)` → `formatTimestamp(widget.label.timestampMs)`
  - **Migrate `practice_screen.dart`:**
    - Import `../utils/time_format.dart`
    - In waiting state (line ~214-225), replace manual `mm:ss` formatting with `formatDuration(pos)`
- **Complexity:** Low
- **Risk:** Low — pure refactor, no behavior change beyond adding milliseconds
- **Dependencies:** None

### Step 2: Data model changes — Label color + Project anchor
- **File(s):** `lib/models/label.dart`, `lib/models/project.dart`, `lib/services/database_service.dart`
- **Action:** Modify
- **Details:**
  - **label.dart:** Add `int? colorValue` field (nullable, stores ARGB int like `0xFFFF0000`)
    - Add to constructor, toMap, fromMap, copyWith
    - Add helper getter: `Color get color => Color(colorValue ?? 0xFFFFC107)` (default = amber accent)
    - Add import for `package:flutter/material.dart`
    - Define preset colors list as a constant:
      - Amber `0xFFFFC107`, Red `0xFFF44336`, Blue `0xFF2196F3`, Green `0xFF4CAF50`, Purple `0xFF9C27B0`, Orange `0xFFFF9800`, Cyan `0xFF00BCD4`, Pink `0xFFE91E63`
  - **project.dart:** Add `int anchorTimestampMs` field (default `0`)
    - Add to constructor (with default value `0`), toMap, fromMap, copyWith
    - fromMap: `map['anchorTimestampMs'] as int? ?? 0` (handles NULL from migration)
  - **database_service.dart:** Bump DB version 1 → 2
    - Add `onUpgrade` callback to `openDatabase()`
    - Migration v1→v2:
      ```sql
      ALTER TABLE labels ADD COLUMN colorValue INTEGER;
      ALTER TABLE projects ADD COLUMN anchorTimestampMs INTEGER NOT NULL DEFAULT 0;
      ```
- **Complexity:** Low
- **Risk:** Medium — DB migration must handle existing rows gracefully
- **Dependencies:** None

### Step 3: Update LabelProvider with full label editing
- **File(s):** `lib/providers/label_provider.dart`
- **Action:** Modify
- **Details:**
  - Add `updateLabel(int labelId, {int? timestampMs, String? caption, int? colorValue})` method
    - Finds label by id, applies non-null fields via copyWith, saves to DB, re-sorts list, notifyListeners
  - Update `addLabel()` signature to accept optional `int? colorValue` parameter
    - Pass through to Label constructor
  - Existing `updateCaption()` can delegate to new `updateLabel()` or remain for backwards compat
- **Complexity:** Low
- **Risk:** Low
- **Dependencies:** Step 2

### Step 4: Add beat-grid utility
- **File(s):** `lib/utils/beat_grid.dart` (new file)
- **Action:** Create
- **Details:**
  - Pure utility class, no Flutter dependency needed:
    ```dart
    class BeatGrid {
      final double bpm;
      final int anchorMs;

      BeatGrid({required this.bpm, required this.anchorMs});

      double get beatIntervalMs => 60000.0 / bpm;

      /// Snap a timestamp to the nearest beat
      int snapToBeat(int timestampMs) {
        final interval = beatIntervalMs;
        final offset = timestampMs - anchorMs;
        return anchorMs + (offset / interval).round() * interval.round();
      }

      /// Get beat number relative to anchor (0 = anchor beat, negative = before)
      int beatNumber(int timestampMs) {
        return ((timestampMs - anchorMs) / beatIntervalMs).floor();
      }

      /// Get all beat positions between startMs and endMs
      List<int> beatsInRange(int startMs, int endMs) {
        final interval = beatIntervalMs;
        final firstBeat = anchorMs + ((startMs - anchorMs) / interval).ceil() * interval.round();
        final beats = <int>[];
        for (var ms = firstBeat; ms <= endMs; ms = (ms + interval).round()) {
          beats.add(ms);
        }
        return beats;
      }
    }
    ```
  - Used by: SeekBar (tick marks), Player (label snapping), Practice (countdown alignment)
- **Complexity:** Low
- **Risk:** Low
- **Dependencies:** None

### Step 5: Fix Practice screen — auto-play, timestamp, start-over, BPM countdown
- **File(s):** `lib/screens/practice_screen.dart`
- **Action:** Modify
- **Details:**
  - **Bug 6 — Auto-play:** In `initState()`, after `_loadDisplayConfig()`:
    ```dart
    if (!widget.audioService.isPlaying) {
      widget.audioService.play();
    }
    ```
  - **Bug 7 — Show timestamp:** Add timestamp display in bottom bar between speed and exit.
    Use `StreamBuilder<Duration>` on `widget.audioService.positionStream` to show `mm:ss.SSS` via `formatDuration()` (from Step 1) in monospace white70.
  - **Bug 8 — Start-over:** Add restart icon button in bottom bar. `onTap`:
    ```dart
    widget.audioService.seek(Duration.zero);
    ```
  - **Bug 9 — BPM countdown:** Current logic already uses `_beatInterval` based on BPM. Verify countdown ticks once per beat. The existing formula `beatsElapsed = (elapsed / beatIntervalMs).floor()` is correct. If the countdown feels wrong, the issue may be that `_beatInterval` doesn't account for the anchor — the countdown start should be aligned to the beat grid:
    ```dart
    // Instead of: countdownStartMs = label.timestampMs - 4 * beatIntervalMs
    // Use beat grid to find the 4th beat before the label
    final grid = BeatGrid(bpm: widget.project.bpm, anchorMs: widget.project.anchorTimestampMs);
    ```
    The countdown should start at the beat grid position 4 beats before the label's timestamp.
- **Complexity:** Medium
- **Risk:** Low
- **Dependencies:** Steps 1, 4

### Step 6: Practice screen — per-label color + background flash
- **File(s):** `lib/screens/practice_screen.dart`
- **Action:** Modify
- **Details:**
  - **Bug 12 — Color starts at timestamp:** In `_computeState()`, the caption state should use the label's `colorValue` for background. Currently uses project-level `_bgColor`. Change to return the active label's color.
  - **CR — Per-label color in practice mode:**
    - `PracticeState.caption` → label's color as background
    - `PracticeState.countdown` → upcoming label's color (dimmed/darkened) as background
    - `PracticeState.waiting` → project default `_bgColor`
  - **CR — Background flash on countdown:**
    - Compute fractional beat position within current beat:
      ```dart
      final beatFraction = (elapsed % beatIntervalMs) / beatIntervalMs;
      ```
    - Use `beatFraction` to interpolate: flash bright at 0.0, fade to dim by 0.3, stay dim until 1.0
    - `Color.lerp(brightColor, dimColor, (beatFraction / 0.3).clamp(0.0, 1.0))`
    - No AnimationController needed — driven purely by stream position
  - Refactor `_computeState` return value to a named class:
    ```dart
    class PracticeDisplayState {
      final PracticeState state;
      final int beat;
      final int beatsElapsed;
      final double beatFraction; // 0.0–1.0 within current beat
      final String caption;
      final String nextCaption;
      final Color bgColor;
    }
    ```
- **Complexity:** High
- **Risk:** Medium — flash timing must feel musical
- **Dependencies:** Steps 2, 4

### Step 7: Label editing dialog (timestamp, color, caption)
- **File(s):** `lib/widgets/label_tile.dart`, `lib/screens/player_screen.dart`
- **Action:** Modify
- **Details:**
  - **label_tile.dart:**
    - Add `onEdit` callback (`VoidCallback`) for long-press
    - Show label color as the leading dot: `Icon(Icons.circle, color: widget.label.color)` instead of `AppColors.accent`
    - Remove inline `_editing` state — all editing moves to dialog
    - Tap → seek (existing `onTap`), long-press → `onEdit`
  - **player_screen.dart:**
    - Add `_editLabel(Label label)` method showing dialog with:
      - Timestamp field (pre-filled `mm:ss.SSS` via `formatTimestamp()`, editable)
      - Caption field (pre-filled)
      - Color picker: row of 8 preset color circles, tap to select, highlight selected
    - Parse timestamp via `parseTimestamp()` (from Step 1) — supports both `mm:ss.SSS` and `mm:ss` input
    - On submit: call `_labelProvider.updateLabel(label.id!, timestampMs: ..., caption: ..., colorValue: ...)`
    - Wire `onEdit` in `LabelTile` builder
    - Update `_addLabel()` dialog to also include color picker (default = first preset)
    - When saving a label (add or edit), optionally snap timestamp to nearest beat:
      ```dart
      final grid = BeatGrid(bpm: widget.project.bpm, anchorMs: widget.project.anchorTimestampMs);
      final snappedMs = grid.snapToBeat(rawMs);
      ```
- **Complexity:** Medium
- **Risk:** Low
- **Dependencies:** Steps 1, 2, 3, 4

### Step 8: Rebuild seek bar as beat-grid rectangles
- **File(s):** `lib/widgets/seek_bar.dart`
- **Action:** Rewrite
- **Details:**
  - **Replace Slider with custom beat-grid visualization.** Instead of a thin line with tick marks, the seek bar is a row of rectangles — each rectangle = one beat.
  - **Layout:**
    ```
    ┌─┬─┬─┬─┐┌─┬─┬─┬─┐┌─┬─┬─┬─┐┌─┬─┬─┬─┐  ← beat rectangles
    │▼│ │ │ ││ │ │▼│ ││ │ │ │ ││ │▼│ │ │  ← label markers (▼) on their beat
    └─┴─┴─┴─┘└─┴─┴─┴─┘└─┴─┴─┴─┘└─┴─┴─┴─┘
     measure 1  measure 2  measure 3  measure 4
    ```
  - **Beat rectangle rendering:**
    - Use `BeatGrid.beatsInRange(0, durationMs)` to compute all beat positions
    - Each beat = a small rectangle (~24px tall), uniform width
    - Gap of 1px between beats for visual separation
    - **First beat of each measure (beat 1 of 4):** emphasized — slightly taller, brighter, or distinct color (e.g., white30 vs white12 for unfilled). No thicker separators.
    - Filled beats (before playback position): accent color or dimmed
    - Unfilled beats (after position): dark/muted color (e.g., `Colors.white12`)
    - Current beat: highlighted (brighter accent)
  - **Zoom + scroll behavior:**
    - **Default zoom level:** Fit all beats within the available width (no scrolling in landscape). Beat width = `availableWidth / totalBeats`.
    - **Pinch-to-zoom:** Use `GestureDetector` with `onScaleUpdate` to change zoom level.
      - `_zoomLevel` state: `1.0` = fit-all (default), `>1.0` = zoomed in
      - Zoomed content width = `availableWidth * _zoomLevel`
      - Beat width = `(availableWidth * _zoomLevel) / totalBeats`
      - Min zoom = 1.0 (fit all), max zoom = capped so each beat ≤ ~20px wide
    - **Scroll when zoomed:** When `_zoomLevel > 1.0`, content overflows → wrap in `SingleChildScrollView(scrollDirection: Axis.horizontal)` with a `ScrollController`
      - Auto-scroll to keep playhead centered/visible during playback
      - Manual scroll allowed when paused or dragging
    - **Double-tap to reset zoom** back to 1.0 (fit-all)
  - **Implementation approach:**
    - Use `CustomPainter` inside a `GestureDetector` for tap/drag-to-seek + pinch-to-zoom
    - `LayoutBuilder` to get available width
    - On tap/drag: convert x-position → beat index → timestamp, call `onSeek`
    - On drag: call `onDragUpdate` with interpolated position for live time display
    - On scale: update `_zoomLevel`, clamp to min/max, rebuild
  - **Label markers:** Draw colored triangle/dot above the beat rectangle where the label sits, using `label.color`
  - **Anchor indicator:** Highlight the anchor beat rectangle with a distinct border or accent color
  - **Fallback:** If no BPM is set or duration is unknown, fall back to a plain Slider (current behavior)
  - **Parameters to add:**
    - `double? bpm` — enables beat-grid mode
    - `int anchorMs` — beat grid origin (default 0)
  - **Bug 11 fix:** Label placement is now inherently accurate — each label sits on its exact beat rectangle, no pixel math needed
- **Complexity:** High
- **Risk:** Medium — custom paint + gesture handling + zoom; performance with many beats (300+ BPM songs)
- **Dependencies:** Steps 2, 4

### Step 9: Anchor UI — set and edit anchor timestamp
- **File(s):** `lib/screens/player_screen.dart`, `lib/screens/project_settings_screen.dart`
- **Action:** Modify
- **Details:**
  - **player_screen.dart:**
    - Add "Set Anchor" button near the transport controls (or as a long-press on the BPM display)
    - On tap: capture current playback position, save to project via `DatabaseService.updateProject()`
    - Show brief snackbar: "Anchor set at mm:ss.SSS" (using `formatTimestamp()`)
    - Pass `bpm` and `anchorTimestampMs` to `SeekBar` widget
  - **project_settings_screen.dart:**
    - Add "Beat Anchor" field showing current anchor as `mm:ss.SSS` via `formatTimestamp()`
    - Editable text field; parse via `parseTimestamp()` (accepts `mm:ss.SSS` or `mm:ss`)
    - "Reset" button to set back to 0
    - Auto-save on change via `DatabaseService.updateProject()`
  - Need to reload project data after anchor changes (or make player screen reactive to project updates)
- **Complexity:** Medium
- **Risk:** Low
- **Dependencies:** Steps 1, 2, 8

### Step 10: Force landscape + iPad support
- **File(s):** `lib/main.dart`, `ios/Runner.xcodeproj/project.pbxproj`, various screens
- **Action:** Modify
- **Details:**
  - **Force landscape on mobile:**
    - In `main()`, set preferred orientations:
      ```dart
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      ```
    - Import `package:flutter/services.dart`, make `main()` async
  - **iPad support:**
    - Xcode: `TARGETED_DEVICE_FAMILY = "1,2"`
    - Check all screens for layout at larger sizes
    - Player screen: may need max-width constraint
    - Practice screen: font sizes may need scaling
    - Project list: consider grid layout on iPad
- **Complexity:** Medium
- **Risk:** Medium — layout adjustments needed after orientation change
- **Dependencies:** All previous steps complete for full testing

## Execution Order

```
Step 1 (Time format) ────── (foundation, no deps)
Step 2 (Models + DB) ──┬── Step 3 (LabelProvider) ──── Step 7 (Label editing)
                       ├── Step 6 (Practice colors)
                       ├── Step 8 (Seek bar fix)  ──── Step 9 (Anchor UI)
                       └──
Step 4 (BeatGrid util) ─┬─ Step 5 (Practice bugs)
                        ├─ Step 6 (uses BeatGrid for countdown)
                        ├─ Step 7 (uses BeatGrid for snap-to-beat)
                        └─ Step 8 (uses BeatGrid for tick marks)
Step 10 (Landscape + iPad) ── (last, depends on all)
```

**Suggested implementation order:** 1 → 2 → 4 → 3 → 5 → 6 → 7 → 8 → 9 → 10

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| DB migration breaks existing data | NULL-safe color field, default 0 for anchor, test upgrade path |
| Beat grid rounding errors accumulate | Use double math internally, only round to int at final output |
| Background flash feels unmusical | Use fractional beat position for smooth lerp, test at 60/120/180 BPM |
| Seek bar markers still misaligned | Use LayoutBuilder for actual bounds, not screen width |
| Anchor at wrong position ruins grid | Allow easy reset to 0, show anchor marker on seek bar for visual feedback |
| Landscape breaks portrait layouts | Test each screen after lock, adjust padding/sizing |

## Rollback Strategy
Each step is a git commit. Revert to any previous commit if needed. DB migration is forward-only — nullable `colorValue` and default-0 `anchorTimestampMs` are safe for existing data.
