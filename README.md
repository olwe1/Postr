# Postr

A minimal macOS client to publish notes to Nostr 🟣

<img width="392" height="281" alt="preview" src="https://github.com/user-attachments/assets/060de4de-4250-41e8-9f0d-9e16c26cef92" />

## Usage
- Download/build the app and launch it.
- Sign in with your Nostr key (nsec/hex).
- Write your note in the "Note:" field and click "Post".

## Development
Requirements:
- macOS
- Xcode 15+ (Swift 5.9+)

Steps:
1. Open the project: `Postr.xcodeproj` (or the workspace if you prefer: `Postr.xcodeproj/project.xcworkspace`).
2. Xcode will automatically resolve Swift Package dependencies (NostrSDK, etc.).
3. Select the "Postr" scheme and the "My Mac" destination.
4. Run (⌘R) to launch in debug.

Useful structure:
- Source code: `Postr/`
- Entry point: `Postr/PostrApp.swift`
- Main SwiftUI views: `Postr/Views/`
- Services (session, posting): `Postr/Services/`
- ViewModels: `Postr/ViewModels/`

## Build
With Xcode (GUI):
- Product → Build (⌘B) for a Debug build.
- Product → Archive to create a Release archive (notarization/distribution as needed).

Command line:
- Debug:
  ```bash
  xcodebuild -project Postr.xcodeproj -scheme Postr -configuration Debug build
  ```
- Release:
  ```bash
  xcodebuild -project Postr.xcodeproj -scheme Postr -configuration Release build
- Release (without signature):
  ```bash
  xcodebuild -scheme "Postr" -configuration Release -derivedDataPath ./build CODE_SIGNING_ALLOWED=NO build
  xattr -cr /your-path/Postr.app/
  ```

## Troubleshooting
- If packages don’t resolve: File → Packages → Reset Package Caches, then "Resolve Package Versions".
- If code signing fails when Archiving: configure Signing & Capabilities with your Team, or disable automatic signing for local builds.
