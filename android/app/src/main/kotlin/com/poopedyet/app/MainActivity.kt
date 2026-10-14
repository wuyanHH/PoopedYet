package com.poopedyet.app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import com.poopedyet.app.service.PoopLiveService
import com.poopedyet.app.widget.WidgetDataProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {

    private val CHANNEL_NAME = "com.poopedyet.app/widget"
    private val BACKUP_CHANNEL_NAME = "com.poopedyet.app/backup"
    private var methodChannel: MethodChannel? = null
    private var backupChannel: MethodChannel? = null
    private var pendingDeepLink: String? = null
    private var pendingFilePickerResult: MethodChannel.Result? = null

    companion object {
        private const val REQUEST_CODE_PICK_FILE = 10086
        private const val REQUEST_CODE_NOTIFICATION = 10087
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        checkAndRequestNotificationPermission()
    }

    private fun checkAndRequestNotificationPermission() {
        // 在 Android 13+ (vivo OriginOS 6 基于 Android 15) 上，动态请求通知权限，否则所有前台通知与原子岛胶囊均会被系统静默拦截
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE_NOTIFICATION)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val uri: Uri? = intent?.data
        if (uri != null && uri.scheme == "poopedyet") {
            val link = uri.toString()
            if (methodChannel != null) {
                methodChannel?.invokeMethod("onDeepLink", link)
            } else {
                pendingDeepLink = link
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_FILE) {
            val callback = pendingFilePickerResult
            pendingFilePickerResult = null
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                try {
                    val fileUri = data.data!!
                    val inputStream = contentResolver.openInputStream(fileUri)
                    if (inputStream != null) {
                        val reader = BufferedReader(InputStreamReader(inputStream, Charsets.UTF_8))
                        val content = reader.use { it.readText() }
                        callback?.success(content)
                    } else {
                        callback?.error("READ_FAIL", "无法打开所选文件数据流", null)
                    }
                } catch (e: Exception) {
                    callback?.error("READ_ERROR", "读取文件失败: ${e.message}", null)
                }
            } else {
                // 用户取消选择
                callback?.success(null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateSnapshot" -> {
                    val jsonStr = call.argument<String>("snapshotJson")
                    if (jsonStr != null) {
                        WidgetDataProvider.saveSnapshot(context, jsonStr)

                        // 联动实时灵动胶囊 / 锁屏前台计时服务
                        try {
                            val json = JSONObject(jsonStr)
                            val liveSession = json.optJSONObject("liveSession")
                            val isLive = liveSession?.optBoolean("isLive", false) ?: false
                            if (isLive) {
                                val recordId = liveSession?.optString("recordId", "") ?: ""
                                val startedAt = liveSession?.optLong("startedAtMillis", System.currentTimeMillis()) ?: System.currentTimeMillis()
                                val defaultPooper = json.optJSONObject("defaultPooper")
                                val pooperName = defaultPooper?.optString("name", "我") ?: "我"
                                val isIncognito = json.optBoolean("isIncognito", false)

                                PoopLiveService.start(context, recordId, pooperName, startedAt, isIncognito)
                            } else {
                                PoopLiveService.stop(context)
                            }
                        } catch (e: Exception) {
                            // 忽略解析非致命错误
                        }

                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "snapshotJson is null", null)
                    }
                }
                "getPendingDeepLink" -> {
                    val link = pendingDeepLink
                    pendingDeepLink = null
                    result.success(link)
                }
                "requestNotificationPermission" -> {
                    checkAndRequestNotificationPermission()
                    result.success(true)
                }
                "isNotificationEnabled" -> {
                    val enabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
                    result.success(enabled)
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("OPEN_SETTINGS_FAILED", e2.message, null)
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 本地备份文件安全分享与外部文件选择通道
        backupChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKUP_CHANNEL_NAME)
        backupChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "shareFile" -> {
                    val filePath = call.argument<String>("filePath")
                    val title = call.argument<String>("title") ?: "分享备份文件"
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            if (!file.exists()) {
                                result.error("NOT_FOUND", "备份文件不存在: $filePath", null)
                                return@setMethodCallHandler
                            }

                            val contentUri = FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )

                            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "application/json"
                                putExtra(Intent.EXTRA_STREAM, contentUri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }

                            val chooser = Intent.createChooser(shareIntent, title)
                            startActivity(chooser)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", "调起分享失败: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARG", "filePath is null", null)
                    }
                }
                "pickFile" -> {
                    try {
                        pendingFilePickerResult = result
                        val pickIntent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
                        }
                        startActivityForResult(pickIntent, REQUEST_CODE_PICK_FILE)
                    } catch (e: Exception) {
                        // 尝试以 ACTION_GET_CONTENT 兜底
                        try {
                            val fallbackIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
                                type = "*/*"
                            }
                            startActivityForResult(fallbackIntent, REQUEST_CODE_PICK_FILE)
                        } catch (ex: Exception) {
                            pendingFilePickerResult = null
                            result.error("PICK_ERROR", "打开系统文件选择器失败: ${ex.message}", null)
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 如果冷启动时有排队的 DeepLink，且此时引擎已就绪，向 Flutter 发送并重置排队状态，防止二次拉取重复执行
        pendingDeepLink?.let { link ->
            pendingDeepLink = null
            methodChannel?.invokeMethod("onDeepLink", link)
        }
    }
}
