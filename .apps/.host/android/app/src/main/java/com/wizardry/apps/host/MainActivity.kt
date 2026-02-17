package com.wizardry.apps.host

import android.annotation.SuppressLint
import android.os.Bundle
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import org.json.JSONArray
import org.json.JSONObject
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

            else -> respond(id, rpcError(-32601, "method not found"))
        }
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
