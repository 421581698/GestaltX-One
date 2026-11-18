# iOS Host App integration

This directory is the planned SwiftUI/WKWebView host application boundary. The initial commit deliberately does not include a signing profile, provisioning settings, entitlements, or a claim that the app can be installed on a device.

The host app must:

1. Create a dedicated WKWebView with a restrictive navigation policy.
2. Register a reply-capable message handler only for the first-party web origin.
3. Generate a fresh BridgeSession nonce for each WebView lifecycle and inject it at document start.
4. Validate main-frame origin, schema, nonce, request replay, and action allowlist before dispatch.
5. Return a typed BridgeResponse through the message reply closure.
6. Never expose arbitrary shell, filesystem path, URL fetch, or MobileGestalt mutation methods to JavaScript.

Do not load untrusted pages in the privileged WebView. Open external links in the system browser instead.

The iOS host should use Apple's supported signing and distribution process. Developer Mode, pairing, local network access, and system authorization cannot be bypassed by this app.
