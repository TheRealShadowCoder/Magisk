package com.topjohnwu.magisk.core

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.util.Log
import java.io.File
import java.io.FileOutputStream

/**
 * FXGA always-on bounded application-event telemetry.
 * Never records arguments, input text, token contents, or third-party app data.
 * Native/crash evidence remains separate and requires explicit user export.
 */
object FxgaTelemetry {
    private const val TAG = "FXGAMagisk"
    private const val MAX_BYTES = 524288L
    private val lock = Any()
    @Volatile private var app: Application? = null

    fun install(application: Application) {
        if (app != null) return
        app = application
        application.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, state: Bundle?) =
                event("activity.created." + activity.javaClass.simpleName)
            override fun onActivityStarted(activity: Activity) =
                event("activity.started." + activity.javaClass.simpleName)
            override fun onActivityResumed(activity: Activity) =
                event("activity.resumed." + activity.javaClass.simpleName)
            override fun onActivityPaused(activity: Activity) =
                event("activity.paused." + activity.javaClass.simpleName)
            override fun onActivityStopped(activity: Activity) =
                event("activity.stopped." + activity.javaClass.simpleName)
            override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) = Unit
            override fun onActivityDestroyed(activity: Activity) =
                event("activity.destroyed." + activity.javaClass.simpleName)
        })
        event("application.start")
    }

    fun event(name: String) {
        val safe = name.replace(Regex("[^A-Za-z0-9_.:-]"), "_").take(120)
        Log.i(TAG, "event=" + safe)
        val ctx = app ?: return
        synchronized(lock) {
            runCatching {
                val file = File(ctx.filesDir, "fxga_events.log")
                if (file.exists() && file.length() >= MAX_BYTES) {
                    val old = File(ctx.filesDir, "fxga_events.previous.log")
                    old.delete()
                    file.renameTo(old)
                }
                FileOutputStream(file, true).bufferedWriter().use {
                    it.append(System.currentTimeMillis().toString()).append(" event=")
                        .append(safe).append('\n')
                }
            }.onFailure { Log.w(TAG, "Local journal failed: " + it.javaClass.simpleName) }
        }
    }
}
