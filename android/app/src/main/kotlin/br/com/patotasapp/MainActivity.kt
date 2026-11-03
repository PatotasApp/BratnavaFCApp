package br.com.patotasapp

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
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
                    "instagramStory" -> result.success(shareToInstagramStory(uri))
                    "copyImage" -> result.success(copyImage(uri))
                    else -> result.notImplemented()
                }
            }
    }

    /** Abre o Instagram direto no story com a imagem de fundo. false = Instagram não instalado. */
    private fun shareToInstagramStory(uri: Uri): Boolean {
        val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
            setDataAndType(uri, "image/png")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            putExtra("source_application", packageName)
        }
        grantUriPermission(INSTAGRAM, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        if (intent.resolveActivity(packageManager) == null) return false
        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    private fun copyImage(uri: Uri): Boolean {
        val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newUri(contentResolver, "PatotasApp", uri))
        return true
    }

    private companion object {
        const val INSTAGRAM = "com.instagram.android"
    }
}
