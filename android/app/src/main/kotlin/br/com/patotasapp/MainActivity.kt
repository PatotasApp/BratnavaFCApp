package br.com.patotasapp

import android.content.ClipData
import android.content.ClipboardManager
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Compartilhar imagem gerada no app (lib/core/share/image_share.dart).
        // O Dart grava o PNG em cache/share/ e manda o caminho.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "br.com.patotasapp/image_share")
            .setMethodCallHandler { call, result ->
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("args", "Caminho da imagem ausente.", null)
                    return@setMethodCallHandler
                }
                val uri = try {
                    FileProvider.getUriForFile(this, "$packageName.imageshare", File(path))
                } catch (e: IllegalArgumentException) {
                    result.error("path", e.message, null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "copyImage" -> result.success(copyImage(uri))
                    else -> result.notImplemented()
                }
            }
    }

    private fun copyImage(uri: Uri): Boolean {
        val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newUri(contentResolver, "PatotasApp", uri))
        return true
    }
}
