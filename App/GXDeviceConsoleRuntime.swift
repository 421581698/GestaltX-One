import Foundation
#if canImport(GXDeviceConsole)
import GXDeviceConsole
#endif

/// Minimal, explicit link boundary for the pinned native console library.
/// Pairing is deliberately not exposed to the web bridge; it will be initiated
/// only by a native, user-confirmed flow after its lifecycle and PIN UI exist.
enum GXDeviceConsoleRuntime {
    static var isLinked: Bool {
        #if canImport(GXDeviceConsole)
        return true
        #else
        return false
        #endif
    }

    static func beginSession() -> UInt64? {
        #if canImport(GXDeviceConsole)
        let generation = gx_session_begin()
        return generation == 0 ? nil : generation
        #else
        return nil
        #endif
    }

    static func cancelSession(_ generation: UInt64) {
        #if canImport(GXDeviceConsole)
        guard generation != 0 else { return }
        gx_session_cancel(generation)
        #else
        _ = generation
        #endif
    }
}
