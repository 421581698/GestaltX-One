export type NativeAction =
  | "device.getInfo"
  | "device.getCapabilities"
  | "device.getPairingStatus"
  | "backup.getStatus"
  | "task.getStatus";

export interface NativeRequest {
  version: 1;
  requestID: string;
  action: NativeAction;
  payload: Record<string, string>;
  nonce: string;
}

export interface NativeResponse {
  version: 1;
  requestID: string;
  success: boolean;
  status: string;
  data: Record<string, string>;
  error: string | null;
}

declare global {
  interface Window {
    __GESTALTX_BRIDGE_NONCE__?: string;
    webkit?: {
      messageHandlers?: {
        gestaltx?: {
          postMessage(request: NativeRequest): Promise<NativeResponse>;
        };
      };
    };
  }
}

/**
 * Calls the first-party iOS WKWebView host.
 * This deliberately fails in Safari or an ordinary desktop browser.
 */
export async function sendNativeTask(
  action: NativeAction,
  payload: Record<string, string> = {},
): Promise<NativeResponse> {
  const handler = window.webkit?.messageHandlers?.gestaltx;
  const nonce = window.__GESTALTX_BRIDGE_NONCE__;

  if (!handler || !nonce) {
    throw new Error("GestaltX native host is not connected");
  }

  const response = await handler.postMessage({
    version: 1,
    requestID: crypto.randomUUID(),
    action,
    payload,
    nonce,
  });

  if (!response || response.version !== 1) {
    throw new Error("Invalid native bridge response");
  }
  if (!response.success) {
    throw new Error(response.error || ("Native task failed: " + response.status));
  }
  return response;
}
