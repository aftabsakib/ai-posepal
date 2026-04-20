# AI-PosePal — Design Document
**Date:** 2026-04-20  
**Status:** Approved  
**Platform:** Flutter (Android + iOS)  
**GitHub:** github.com/aftabsakib/ai-posepal

---

## Overview

A cross-platform camera app that uses on-device pose detection and cloud AI to give users real-time pose suggestions before they take a photo. Targets casual users and content creators.

---

## Architecture

```
AI-PosePal
├── Camera Layer         — Flutter camera plugin (live preview + capture)
├── Pose Detection       — google_mlkit_pose_detection (on-device, 33 landmarks)
│    └── CustomPainter   — skeleton overlay drawn on live preview every frame
├── Suggestion Engine    — triggered by user tap "Suggest a Pose"
│    ├── Capture frame   — convert CameraImage to base64 JPEG
│    ├── Claude API call — send image + context prompt to claude-sonnet-4-6
│    └── Parse response  — 3 pose suggestions with plain-English instructions
├── UI Layer
│    ├── CameraScreen    — full-screen live preview with overlay
│    ├── SuggestionSheet — bottom sheet showing 3 pose options
│    └── PoseGuideOverlay— on-screen arrows/text guiding user to match pose
└── Storage              — gal package saves captured photo to device gallery
```

---

## Tech Stack

| Layer | Package | Version |
|---|---|---|
| Camera | camera | ^0.12.0+1 |
| Pose detection | google_mlkit_pose_detection | ^0.14.1 |
| HTTP | http | ^1.6.0 |
| Gallery save | gal | ^2.3.2 |
| Permissions | permission_handler | ^12.0.1 |
| Secrets | envied | ^1.3.4 |
| Code gen | build_runner | ^2.4.0 |

---

## Data Flow

1. App opens → request camera permission → start live preview
2. Every frame: ML Kit detects 33 body landmarks → CustomPainter draws skeleton overlay
3. User taps "Suggest" button:
   - Capture current frame as JPEG
   - Detect person count from ML Kit result (1 = solo, 2+ = group)
   - Send image + person context to Claude vision API
   - Parse response into 3 pose suggestions
4. Bottom sheet appears with 3 suggestion cards
5. User taps a suggestion → on-screen guide text overlaid on camera
6. User hits shutter → photo saved to gallery via gal

---

## Claude API Prompt Strategy

**System prompt:** "You are a professional photography pose coach. You receive a camera frame and suggest 3 specific, actionable poses. Keep each suggestion to 1-2 sentences. Be encouraging and practical."

**User prompt:** "I see [1 person / N people] in this frame. Suggest 3 [solo portrait / group] poses. Format: JSON array of 3 objects with 'title' and 'instruction' fields."

---

## Screens

1. **CameraScreen** — main screen, full-bleed camera preview, skeleton overlay, Suggest button, shutter button
2. **SuggestionSheet** — modal bottom sheet, 3 pose cards, dismiss on tap outside
3. **PermissionScreen** — shown on first launch if camera permission denied

---

## Error Handling

- No internet: Suggest button shows "Needs internet connection" toast, camera still works
- API error: Show retry option, log error
- No person detected: Suggest button shows "Step into frame first" toast
- Permission denied: Show explanation screen with Settings deep link

---

## Testing Plan

- Unit: Claude API service (mock HTTP), pose suggestion parser
- Widget: CameraScreen renders skeleton overlay correctly
- Integration: Full flow on a physical Android device (emulators don't support camera well)

---

## Platform Config Required

**Android (AndroidManifest.xml):**
- `CAMERA` permission
- `READ_MEDIA_IMAGES` (API 33+)
- minSdkVersion 24

**iOS (Info.plist):**
- NSCameraUsageDescription
- NSPhotoLibraryAddUsageDescription
- Minimum deployment target: 15.5

---

## Out of Scope (v1)

- Monetization / paywall
- Social sharing
- Video mode
- Offline pose suggestions
- User accounts
