---
name: expo
description: Conventions and workflow for Expo / React Native apps. Use whenever working on mobile screens, navigation, native modules, app config (app.json/app.config), EAS builds, or anything in an Expo project, including debugging Metro or device-specific issues.
---

# Expo / React Native conventions

Starting defaults; edit freely.

## Dependencies
- Add Expo-ecosystem packages with `npx expo install <pkg>`, not a bare npm/pnpm add, so versions
  match the SDK.
- Prefer Expo SDK modules before reaching for a community native module. If you do need custom
  native code, use a config plugin or a local Expo module rather than hand-editing `ios/` or
  `android/` when the project uses Continuous Native Generation (no committed native dirs).

## Running
- In a parallel worktree, start Metro on the worktree's port:
  `npx expo start --port $RCT_METRO_PORT` (from `.harness/ports.env`).
- Anything that needs a device or simulator can't be verified by the harness. Say clearly what
  you verified and what needs a manual check on iOS **and** Android.

## Code
- Use platform-specific files (`*.ios.tsx`, `*.android.tsx`) or `Platform.select` for real
  platform differences. Don't sprinkle `Platform.OS` checks everywhere.
- Lists: use `FlatList`/`FlashList` with stable keys for anything unbounded, never
  `ScrollView` + `map`.
- Keep secrets out of the bundle. Anything in app config or `EXPO_PUBLIC_*` ships to users.

## Releases
- `eas build` / `eas submit` / `eas update` are release actions. The harness blocks them in
  parallel/auto mode, so ask me before running them interactively.
