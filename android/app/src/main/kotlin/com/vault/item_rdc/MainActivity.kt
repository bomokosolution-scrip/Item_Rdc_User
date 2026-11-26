package com.vault.itemrdc

import android.app.DownloadManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Canal natif utilisé par le système de mise à jour intégré :
 * version installée, autorisation d'installer, installation de l'APK téléchargé,
 * désinstallation et copie de l'APK dans « Téléchargements ».
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.vault.itemrdc/updater"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    /** Canal « importance haute » : les notifications push apparaissent en bandeau, avec son. */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                "item_rdc_high",
                "Annonces Item RDC",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Nouveautés et annonces d'Item RDC"
            manager.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "appInfo" -> {
                            val info = packageManager.getPackageInfo(packageName, 0)
                            val code: Long = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                info.longVersionCode
                            } else {
                                @Suppress("DEPRECATION")
                                info.versionCode.toLong()
                            }
                            result.success(
                                mapOf(
                                    "versionName" to (info.versionName ?: ""),
                                    "versionCode" to code,
                                    "sdkInt" to Build.VERSION.SDK_INT,
                                    "release" to (Build.VERSION.RELEASE ?: ""),
                                    "packageName" to packageName
                                )
                            )
                        }

                        "canInstall" -> {
                            val ok = Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                                packageManager.canRequestPackageInstalls()
                            result.success(ok)
                        }

                        "openInstallSettings" -> {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        }

                        "installApk" -> {
                            val path = call.argument<String>("path")
                                ?: throw IllegalArgumentException("path manquant")
                            installApk(File(path))
                            result.success(true)
                        }

                        "saveToDownloads" -> {
                            val path = call.argument<String>("path")
                                ?: throw IllegalArgumentException("path manquant")
                            val name = call.argument<String>("name") ?: "item_rdc.apk"
                            result.success(saveToDownloads(File(path), name))
                        }

                        "uninstall" -> {
                            val intent = Intent(
                                Intent.ACTION_DELETE,
                                Uri.parse("package:$packageName")
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        }

                        "setSecure" -> {
                            val secure = call.argument<Boolean>("secure") ?: false
                            if (secure) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                            result.success(true)
                        }

                        "openDownloads" -> {
                            val intent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        }

                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("UPDATER_ERROR", e.message, null)
                }
            }
    }

    /**
     * Installe l'APK : d'abord par l'installateur système (FileProvider) ;
     * si cela échoue sur ce téléphone, bascule sur la méthode « session »
     * (PackageInstaller), qui n'a besoin d'aucun FileProvider.
     */
    private fun installApk(file: File) {
        if (!file.exists()) throw IllegalStateException("Fichier APK introuvable")
        try {
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (first: Exception) {
            try {
                installWithSession(file)
            } catch (second: Exception) {
                throw IllegalStateException("${first.message} / ${second.message}")
            }
        }
    }

    private fun installWithSession(file: File) {
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setSize(file.length())
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            file.inputStream().use { input ->
                session.openWrite("item_rdc.apk", 0, file.length()).use { out ->
                    input.copyTo(out)
                    session.fsync(out)
                }
            }
            val intent = Intent(this, InstallResultReceiver::class.java)
                .setAction("com.vault.itemrdc.INSTALL_RESULT")
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
            val pending = PendingIntent.getBroadcast(this, sessionId, intent, flags)
            session.commit(pending.intentSender)
        }
    }

    /** Copie l'APK dans le dossier public « Téléchargements » (survit à la désinstallation). */
    private fun saveToDownloads(src: File, name: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, "application/vnd.android.package-archive")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Impossible de créer le fichier")
            resolver.openOutputStream(uri)?.use { out ->
                src.inputStream().use { input -> input.copyTo(out) }
            } ?: throw IllegalStateException("Impossible d'écrire le fichier")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return "Téléchargements/$name"
        } else {
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            dir.mkdirs()
            val dest = File(dir, name)
            src.copyTo(dest, overwrite = true)
            return dest.absolutePath
        }
    }
}
