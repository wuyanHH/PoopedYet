package com.poopedyet.app

import android.Manifest
import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ClipData
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import com.poopedyet.app.service.PoopLiveService
import com.poopedyet.app.widget.LargeWidgetProvider
import com.poopedyet.app.widget.MediumWidgetProvider
import com.poopedyet.app.widget.SmallWidgetProvider
import com.poopedyet.app.widget.WidgetChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
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
                // 快照推送 / 绑定读写统一在下面的 else 分支委托给 WidgetChannelHandler：
                // 后台执行小组件动作时用的是同一份实现，两边行为不会漂移。
                "getPendingDeepLink" -> {
                    val link = pendingDeepLink
                    pendingDeepLink = null
                    result.success(link)
                }
                // 从 App 内一键把小组件钉到桌面（Android 8.0+ 支持）。
                // 返回 false 表示当前启动器不支持，调用方应引导用户手动长按桌面添加。
                "requestPinWidget" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                        result.success(false)
                    } else {
                        val type = call.argument<String>("type") ?: "small"
                        val provider = when (type) {
                            "medium" -> ComponentName(this, MediumWidgetProvider::class.java)
                            "large" -> ComponentName(this, LargeWidgetProvider::class.java)
                            else -> ComponentName(this, SmallWidgetProvider::class.java)
                        }
                        val manager = AppWidgetManager.getInstance(this)
                        if (manager.isRequestPinAppWidgetSupported) {
                            result.success(manager.requestPinAppWidget(provider, null, null))
                        } else {
                            result.success(false)
                        }
                    }
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
                    // 优先直达「如厕实时活动与状态栏胶囊」专属渠道设置，方便 vivo / 小米用户直接开启「悬浮通知」与「锁屏显示」
                    val channelIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            putExtra(Settings.EXTRA_CHANNEL_ID, PoopLiveService.CHANNEL_ID)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                    } else null

                    try {
                        if (channelIntent != null && channelIntent.resolveActivity(packageManager) != null) {
                            startActivity(channelIntent)
                            result.success(true)
                            return@setMethodCallHandler
                        }
                    } catch (_: Exception) {}

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
                "getDeviceAbi" -> {
                    // 获取当前 Android 硬件设备支持的首选指令集架构
                    val abi = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        Build.SUPPORTED_ABIS.firstOrNull() ?: "universal"
                    } else {
                        @Suppress("DEPRECATION")
                        Build.CPU_ABI ?: "universal"
                    }
                    result.success(abi)
                }
                "openUrl" -> {
                    val urlStr = call.argument<String>("url")
                    if (!urlStr.isNullOrBlank()) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(urlStr)).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_URL_FAILED", "无法唤起浏览器打开链接: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARG", "url is null or empty", null)
                    }
                }
                else -> {
                    // 小组件通道里与 Activity 无关的那几个方法（快照推送、绑定读写）
                    // 统一交给 WidgetChannelHandler —— 后台无界面引擎用的是同一份实现。
                    if (WidgetChannelHandler.handle(context, call, result)) {
                        return@setMethodCallHandler
                    }
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
                            val originalFile = File(filePath)
                            if (!originalFile.exists()) {
                                result.error("NOT_FOUND", "备份文件不存在: $filePath", null)
                                return@setMethodCallHandler
                            }

                            // 优先尝试原路径 FileProvider；若受限则安全同步到 cacheDir 后分享
                            val contentUri: Uri = try {
                                FileProvider.getUriForFile(
                                    this,
                                    "${applicationContext.packageName}.fileprovider",
                                    originalFile
                                )
                            } catch (e: Exception) {
                                val shareCacheDir = File(cacheDir, "backups").apply { if (!exists()) mkdirs() }
                                val cachedFile = File(shareCacheDir, originalFile.name)
                                originalFile.copyTo(cachedFile, overwrite = true)
                                FileProvider.getUriForFile(
                                    this,
                                    "${applicationContext.packageName}.fileprovider",
                                    cachedFile
                                )
                            }

                            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "application/json"
                                putExtra(Intent.EXTRA_STREAM, contentUri)
                                clipData = ClipData.newRawUri("backup", contentUri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }

                            val chooser = Intent.createChooser(shareIntent, title).apply {
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }

                            // 为所有匹配的目标组件授予临时 URI 读权限
                            val resInfoList = packageManager.queryIntentActivities(chooser, PackageManager.MATCH_DEFAULT_ONLY)
                            for (resolveInfo in resInfoList) {
                                val packageName = resolveInfo.activityInfo.packageName
                                grantUriPermission(packageName, contentUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }

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
