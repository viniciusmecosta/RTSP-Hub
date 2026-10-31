package com.rtsp.rtsp_hub

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var fileChannel: MethodChannel? = null
    private var pendingFilePayload: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.let { handleFileIntent(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleFileIntent(intent)
    }

    private fun handleFileIntent(intent: Intent) {
        val action = intent.action
        val resolvedUri: Uri? = when (action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
            }
            else -> null
        }
        val targetUri: Uri = resolvedUri ?: return

        try {
            val content = contentResolver.openInputStream(targetUri)?.bufferedReader()?.use { it.readText() }
            if (content.isNullOrBlank()) return

            var fileName = "backup.json"
            try {
                contentResolver.query(targetUri, null, null, null, null)?.use { cursor ->
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex != -1 && cursor.moveToFirst()) {
                        cursor.getString(nameIndex)?.let { fileName = it }
                    }
                }
            } catch (_: Exception) {
                targetUri.lastPathSegment?.let { fileName = it }
            }

            val payload = mapOf("name" to fileName, "content" to content)
            val channel = fileChannel
            if (channel != null) {
                channel.invokeMethod("onFileReceived", payload)
            } else {
                pendingFilePayload = payload
            }
        } catch (_: Exception) {
            // Ignora URIs ilegíveis sem interromper a execução do app
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rtsp.rtsp_hub/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "isTelevision") {
                    val uiMode = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                    result.success(
                        uiMode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
                            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK),
                    )
                } else {
                    result.notImplemented()
                }
            }

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rtsp.rtsp_hub/file_import")
        fileChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFile" -> {
                    val payload = pendingFilePayload
                    pendingFilePayload = null
                    result.success(payload)
                }
                else -> result.notImplemented()
            }
        }

        pendingFilePayload?.let { payload ->
            channel.invokeMethod("onFileReceived", payload)
            pendingFilePayload = null
        }
    }
}
