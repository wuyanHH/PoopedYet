package com.poopedyet.app.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import com.poopedyet.app.MainActivity
import com.poopedyet.app.R

/**
 * 屙了么 · 如厕实时灵动胶囊 & 前台计时通知服务
 *
 * 兼容各厂商挖孔屏灵动胶囊（小米 HyperOS 焦点通知 / OPPO 流体云 / vivo 原生通知胶囊 / 华为实况窗）
 * 并为锁屏提供一键完事的快捷操作面板。
 */
class PoopLiveService : Service {

    constructor() : super()

    companion object {
        // 使用 v3 渠道强制在真机上建立 IMPORTANCE_HIGH 高优先级通知渠道，才能被 vivo OriginOS 原子岛/状态栏胶囊、小米 HyperOS、OPPO 流体云识别
        const val CHANNEL_ID = "poop_live_island_v3"
        const val NOTIFICATION_ID = 9527

        const val ACTION_START_LIVE = "com.poopedyet.app.START_LIVE"
        const val ACTION_STOP_LIVE = "com.poopedyet.app.STOP_LIVE"

        const val EXTRA_RECORD_ID = "extra_record_id"
        const val EXTRA_POOPER_NAME = "extra_pooper_name"
        const val EXTRA_STARTED_AT = "extra_started_at"
        const val EXTRA_IS_INCOGNITO = "extra_is_incognito"

        fun start(
            context: Context,
            recordId: String,
            pooperName: String,
            startedAtMillis: Long,
            isIncognito: Boolean
        ) {
            val intent = Intent(context, PoopLiveService::class.java).apply {
                action = ACTION_START_LIVE
                putExtra(EXTRA_RECORD_ID, recordId)
                putExtra(EXTRA_POOPER_NAME, pooperName)
                putExtra(EXTRA_STARTED_AT, startedAtMillis)
                putExtra(EXTRA_IS_INCOGNITO, isIncognito)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, PoopLiveService::class.java).apply {
                action = ACTION_STOP_LIVE
            }
            context.startService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || intent.action == ACTION_STOP_LIVE) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        if (intent.action == ACTION_START_LIVE) {
            val recordId = intent.getStringExtra(EXTRA_RECORD_ID) ?: ""
            val pooperName = intent.getStringExtra(EXTRA_POOPER_NAME) ?: "我"
            val startedAt = intent.getLongExtra(EXTRA_STARTED_AT, System.currentTimeMillis())
            val isIncognito = intent.getBooleanExtra(EXTRA_IS_INCOGNITO, false)

            val notification = buildLiveNotification(recordId, pooperName, startedAt, isIncognito)
            
            try {
                // 兼容 Android 14+ 必须显式声明前台服务类型的要求，防止抛出 MissingForegroundServiceTypeException 崩溃
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            } catch (e: Exception) {
                try {
                    startForeground(NOTIFICATION_ID, notification)
                } catch (ex: Exception) {
                    // 兜底防止后台启动前台服务受限异常
                }
            }
        }

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // 当用户从系统多任务列表中彻底划掉应用时，优雅注销前台计时服务与常驻通知
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "如厕实时活动与灵动胶囊"
            val desc = "在进行排便时展示实时秒表与一键完成操作"
            // 必须设为 IMPORTANCE_HIGH 才能被 vivo OriginOS 原子岛/状态栏胶囊与浮动通知捕获
            val channel = NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_HIGH).apply {
                description = desc
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableVibration(false)
                setSound(null, null)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildLiveNotification(
        recordId: String,
        pooperName: String,
        startedAtMillis: Long,
        isIncognito: Boolean
    ): Notification {
        // 计算 Chronometer 基准时间：SystemClock.elapsedRealtime - 已过去的毫秒
        val elapsedRealtime = SystemClock.elapsedRealtime()
        val durationAlready = (System.currentTimeMillis() - startedAtMillis).coerceAtLeast(0)
        val baseChronometerTime = elapsedRealtime - durationAlready

        // 点击通知主体：打开主页
        val openIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("poopedyet://main")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            this, 5001, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 点击操作按钮：一键完成并记录
        val finishIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("poopedyet://action/finish?recordId=$recordId")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val finishPendingIntent = PendingIntent.getActivity(
            this, 5002, finishIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (isIncognito) "🧻 $pooperName 正在深度放空中..." else "🧻 $pooperName 正在如厕中..."
        val subText = if (isIncognito) "身心减负中" else "如厕计时进行中"
        val contentText = if (isIncognito) "正在深度放空，身心减负中..." else "正在如厕计时中，点击进入应用"
        val finishBtnText = if (isIncognito) "放空达成" else "完成打卡"

        val extras = Bundle().apply {
            // 小米 HyperOS 澎湃 OS 焦点通知 / 灵动胶囊识别
            putString("android.substName", "屙了么")
            putBoolean("miui.enableFloat", true)
            putBoolean("miui.enableKeyguard", true)
            putBoolean("show_when_locked", true)
            // OPPO / 一加 / realme (ColorOS 14+) 流体云胶囊识别
            putBoolean("com.coloros.notification.capsule", true)
            putString("com.coloros.notification.capsule_type", "stopwatch")
            // vivo OriginOS 原子岛
            putBoolean("vivo.summaryNotification", false)
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_live_notification)
            .setContentTitle(title)
            .setContentText(contentText)
            .setSubText(subText)
            .setContentIntent(openPendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            // Android 12+ 立即展示前台通知，杜绝 10 秒延迟展示
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            // 必须设置 PRIORITY_MAX 才能触发 vivo OriginOS 的原子通知/原子岛状态栏胶囊与锁屏浮窗
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setTicker(title)
            // 启用系统级秒表计时器（精准跳秒、极其省电）
            .setUsesChronometer(true)
            .setChronometerCountDown(false)
            .setWhen(baseChronometerTime)
            // CATEGORY_STOPWATCH 是厂商灵动胶囊识别的核心标记
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setColor(0xFFA85F29.toInt()) // 焦糖品牌色
            .setExtras(extras)
            // 添加一键完成 Action 按钮：统一使用鼠尾草绿对勾卷纸完成图标 (ic_widget_action_finish)
            .addAction(R.drawable.ic_widget_action_finish, finishBtnText, finishPendingIntent)

        val notification = builder.build()
        // 显式标记 ONGOING 状态
        notification.flags = notification.flags or Notification.FLAG_ONGOING_EVENT
        return notification
    }
}
