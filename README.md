# GestaltX One

A safety-first iPhone task platform with a web control surface and a native iOS execution host.

> Status: foundation scaffold. This repository does not yet install an iOS app, pair a device, or modify MobileGestalt. Those capabilities require a separately built and signed native app and explicit iOS authorization.

## Architecture

- **Web control plane**: creates tasks and presents progress. It never receives arbitrary system-command access.
- **Native bridge**: accepts a small allowlist of typed requests from the first-party web origin.
- **Device adapter / transport**: reports only capabilities the installed host can verify. `DeviceTransport` defines the pairing boundary; the current `UnavailableDeviceTransport` intentionally performs no discovery or pairing.
- **Task runtime**: tracks task lifecycle, cancellation, and structured events.
- **Backup store**: writes versioned, integrity-checkable backup artifacts before any future mutation workflow.
- **Upstream native component**: `Vendor/GestaltX` pins the official GestaltX repository at a reviewed commit. Its `Native/DeviceConsole` crate is GPL-3.0-only and is tested separately. The current app does not yet link the generated XCFramework or invoke pairing.

## Repository layout

```
Sources/GestaltXOneCore/   Cross-platform task, bridge, device and backup foundations
Tests/GestaltXOneCoreTests/
App/                       SwiftUI iOS host and WKWebView bridge
Web/                       Typed TypeScript bridge client
project.yml                XcodeGen project definition
Vendor/GestaltX/           Pinned upstream GestaltX source submodule (GPL-3.0 component)
.github/workflows/         Swift, Rust host tests, native iOS cross-build and simulator CI
```

## Development

Requires Swift 5.9 or newer.

```sh
swift test
```

## Security model

1. Only the configured HTTPS origin and main frame may call the bridge.
2. Bridge actions are allowlisted and strongly typed.
3. Each bridge session uses a native-generated nonce; request identifiers are replay-protected.
4. Pairing readiness distinguishes the pairing prerequisites (user-confirmed Developer Mode and Local Network permission) from the later RSD device-session prerequisite (local development tunnel). iOS does not expose every prerequisite as a trustworthy public programmatic status.
5. Backups are created and verified before future write operations.
6. iOS signing, Developer Mode, local network permissions, pairing, and system confirmation remain under Apple's control. This project does not bypass them.

## Build the iOS host

Install Xcode and XcodeGen, then run:

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project GestaltXOne.xcodeproj -scheme GestaltXOne -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Before a real device build, replace the placeholder `GESTALTX_CONTROL_PLANE_URL` build setting with a domain you control and configure that origin's Content Security Policy. The host intentionally refuses non-HTTPS origins and cross-origin navigation.

## Current supported actions

- `device.getInfo`
- `device.getCapabilities`
- `device.getPairingStatus` (reports explicit unavailable state and missing prerequisites until the native adapter is linked and wired)
- `backup.getStatus`
- `task.getStatus`

No MobileGestalt read/write operation or working pairing UI is claimed as implemented. The upstream repository is pinned as a Git submodule, not copied into the app's source tree. Its native console supports pairing/RSD transport only; MobileGestalt access is a separate upstream path and is not enabled here. Any distributed combined build incorporating the GPL-3.0 component must preserve notices and meet the corresponding-source and licensing obligations. See `Vendor/README.md`.
