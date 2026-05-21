package com.wizardry.apps.host

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.atomic.AtomicLong

class MainActivity : AppCompatActivity() {
    private lateinit var webView: WebView
    private val subscriptions = mutableMapOf<String, String>()
    private var mountedVault: String = ""
    private var txOpen: Boolean = false
    private val txId = AtomicLong(0)

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        webView = WebView(this)
        setContentView(webView)

        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.allowFileAccess = true
        webView.settings.allowContentAccess = true
        webView.webViewClient = WebViewClient()
        webView.webChromeClient = WebChromeClient()
        webView.addJavascriptInterface(Bridge(), "WizardryBridge")

        webView.loadUrl("file:///android_asset/app/index.html")
    }

    inner class Bridge {
        @JavascriptInterface
        fun postMessage(payload: String) {
            val message = try {
                JSONObject(payload)
            } catch (_: Throwable) {
                null
            } ?: return

            when {
                message.has("command") && message.has("id") -> handleLegacyExec(message)
                message.optString("type") == "rpc" -> handleRpc(message)
                message.optString("type") == "subscribe" -> {
                    val token = message.optString("token")
                    val event = message.optString("event")
                    if (token.isNotBlank() && event.isNotBlank()) {
                        subscriptions[token] = event
                    }
                }
                message.optString("type") == "unsubscribe" -> {
                    val token = message.optString("token")
                    subscriptions.remove(token)
                }
            }
        }
    }

    private fun handleLegacyExec(message: JSONObject) {
        val id = message.optString("id")
        val payload = JSONObject()
            .put("stdout", "")
            .put("stderr", "bridge.exec is not enabled on mobile hosts")
            .put("exit_code", 1)
            .put("error", JSONObject.NULL)
        respond(id, payload)
    }

    private fun handleRpc(message: JSONObject) {
        val id = message.optString("id")
        val method = message.optString("method")
        val params = message.optJSONObject("params") ?: JSONObject()

        when (method) {
            "core.ping" -> {
                respond(id, JSONObject().put("result", JSONObject()
                    .put("ok", true)
                    .put("engine", "android-host")
                    .put("version", "0.1.0")))
            }

            "vault.mount" -> {
                val path = params.optString("path")
                if (path.isBlank()) {
                    respond(id, rpcError(-32602, "vault.mount requires params.path"))
                    return
                }
                mountedVault = path
                respond(id, JSONObject().put("result", JSONObject().put("mounted", true)))
                emitEvent("vaultMounted", JSONObject().put("path", path))
            }

            "vault.info" -> {
                respond(id, JSONObject().put("result", JSONObject()
                    .put("mounted", mountedVault.isNotBlank())
                    .put("path", mountedVault)))
            }

            "txn.begin" -> {
                if (txOpen) {
                    respond(id, rpcError(-32600, "transaction already open"))
                    return
                }
                txOpen = true
                txId.incrementAndGet()
                respond(id, JSONObject().put("result", JSONObject().put("opened", true)))
            }

            "txn.commit" -> {
                if (!txOpen) {
                    respond(id, rpcError(-32600, "no open transaction"))
                    return
                }
                txOpen = false
                respond(id, JSONObject().put("result", JSONObject().put("committed", true)))
                emitEvent("txnCommitted", JSONObject().put("txId", txId.get()))
            }

            "txn.rollback" -> {
                if (!txOpen) {
                    respond(id, rpcError(-32600, "no open transaction"))
                    return
                }
                txOpen = false
                respond(id, JSONObject().put("result", JSONObject().put("rolledBack", true)))
            }

            "priorities.exec" -> {
                val argv = params.optJSONArray("argv") ?: JSONArray()
                respond(id, JSONObject().put("result", runPriorities(argv)))
            }

            else -> respond(id, rpcError(-32601, "method not found"))
        }
    }

    private data class PriorityAttrs(
        val echelon: Int = 0,
        val priority: Int = 0,
        val checked: Int = 0,
        val upvotes: Int = 0
    )

    private data class PriorityRow(
        val file: File,
        val attrs: PriorityAttrs,
        val hasSubpriorities: Boolean
    )

    private fun runPriorities(argv: JSONArray): JSONObject {
        val args = mutableListOf<String>()
        for (i in 0 until argv.length()) {
            args.add(argv.optString(i))
        }
        if (args.isEmpty()) {
            return execResult("", "priorities-mobile: action required", 2)
        }
        return try {
            when (val action = args[0]) {
                "list-themes" -> execResult("psionic\nwizard\ntechnomancer\n")
                "get-ui-prefs" -> execResult(readPriorityPrefs())
                "set-ui-pref" -> {
                    if (args.size < 3) execResult("", "priorities-mobile: set-ui-pref requires KEY VALUE", 2)
                    else {
                        val key = args[1]
                        if (!key.matches(Regex("[a-z0-9][a-z0-9._-]*"))) {
                            execResult("", "priorities-mobile: invalid UI pref key: $key", 2)
                        } else {
                            priorityPrefs().edit().putString(key, args[2].replace(Regex("[\\r\\n]"), " ")).apply()
                            execResult("key=$key\nvalue=${args[2].replace(Regex("[\\r\\n]"), " ")}\n")
                        }
                    }
                }
                "list" -> execResult(emitList(resolvePriorityPath(args.getOrNull(1) ?: ".")))
                "prioritize", "prioritize-fast" -> {
                    val target = args.getOrNull(1) ?: return execResult("", "priorities-mobile: path required for prioritize", 2)
                    prioritize(resolvePriorityPath(target), false)
                    execResult("")
                }
                "prioritize-quick" -> {
                    val target = args.getOrNull(1) ?: return execResult("", "priorities-mobile: path required for prioritize-quick", 2)
                    val file = resolvePriorityPath(target)
                    prioritize(file, false)
                    val attrs = readAttrs(file)
                    execResult("${attrs.echelon}\t${attrs.priority}\t${attrs.checked}\n")
                }
                "add", "add-fast" -> {
                    val dir = args.getOrNull(1) ?: return execResult("", "priorities-mobile: add requires DIR and NAME", 2)
                    val name = args.getOrNull(2) ?: return execResult("", "priorities-mobile: add requires DIR and NAME", 2)
                    if (unsafeName(name)) return execResult("", "priorities-mobile: invalid item name", 2)
                    val target = File(resolvePriorityPath(dir), name)
                    prioritize(target, true)
                    if (action == "add-fast") execResult(emitList(resolvePriorityPath(dir))) else execResult("")
                }
                "check-toggle", "check-toggle-fast" -> {
                    val file = resolvePriorityPath(args.getOrNull(1) ?: return execResult("", "priorities-mobile: path required for check-toggle", 2))
                    if (!file.exists()) return execResult("", "priorities-mobile: file not found: ${file.path}", 1)
                    val attrs = readAttrs(file)
                    writeAttrs(file, attrs.copy(checked = if (attrs.checked == 1) 0 else 1))
                    if (action == "check-toggle-fast") execResult(emitList(file.parentFile ?: defaultPriorityRoot())) else execResult("")
                }
                "make-project", "make-project-fast" -> {
                    val file = resolvePriorityPath(args.getOrNull(1) ?: return execResult("", "priorities-mobile: path required for make-project", 2))
                    if (!file.exists()) return execResult("", "priorities-mobile: file not found: ${file.path}", 1)
                    val attrs = readAttrs(file)
                    if (file.isFile) {
                        if (!file.delete()) return execResult("", "priorities-mobile: could not convert file to project: ${file.path}", 1)
                        file.mkdirs()
                    }
                    writeAttrs(file, attrs)
                    if (action == "make-project-fast") execResult(emitList(file.parentFile ?: defaultPriorityRoot())) else execResult("${file.path}\n")
                }
                "rename", "rename-fast" -> {
                    val file = resolvePriorityPath(args.getOrNull(1) ?: return execResult("", "priorities-mobile: rename requires PATH and NAME", 2))
                    val name = args.getOrNull(2) ?: return execResult("", "priorities-mobile: rename requires PATH and NAME", 2)
                    if (unsafeName(name)) return execResult("", "priorities-mobile: invalid rename target name", 2)
                    val dest = File(file.parentFile, name)
                    if (dest.exists()) return execResult("", "priorities-mobile: rename target already exists: $name", 1)
                    if (!file.renameTo(dest)) return execResult("", "priorities-mobile: rename failed: ${file.path}", 1)
                    sidecar(file).renameTo(sidecar(dest))
                    if (action == "rename-fast") execResult(emitList(dest.parentFile ?: defaultPriorityRoot())) else execResult("${dest.path}\n")
                }
                "remove", "remove-fast" -> {
                    val file = resolvePriorityPath(args.getOrNull(1) ?: return execResult("", "priorities-mobile: path required for remove", 2))
                    if (!file.exists()) return execResult("", "priorities-mobile: file not found: ${file.path}", 1)
                    val parent = file.parentFile ?: defaultPriorityRoot()
                    if (!file.deleteRecursively()) return execResult("", "priorities-mobile: remove failed: ${file.path}", 1)
                    sidecar(file).delete()
                    if (action == "remove-fast") execResult(emitList(parent)) else execResult("")
                }
                "descendant-count" -> {
                    val file = resolvePriorityPath(args.getOrNull(1) ?: return execResult("", "priorities-mobile: path required for descendant-count", 2))
                    val count = if (file.isDirectory) file.walkTopDown().drop(1).count { !it.name.endsWith(".xattr.json") } else 0
                    execResult("$count\n")
                }
                "parent" -> {
                    val file = resolvePriorityPath(args.getOrNull(1) ?: return execResult("", "priorities-mobile: parent requires DIR", 2))
                    execResult("${(file.parentFile ?: defaultPriorityRoot()).path}\n")
                }
                "pick-dir" -> {
                    val root = defaultPriorityRoot()
                    root.mkdirs()
                    execResult("${root.path}\n")
                }
                "open-dir" -> execResult("")
                "copy-priorities" -> {
                    val dirArg = args.drop(1).firstOrNull { it != "--expanded" } ?: "."
                    val expanded = args.contains("--expanded")
                    val text = markdown(resolvePriorityPath(dirArg), 0, expanded).trimEnd()
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    clipboard.setPrimaryClip(ClipData.newPlainText("Priorities", text))
                    execResult("$text\n")
                }
                else -> execResult("", "priorities-mobile: unsupported action: $action", 2)
            }
        } catch (t: Throwable) {
            execResult("", "priorities-mobile: ${t.message ?: "operation failed"}", 1)
        }
    }

    private fun execResult(stdout: String, stderr: String = "", exitCode: Int = 0): JSONObject =
        JSONObject().put("stdout", stdout).put("stderr", stderr).put("exit_code", exitCode).put("error", JSONObject.NULL)

    private fun priorityPrefs() = getSharedPreferences("priorities", Context.MODE_PRIVATE)

    private fun readPriorityPrefs(): String {
        val prefs = priorityPrefs().all
        return prefs.keys.sorted().joinToString(separator = "\n", postfix = if (prefs.isEmpty()) "" else "\n") { key ->
            "$key=${prefs[key] ?: ""}"
        }
    }

    private fun defaultPriorityRoot(): File = File(filesDir, "priorities")

    private fun resolvePriorityPath(path: String): File {
        val raw = if (path.isBlank() || path == ".") defaultPriorityRoot().path else path
        val expanded = if (raw == "~") defaultPriorityRoot().path else raw.replaceFirst("~/", defaultPriorityRoot().path + "/")
        return File(expanded).absoluteFile
    }

    private fun unsafeName(name: String): Boolean =
        name.isBlank() || name == "." || name == ".." || name.contains("/") || name.contains("\\") || name.contains("\n") || name.contains("\r")

    private fun sidecar(file: File): File = File(file.parentFile, "${file.name}.xattr.json")

    private fun readAttrs(file: File): PriorityAttrs {
        val side = sidecar(file)
        if (!side.isFile) return PriorityAttrs()
        val attrs = JSONObject(side.readText()).optJSONObject("xattrs") ?: JSONObject()
        return PriorityAttrs(
            attrs.optString("echelon").toIntOrNull() ?: 0,
            attrs.optString("priority").toIntOrNull() ?: 0,
            attrs.optString("checked").toIntOrNull() ?: 0,
            attrs.optString("upvotes").toIntOrNull() ?: 0
        )
    }

    private fun writeAttrs(file: File, attrs: PriorityAttrs) {
        val xattrs = JSONObject()
        if (attrs.echelon > 0) xattrs.put("echelon", attrs.echelon.toString())
        if (attrs.priority > 0) xattrs.put("priority", attrs.priority.toString())
        xattrs.put("checked", attrs.checked.toString())
        if (attrs.upvotes > 0) xattrs.put("upvotes", attrs.upvotes.toString())
        sidecar(file).writeText(JSONObject().put("version", "1").put("docPath", file.name).put("xattrs", xattrs).toString())
    }

    private fun rows(dir: File): List<PriorityRow> =
        (dir.listFiles() ?: emptyArray())
            .filter { !it.name.endsWith(".xattr.json") }
            .mapNotNull { file ->
                val attrs = readAttrs(file)
                if (attrs.echelon <= 0) null else PriorityRow(file, attrs, hasSubpriorities(file))
            }
            .sortedWith(compareByDescending<PriorityRow> { it.attrs.echelon }.thenBy { it.attrs.priority }.thenBy { it.file.name })

    private fun hasSubpriorities(file: File): Boolean =
        file.isDirectory && (file.listFiles() ?: emptyArray()).any { !it.name.endsWith(".xattr.json") && readAttrs(it).echelon > 0 }

    private fun emitList(dir: File): String {
        if (!dir.exists()) dir.mkdirs()
        if (!dir.isDirectory) throw IllegalArgumentException("directory not found: ${dir.path}")
        return rows(dir).joinToString(separator = "\n", postfix = if (rows(dir).isEmpty()) "" else "\n") { row ->
            val kind = if (row.file.isDirectory) "dir" else "file"
            "${row.file.path}\t${row.file.name}\t$kind\t${row.attrs.echelon}\t${row.attrs.priority}\t${row.attrs.checked}\t${row.attrs.upvotes}\t${if (row.hasSubpriorities) 1 else 0}"
        }
    }

    private fun prioritize(file: File, autoCreate: Boolean) {
        if (!file.exists()) {
            if (!autoCreate) throw IllegalArgumentException("file not found: ${file.path}")
            file.parentFile?.mkdirs()
            file.createNewFile()
        }
        val dir = file.parentFile ?: defaultPriorityRoot()
        val current = readAttrs(file)
        val siblingRows = rows(dir)
        val highestEchelon = siblingRows.maxOfOrNull { it.attrs.echelon } ?: 0
        val highestPriority = siblingRows.filter { it.attrs.echelon == highestEchelon }.maxOfOrNull { it.attrs.priority } ?: 0
        val next = when {
            highestEchelon == 0 -> current.copy(echelon = 1, priority = 1, checked = 0)
            current.echelon == highestEchelon && current.echelon > 0 -> current.copy(echelon = highestEchelon + 1, priority = 1, checked = 0)
            else -> current.copy(echelon = highestEchelon, priority = highestPriority + 1, checked = 0)
        }
        writeAttrs(file, next)
    }

    private fun markdown(dir: File, depth: Int, expanded: Boolean): String =
        rows(dir).joinToString(separator = "") { row ->
            val mark = if (row.attrs.checked == 1) "x" else " "
            val line = "${"  ".repeat(depth)}- [$mark] ${row.file.name}\n"
            if (expanded && row.file.isDirectory && row.hasSubpriorities) line + markdown(row.file, depth + 1, true) else line
        }

    private fun rpcError(code: Int, message: String): JSONObject {
        return JSONObject().put("error", JSONObject().put("code", code).put("message", message))
    }

    private fun emitEvent(eventName: String, payload: JSONObject) {
        val interested = subscriptions.values.any { it == eventName }
        if (!interested) {
            return
        }

        val script = """
            if (window.__wizardry_emit) {
              window.__wizardry_emit(${eventName.quoteForJs()}, ${payload.toString()});
            }
        """.trimIndent()

        runOnUiThread {
            webView.evaluateJavascript(script, null)
        }
    }

    private fun respond(id: String, payload: JSONObject) {
        val safeId = id.replace("\\", "\\\\").replace("'", "\\'")
        val script = """
            if (window.__wizardry_callbacks && window.__wizardry_callbacks['$safeId']) {
              window.__wizardry_callbacks['$safeId'](${payload.toString()});
              delete window.__wizardry_callbacks['$safeId'];
            }
        """.trimIndent()

        runOnUiThread {
            webView.evaluateJavascript(script, null)
        }
    }

    private fun String.quoteForJs(): String {
        val escaped = this.replace("\\", "\\\\").replace("'", "\\'")
        return "'$escaped'"
    }
}
