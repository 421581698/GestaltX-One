# MobileGestalt access boundary

## What is implemented

- Native RPPairing host and Bonjour advertisement through the pinned DeviceConsole XCFramework.
- User-visible pairing code and system-confirmed Developer Mode pairing flow.
- Protected local pairing-record storage with complete file protection and backup exclusion.
- Read-only bridge status for the saved native pairing record.

## What is not implemented

Direct MobileGestalt read/write is not implemented. The upstream GestaltX application uses the separate `worse_query` path and special signed App Group access for its on-device file access. That is not provided by DeviceConsole pairing, and ordinary WKWebView or sandboxed Swift code cannot write the system MobileGestalt store.

GestaltX One will not silently adopt private exploit-based access or claim that pairing grants system-write permission.

## Safe next milestone

Implement a user-driven plist workflow:

1. Import a plist through the iOS document picker.
2. Validate the plist structure and require at least two matching device identity values before treating it as a same-device backup.
3. Show a complete before/after diff.
4. Create and verify a protected backup before any local file replacement.
5. Export the edited plist or share it back to a user-selected destination.
6. Keep direct system mutation disabled unless a supported, documented iOS mechanism becomes available and can be independently verified.

The UI must label exported plist edits as files for manual use; it must not imply that they have been applied to the live system.
