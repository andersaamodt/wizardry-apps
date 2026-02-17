import SwiftUI
import WebKit

struct WizardryWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "wizardry")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        let view = WKWebView(frame: .zero, configuration: config)
        context.coordinator.webView = view

        if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "app") {
            let accessURL = indexURL.deletingLastPathComponent()
            view.loadFileURL(indexURL, allowingReadAccessTo: accessURL)
        }

        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        _ = uiView
        _ = context
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?

        private var mountedVault = ""
        private var txOpen = false
        private var txId: UInt64 = 0
        private var subscriptions: [String: String] = [:]

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "wizardry" else { return }

            let payload = decodeMessageBody(message.body)
            guard let payload else { return }

            if payload["command"] != nil, let id = payload["id"] as? String {
                respond(id: id, payload: [
                    "stdout": "",
                    "stderr": "bridge.exec is not enabled on mobile hosts",
                    "exit_code": 1,
                    "error": NSNull()
                ])
                return
            }

            guard let type = payload["type"] as? String else { return }
            switch type {
            case "rpc":
                handleRpc(payload)
            case "subscribe":
                if let token = payload["token"] as? String,
                   let event = payload["event"] as? String,
                   !token.isEmpty,
                   !event.isEmpty {
                    subscriptions[token] = event
                }
            case "unsubscribe":
                if let token = payload["token"] as? String {
                    subscriptions.removeValue(forKey: token)
                }
            default:
                break
            }
        }

        private func handleRpc(_ payload: [String: Any]) {
            let id = (payload["id"] as? String) ?? ""
            let method = (payload["method"] as? String) ?? ""
            let params = (payload["params"] as? [String: Any]) ?? [:]

            switch method {
            case "core.ping":
                respond(id: id, payload: [
                    "result": [
                        "ok": true,
                        "engine": "ios-host",
                        "version": "0.1.0"
                    ]
                ])

            case "vault.mount":
                guard let path = params["path"] as? String, !path.isEmpty else {
                    respond(id: id, payload: rpcError(code: -32602, message: "vault.mount requires params.path"))
                    return
                }
                mountedVault = path
                respond(id: id, payload: ["result": ["mounted": true]])
                emitEvent(name: "vaultMounted", payload: ["path": path])

            case "vault.info":
                respond(id: id, payload: ["result": [
                    "mounted": !mountedVault.isEmpty,
                    "path": mountedVault
                ]])

            case "txn.begin":
                if txOpen {
                    respond(id: id, payload: rpcError(code: -32600, message: "transaction already open"))
                    return
                }
                txOpen = true
                txId += 1
                respond(id: id, payload: ["result": ["opened": true]])

            case "txn.commit":
                if !txOpen {
                    respond(id: id, payload: rpcError(code: -32600, message: "no open transaction"))
                    return
                }
                txOpen = false
                respond(id: id, payload: ["result": ["committed": true]])
                emitEvent(name: "txnCommitted", payload: ["txId": txId])

            case "txn.rollback":
                if !txOpen {
                    respond(id: id, payload: rpcError(code: -32600, message: "no open transaction"))
                    return
                }
                txOpen = false
                respond(id: id, payload: ["result": ["rolledBack": true]])

            default:
                respond(id: id, payload: rpcError(code: -32601, message: "method not found"))
            }
        }

        private func decodeMessageBody(_ body: Any) -> [String: Any]? {
            if let dict = body as? [String: Any] {
                return dict
            }

            if let str = body as? String,
               let data = str.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }

            return nil
        }

        private func rpcError(code: Int, message: String) -> [String: Any] {
            ["error": ["code": code, "message": message]]
        }

        private func respond(id: String, payload: [String: Any]) {
            guard let webView else { return }
            let payloadJSON = encodeJSON(payload)
            let escapedId = id
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")

            let js = """
            if (window.__wizardry_callbacks && window.__wizardry_callbacks['\(escapedId)']) {
              window.__wizardry_callbacks['\(escapedId)'](\(payloadJSON));
              delete window.__wizardry_callbacks['\(escapedId)'];
            }
            """

            DispatchQueue.main.async {
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }

        private func emitEvent(name: String, payload: [String: Any]) {
            guard subscriptions.values.contains(name), let webView else { return }
            let payloadJSON = encodeJSON(payload)
            let escapedName = name
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")

            let js = """
            if (window.__wizardry_emit) {
              window.__wizardry_emit('\(escapedName)', \(payloadJSON));
            }
            """

            DispatchQueue.main.async {
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }

        private func encodeJSON(_ value: Any) -> String {
            guard JSONSerialization.isValidJSONObject(value),
                  let data = try? JSONSerialization.data(withJSONObject: value),
                  let text = String(data: data, encoding: .utf8)
            else {
                return "null"
            }
            return text
        }
    }
}
