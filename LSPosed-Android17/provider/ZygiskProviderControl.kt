package org.matrix.vector.daemon.utils

import android.os.Build
import android.util.Log
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Root-side, Android 17-only provider selection bridge.
 *
 * The controller is installed with Vector and runs in the daemon's root context.
 * It stages changes for the NEXT boot, never kills Zygote and never reboots.
 * The manager always renders the exact result, including failure text.
 */
object ZygiskProviderControl {
  private const val TAG = "VectorProviderControl"
  private val script = File("/data/adb/modules/zygisk_vector/a17-provider-control.sh")

  fun status(): String = run("status")

  fun select(mode: String): String {
    if (mode !in setOf("auto", "magisk", "rezygisk")) return "error=Invalid provider choice"
    return run("select", mode)
  }

  private fun run(action: String, mode: String? = null): String {
    if (Build.VERSION.SDK_INT != 37) return "error=Only Android 17 API 37 is supported"
    if (!script.isFile || !script.canRead()) {
      return "error=Provider controller unavailable; install the matching Vector framework ZIP"
    }
    val command = mutableListOf("/system/bin/sh", script.absolutePath, action)
    if (mode != null) command.add(mode)
    return try {
      val process = ProcessBuilder(command).redirectErrorStream(true).start()
      if (!process.waitFor(12, TimeUnit.SECONDS)) {
        process.destroyForcibly()
        "error=Provider action timed out; check root and provider logs"
      } else {
        val output = process.inputStream.bufferedReader().use { it.readText() }.trim()
        if (process.exitValue() == 0) output.ifBlank { "error=Empty provider response" }
        else output.ifBlank { "error=Provider command failed (exit ${process.exitValue()})" }
      }
    } catch (e: Exception) {
      Log.e(TAG, "Provider operation failed", e)
      "error=Provider operation failed: ${e.javaClass.simpleName}"
    }
  }
}
