import SwiftUI
import UIKit
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

            case "priorities.exec":
                let argv = params["argv"] as? [Any] ?? []
                respond(id: id, payload: ["result": runPriorities(argv.map { String(describing: $0) })])

            default:
                respond(id: id, payload: rpcError(code: -32601, message: "method not found"))
            }
        }

        private struct PriorityAttrs {
            var echelon = 0
            var priority = 0
            var checked = 0
            var upvotes = 0
        }

        private struct PriorityRow {
            let url: URL
            let attrs: PriorityAttrs
            let hasSubpriorities: Bool
        }

        private func runPriorities(_ args: [String]) -> [String: Any] {
            guard let action = args.first else {
                return execResult(stderr: "priorities-mobile: action required", exitCode: 2)
            }

            do {
                switch action {
                case "list-themes":
                    return execResult(stdout: "psionic\nwizard\ntechnomancer\n")
                case "get-ui-prefs":
                    return execResult(stdout: readPriorityPrefs())
                case "set-ui-pref":
                    guard args.count >= 3 else { return execResult(stderr: "priorities-mobile: set-ui-pref requires KEY VALUE", exitCode: 2) }
                    let key = args[1]
                    guard key.range(of: "^[a-z0-9][a-z0-9._-]*$", options: .regularExpression) != nil else {
                        return execResult(stderr: "priorities-mobile: invalid UI pref key: \(key)", exitCode: 2)
                    }
                    let value = args[2].replacingOccurrences(of: "[\\r\\n]", with: " ", options: .regularExpression)
                    UserDefaults.standard.set(value, forKey: "priorities.\(key)")
                    return execResult(stdout: "key=\(key)\nvalue=\(value)\n")
                case "list":
                    return execResult(stdout: try emitList(resolvePriorityPath(args.dropFirst().first ?? ".")))
                case "prioritize", "prioritize-fast":
                    guard args.count >= 2 else { return execResult(stderr: "priorities-mobile: path required for prioritize", exitCode: 2) }
                    try prioritize(resolvePriorityPath(args[1]), autoCreate: false)
                    return execResult()
                case "prioritize-quick":
                    guard args.count >= 2 else { return execResult(stderr: "priorities-mobile: path required for prioritize-quick", exitCode: 2) }
                    let url = resolvePriorityPath(args[1])
                    try prioritize(url, autoCreate: false)
                    let attrs = readAttrs(url)
                    return execResult(stdout: "\(attrs.echelon)\t\(attrs.priority)\t\(attrs.checked)\n")
                case "add", "add-fast":
                    guard args.count >= 3 else { return execResult(stderr: "priorities-mobile: add requires DIR and NAME", exitCode: 2) }
                    guard !unsafeName(args[2]) else { return execResult(stderr: "priorities-mobile: invalid item name", exitCode: 2) }
                    let dir = resolvePriorityPath(args[1])
                    let target = dir.appendingPathComponent(args[2])
                    try prioritize(target, autoCreate: true)
                    return action == "add-fast" ? execResult(stdout: try emitList(dir)) : execResult()
                case "check-toggle", "check-toggle-fast":
                    guard args.count >= 2 else { return execResult(stderr: "priorities-mobile: path required for check-toggle", exitCode: 2) }
                    let url = resolvePriorityPath(args[1])
                    guard fileExists(url) else { return execResult(stderr: "priorities-mobile: file not found: \(url.path)", exitCode: 1) }
                    var attrs = readAttrs(url)
                    attrs.checked = attrs.checked == 1 ? 0 : 1
                    try writeAttrs(url, attrs)
                    return action == "check-toggle-fast" ? execResult(stdout: try emitList(url.deletingLastPathComponent())) : execResult()
                case "make-project", "make-project-fast":
                    guard args.count >= 2 else { return execResult(stderr: "priorities-mobile: path required for make-project", exitCode: 2) }
                    let url = resolvePriorityPath(args[1])
                    guard fileExists(url) else { return execResult(stderr: "priorities-mobile: file not found: \(url.path)", exitCode: 1) }
                    let attrs = readAttrs(url)
                    if !isDirectory(url) {
                        try FileManager.default.removeItem(at: url)
                        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    }
                    try writeAttrs(url, attrs)
                    return action == "make-project-fast" ? execResult(stdout: try emitList(url.deletingLastPathComponent())) : execResult(stdout: "\(url.path)\n")
                case "rename", "rename-fast":
                    guard args.count >= 3 else { return execResult(stderr: "priorities-mobile: rename requires PATH and NAME", exitCode: 2) }
                    guard !unsafeName(args[2]) else { return execResult(stderr: "priorities-mobile: invalid rename target name", exitCode: 2) }
                    let url = resolvePriorityPath(args[1])
                    let dest = url.deletingLastPathComponent().appendingPathComponent(args[2])
                    guard !fileExists(dest) else { return execResult(stderr: "priorities-mobile: rename target already exists: \(args[2])", exitCode: 1) }
                    try FileManager.default.moveItem(at: url, to: dest)
                    if fileExists(sidecar(url)) {
                        try? FileManager.default.moveItem(at: sidecar(url), to: sidecar(dest))
                    }
                    return action == "rename-fast" ? execResult(stdout: try emitList(dest.deletingLastPathComponent())) : execResult(stdout: "\(dest.path)\n")
                case "remove", "remove-fast":
                    guard args.count >= 2 else { return execResult(stderr: "priorities-mobile: path required for remove", exitCode: 2) }
                    let url = resolvePriorityPath(args[1])
                    guard fileExists(url) else { return execResult(stderr: "priorities-mobile: file not found: \(url.path)", exitCode: 1) }
                    let parent = url.deletingLastPathComponent()
                    try FileManager.default.removeItem(at: url)
                    try? FileManager.default.removeItem(at: sidecar(url))
                    return action == "remove-fast" ? execResult(stdout: try emitList(parent)) : execResult()
                case "descendant-count":
                    guard args.count >= 2 else { return execResult(stderr: "priorities-mobile: path required for descendant-count", exitCode: 2) }
                    let url = resolvePriorityPath(args[1])
                    let count = descendantCount(url)
                    return execResult(stdout: "\(count)\n")
                case "parent":
                    guard args.count >= 2 else { return execResult(stderr: "priorities-mobile: parent requires DIR", exitCode: 2) }
                    return execResult(stdout: "\(resolvePriorityPath(args[1]).deletingLastPathComponent().path)\n")
                case "pick-dir":
                    let root = defaultPriorityRoot()
                    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                    return execResult(stdout: "\(root.path)\n")
                case "open-dir":
                    return execResult()
                case "copy-priorities":
                    let expanded = args.contains("--expanded")
                    let dirArg = args.dropFirst().first(where: { $0 != "--expanded" }) ?? "."
                    let text = try markdown(resolvePriorityPath(dirArg), depth: 0, expanded: expanded).trimmingCharacters(in: .newlines)
                    UIPasteboard.general.string = text
                    return execResult(stdout: "\(text)\n")
                default:
                    return execResult(stderr: "priorities-mobile: unsupported action: \(action)", exitCode: 2)
                }
            } catch {
                return execResult(stderr: "priorities-mobile: \(error.localizedDescription)", exitCode: 1)
            }
        }

        private func execResult(stdout: String = "", stderr: String = "", exitCode: Int = 0) -> [String: Any] {
            ["stdout": stdout, "stderr": stderr, "exit_code": exitCode, "error": NSNull()]
        }

        private func defaultPriorityRoot() -> URL {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            return (docs ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent("Priorities", isDirectory: true)
        }

        private func resolvePriorityPath(_ path: String) -> URL {
            if path.isEmpty || path == "." {
                return defaultPriorityRoot()
            }
            if path == "~" {
                return defaultPriorityRoot()
            }
            if path.hasPrefix("~/") {
                return defaultPriorityRoot().appendingPathComponent(String(path.dropFirst(2)))
            }
            return URL(fileURLWithPath: path).standardizedFileURL
        }

        private func readPriorityPrefs() -> String {
            UserDefaults.standard.dictionaryRepresentation().keys
                .filter { $0.hasPrefix("priorities.") }
                .sorted()
                .map { "\($0.dropFirst("priorities.".count))=\(UserDefaults.standard.string(forKey: $0) ?? "")" }
                .joined(separator: "\n")
        }

        private func unsafeName(_ name: String) -> Bool {
            name.isEmpty || name == "." || name == ".." || name.contains("/") || name.contains("\\") || name.contains("\n") || name.contains("\r")
        }

        private func sidecar(_ url: URL) -> URL {
            url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + ".xattr.json")
        }

        private func fileExists(_ url: URL) -> Bool {
            FileManager.default.fileExists(atPath: url.path)
        }

        private func isDirectory(_ url: URL) -> Bool {
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }

        private func readAttrs(_ url: URL) -> PriorityAttrs {
            let side = sidecar(url)
            guard let data = try? Data(contentsOf: side),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let xattrs = json["xattrs"] as? [String: String]
            else { return PriorityAttrs() }
            return PriorityAttrs(
                echelon: Int(xattrs["echelon"] ?? "") ?? 0,
                priority: Int(xattrs["priority"] ?? "") ?? 0,
                checked: Int(xattrs["checked"] ?? "") ?? 0,
                upvotes: Int(xattrs["upvotes"] ?? "") ?? 0
            )
        }

        private func writeAttrs(_ url: URL, _ attrs: PriorityAttrs) throws {
            var xattrs: [String: String] = [:]
            if attrs.echelon > 0 { xattrs["echelon"] = String(attrs.echelon) }
            if attrs.priority > 0 { xattrs["priority"] = String(attrs.priority) }
            xattrs["checked"] = String(attrs.checked)
            if attrs.upvotes > 0 { xattrs["upvotes"] = String(attrs.upvotes) }
            let obj: [String: Any] = ["version": "1", "docPath": url.lastPathComponent, "xattrs": xattrs]
            let data = try JSONSerialization.data(withJSONObject: obj)
            try data.write(to: sidecar(url), options: .atomic)
        }

        private func rows(_ dir: URL) throws -> [PriorityRow] {
            if !fileExists(dir) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            let children = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
            return children
                .filter { !$0.lastPathComponent.hasSuffix(".xattr.json") }
                .compactMap { url -> PriorityRow? in
                    let attrs = readAttrs(url)
                    guard attrs.echelon > 0 else { return nil }
                    return PriorityRow(url: url, attrs: attrs, hasSubpriorities: hasSubpriorities(url))
                }
                .sorted {
                    if $0.attrs.echelon != $1.attrs.echelon { return $0.attrs.echelon > $1.attrs.echelon }
                    if $0.attrs.priority != $1.attrs.priority { return $0.attrs.priority < $1.attrs.priority }
                    return $0.url.lastPathComponent < $1.url.lastPathComponent
                }
        }

        private func hasSubpriorities(_ url: URL) -> Bool {
            guard isDirectory(url),
                  let children = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            else { return false }
            return children.contains { !$0.lastPathComponent.hasSuffix(".xattr.json") && readAttrs($0).echelon > 0 }
        }

        private func emitList(_ dir: URL) throws -> String {
            let currentRows = try rows(dir)
            return currentRows.map { row in
                let kind = isDirectory(row.url) ? "dir" : "file"
                return "\(row.url.path)\t\(row.url.lastPathComponent)\t\(kind)\t\(row.attrs.echelon)\t\(row.attrs.priority)\t\(row.attrs.checked)\t\(row.attrs.upvotes)\t\(row.hasSubpriorities ? 1 : 0)"
            }.joined(separator: "\n").appending(currentRows.isEmpty ? "" : "\n")
        }

        private func prioritize(_ url: URL, autoCreate: Bool) throws {
            if !fileExists(url) {
                guard autoCreate else { throw NSError(domain: "Priorities", code: 1, userInfo: [NSLocalizedDescriptionKey: "file not found: \(url.path)"]) }
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                FileManager.default.createFile(atPath: url.path, contents: Data())
            }
            let dir = url.deletingLastPathComponent()
            var attrs = readAttrs(url)
            let siblings = try rows(dir)
            let highestEchelon = siblings.map(\.attrs.echelon).max() ?? 0
            let highestPriority = siblings.filter { $0.attrs.echelon == highestEchelon }.map(\.attrs.priority).max() ?? 0
            if highestEchelon == 0 {
                attrs.echelon = 1
                attrs.priority = 1
            } else if attrs.echelon == highestEchelon && attrs.echelon > 0 {
                attrs.echelon = highestEchelon + 1
                attrs.priority = 1
            } else {
                attrs.echelon = highestEchelon
                attrs.priority = highestPriority + 1
            }
            attrs.checked = 0
            try writeAttrs(url, attrs)
        }

        private func markdown(_ dir: URL, depth: Int, expanded: Bool) throws -> String {
            try rows(dir).map { row in
                let mark = row.attrs.checked == 1 ? "x" : " "
                let line = String(repeating: "  ", count: depth) + "- [\(mark)] \(row.url.lastPathComponent)\n"
                if expanded && isDirectory(row.url) && row.hasSubpriorities {
                    return line + (try markdown(row.url, depth: depth + 1, expanded: true))
                }
                return line
            }.joined()
        }

        private func descendantCount(_ url: URL) -> Int {
            guard isDirectory(url),
                  let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)
            else { return 0 }
            var count = 0
            for case let child as URL in enumerator where !child.lastPathComponent.hasSuffix(".xattr.json") {
                count += 1
            }
            return count
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
