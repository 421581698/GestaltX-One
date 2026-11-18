# GestaltX One

A safety-first iPhone task platform with a web control surface and a native iOS execution host.

> Status: native pairing flow integrated; real-device acceptance remains outstanding. CI cross-compiles the pinned DeviceConsole Rust library for iPhone ARM64 and iOS Simulator ARM64 and links it into the iOS host. The native Device tab can start the RPPairing host, advertise it over Bonjour, display the temporary pairing code, and store a verified pairing plist in protected local storage. MobileGestalt read/write is not implemented.

## Architecture

- **Web control plane**: creates tasks and presents progress. It never receives arbitrary system-command access.
- **Native bridge**: accepts a small allowlist of typed requests from the first-party web origin.
- **Device pairing**: the native Device tab invokes the pinned RPPairing host after an explicit user tap, advertises it on the local network, and persists credentials under complete file protection. The web bridge cannot start pairing.
- **Task runtime**: tracks task lifecycle, cancellation, and structured events.
- **Backup store**: writes versioned, integrity-checkable backup artifacts before any future mutation workflow.
- **Upstream native component**: `Vendor/GestaltX` pins the official GestaltX repository at a reviewed commit. CI builds its GPL-3.0-only `Native/DeviceConsole` crate for device and simulator and links the resulting XCFramework into the app. The app compiles the upstream Swift FFI wrapper and a Bonjour relay.

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

Install Xcode, XcodeGen, Rust, CMake and NASM. Initialize the pinned submodule and build the native XCFramework before generating the Xcode project:

```sh
git submodule update --init --recursive
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
brew install xcodegen cmake nasm
Vendor/GestaltX/Native/DeviceConsole/build-xcframework.sh
xcodegen generate
xcodebuild -project GestaltXOne.xcodeproj -scheme GestaltXOne -sdk iphonesimulator -arch arm64 -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Before a real device build, replace the placeholder `GESTALTX_CONTROL_PLANE_URL` build setting with a domain you control and configure that origin's Content Security Policy. The host intentionally refuses non-HTTPS origins and cross-origin navigation.

## Current supported actions

- `device.getInfo`
- `device.getCapabilities`
- `device.getPairingStatus` (read-only status; pairing is initiated from the native Device tab)
- `backup.getStatus`
- `task.getStatus`

The native pairing flow has not yet been accepted on a physical iPhone. iOS may suspend the app when switching to Settings, so the UI warns that pairing can require a retry. No MobileGestalt read/write operation is implemented. The upstream native console supports RPPairing and RSD/syslog transport only; MobileGestalt access is a separate capability. This app statically links the upstream GPL-3.0-only component, so distribution of the combined binary must comply with GPL-3.0 and provide the corresponding source. See `LICENSE`, `NOTICE.md`, and `Vendor/README.md`.
