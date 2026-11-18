import Foundation
import GXDeviceConsole

/// Minimal link boundary for the pinned native console library.
/// The C ABI is imported through the target's bridging header.
enum GXDeviceConsoleRuntime {
    static var isLinked: Bool {
        #if GXDEVICECONSOLE
        return true
        #else
        return false
        #endif
    }

    static func beginSession() -> UInt64? {
        #if GXDEVICECONSOLE
        let generation = gx_session_begin()
        return generation == 0 ? nil : generation
        #else
        return nil
        #endif
    }

    static func cancelSession(_ generation: UInt64) {
        #if GXDEVICECONSOLE
        guard generation != 0 else { return }
        gx_session_cancel(generation)
        #else
        _ = generation
        #endif
    }
}
