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

    /**
     * Dart 侧的 Deep Link 处理函数是否已经注册好。
     *
     * 冷启动时的时序是这样的：`onCreate` → `configureFlutterEngine`（原生这边
     * 通道就绪）→ **Dart 的 main() 才开始跑** → 启动页 → 主页才
     * `setMethodCallHandler`。也就是说在 `configureFlutterEngine` 里
     * `invokeMethod("onDeepLink")` 是**百分之百丢**：Dart 那边还没有 handler，
     * 调用被直接丢弃，而排队字段又已经被清空，Dart 稍后主动来拉也拉不到 ——
     * 于是「通知栏/锁屏点完成打卡，App 打开了但记录没结束」。
     *
     * 现在改成拉取式握手：Dart 首次调用 `getPendingDeepLink` 就说明它已就绪，
     * 那之前来的链接一律先排队，那之后来的才直接推。
     */
    private var dartReady = false

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
            pushDeepLink(uri.toString())
        }
    }

    /**
     * 把一个 Deep Link 交给 Dart 侧处理。
     *
     * Dart 已就绪就直接推；否则存进 [pendingDeepLink] 等它自己来取 ——
     * 排队字段保持"最后一次请求生效"，用户连点两下时按后一次执行。
     */
    private fun pushDeepLink(link: String) {
        val channel = methodChannel
        if (dartReady && channel != null) {
            channel.invokeMethod("onDeepLink", link)
        } else {
            pendingDeepLink = link
        }
    }

    /// 本应用当前是否被允许「安装未知来源应用」。
    ///
    /// Android 8.0 才有这个概念，更低版本一律视为已授权。
    private fun canInstallApk(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    /// 安装失败的结构化返回。Dart 侧按 `code` 决定引导文案与跳转目标。
    private fun installFailure(code: String): Map<String, Any?> {
        return mapOf("ok" to false, "code" to code)
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

        // FlutterActivity 不缓存引擎，Activity 重建就等于换了一个全新的 Dart isolate，
        // 上一轮注册的 Deep Link handler 随之消失 —— 所以这里必须把就绪标志归零，
        // 让这段时间里到达的链接重新回到排队状态，等新 isolate 起来再领走。
        dartReady = false

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // 快照推送 / 绑定读写统一在下面的 else 分支委托给 WidgetChannelHandler：
                // 后台执行小组件动作时用的是同一份实现，两边行为不会漂移。
                "getPendingDeepLink" -> {
                    // Dart 能调到这一步，说明它的 setMethodCallHandler 已经挂上了，
                    // 之后来的 Deep Link 都可以直接推给它。
                    dartReady = true
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
                // ---- 应用内更新：安装未知来源 APK ----
                // Dart 侧负责下载到应用私有目录（files/updates/），原生只负责把文件
                // 交给系统安装器。返回的是结构化结果而不是抛异常 —— 「没授权」和
                // 「文件不存在」是两种完全不同的用户引导，不能混成一句报错。
                "canInstallApk" -> {
                    result.success(canInstallApk())
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrBlank()) {
                        result.success(installFailure("INVALID_ARG"))
                        return@setMethodCallHandler
                    }
                    if (!canInstallApk()) {
                        result.success(installFailure("NEED_PERMISSION"))
                        return@setMethodCallHandler
                    }
                    val apkFile = File(filePath)
                    if (!apkFile.exists() || apkFile.length() <= 0L) {
                        result.success(installFailure("NOT_FOUND"))
                        return@setMethodCallHandler
                    }
                    try {
                        // 必须走 FileProvider：Android 7.0 起直接把 file:// 路径
                        // 塞进 Intent 会触发 FileUriExposedException。
                        val apkUri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            apkFile
                        )
                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        if (installIntent.resolveActivity(packageManager) == null) {
                            result.success(installFailure("NO_INSTALLER"))
                            return@setMethodCallHandler
                        }
                        startActivity(installIntent)
                        result.success(mapOf("ok" to true))
                    } catch (e: Exception) {
                        result.success(
                            installFailure("FAILED").toMutableMap().apply {
                                put("message", e.message ?: "")
                            }
                        )
                    }
                }
                // 把用户送到本应用的「安装未知应用」授权页。
                // 老系统（< 8.0）没有这个概念，直接当成功处理。
                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                        result.success(true)
                    } else {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.fromParts("package", packageName, null)
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                // 个别定制 ROM 收起了该页面，退回应用详情页让用户自己找。
                                val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.fromParts("package", packageName, null)
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(fallback)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.success(false)
                            }
                        }
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

        // ⚠ 这里刻意**不**做「把排队的 Deep Link 推给 Flutter」。
        //
        // 曾经在这里 `invokeMethod("onDeepLink")`，但那一刻 Dart 的 main() 还没开始跑，
        // 更没注册 setMethodCallHandler —— 调用被静默丢弃，排队字段又被清空，
        // 于是冷启动的 deep link（例如锁屏胶囊的「完成打卡」）彻底丢失。
        // 现在统一由 Dart 侧主动调用 getPendingDeepLink 领取，见 pushDeepLink()。
    }
}
