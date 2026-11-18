# GestaltX One

A safety-first iPhone task platform with a web control surface and a native iOS execution host.

> Status: foundation scaffold. This repository does not yet install an iOS app, pair a device, or modify MobileGestalt. Those capabilities require a separately built and signed native app and explicit iOS authorization.

## Architecture

- **Web control plane**: creates tasks and presents progress. It never receives arbitrary system-command access.
- **Native bridge**: accepts a small allowlist of typed requests from the first-party web origin.
- **Device adapter**: reports only capabilities that the installed native host can actually verify.
- **Task runtime**: tracks task lifecycle, cancellation, and structured events.
- **Backup store**: writes versioned, integrity-checkable backup artifacts before any future mutation workflow.
- **GestaltX adapter**: planned integration boundary. Any reuse of GestaltX GPL-3.0 code must preserve notices and comply with GPL-3.0 distribution obligations.

## Repository layout

```
Sources/GestaltXOneCore/   Cross-platform task, bridge, device and backup foundations
Tests/GestaltXOneCoreTests/
App/                       iOS host integration notes and entry-point scaffold
.github/workflows/         Swift package CI
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
4. Mutating actions are not exposed in this initial version.
5. Backups are created and verified before future write operations.
6. iOS signing, Developer Mode, local network permissions, pairing, and system confirmation remain under Apple's control. This project does not bypass them.

## Current supported actions

- `device.getInfo`
- `device.getCapabilities`
- `device.getPairingStatus` (reports unsupported until a real pairing adapter is integrated)
- `backup.getStatus`
- `task.getStatus`

No MobileGestalt read/write operation is claimed as implemented.
