package com.topjohnwu.magisk.ui.zygisk

import android.content.pm.ApplicationInfo
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.topjohnwu.magisk.core.FxgaTelemetry
import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.ui.MagiskTheme
import com.topjohnwu.magisk.core.model.module.LocalModule
import com.topjohnwu.superuser.Shell
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/**
 * Diagnostic evidence only. A module on disk is not proof of runtime compatibility.
 * The user explicitly selects an app and destination before private logs are exported.
 */
class FxgaCompatibilityActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MagiskTheme { CompatibilityPage() } }
    }
}

private data class AppRow(val pkg: String, val name: String, val process: String, val system: Boolean)
private data class ModuleRow(val id: String, val issue: String)
private data class ScanState(
    val apps: List<AppRow> = emptyList(),
    val issues: List<ModuleRow> = emptyList(),
    val excluded: Set<String> = emptySet(),
    val denyEnforced: Boolean = false,
    val error: String? = null,
)

private fun validName(s: String) = s.matches(Regex("[A-Za-z0-9_.:]+")) && s.length <= 180

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FxgaCompatibilityActivity.CompatibilityPage() {
    val scope = rememberCoroutineScope()
    val prefs = remember { getSharedPreferences("fxga_compat", MODE_PRIVATE) }
    var state by remember { mutableStateOf(ScanState()) }
    var search by remember { mutableStateOf("") }
    var selected by remember { mutableStateOf<AppRow?>(null) }
    var message by remember { mutableStateOf("Loading compatibility information…") }
    var busy by remember { mutableStateOf(false) }
    var confirmAction by remember { mutableStateOf<(() -> Unit)?>(null) }
    val exportZip = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/zip")
    ) { uri ->
        val app = selected
        if (uri != null && app != null) scope.launch {
            busy = true
            val result = withContext(Dispatchers.IO) {
                runCatching {
                    val info = buildString {
                        appendLine("FXGA compatibility evidence")
                        appendLine("Package: " + app.pkg)
                        appendLine("Process: " + app.process)
                        appendLine("SDK: " + android.os.Build.VERSION.SDK_INT)
                        appendLine("Zygisk running: " + Info.isZygiskEnabled)
                        appendLine("DenyList enforced: " + state.denyEnforced)
                        appendLine("Marked problematic: " + prefs.getBoolean(app.pkg, false))
                        appendLine("This report includes only package-linked crash evidence; absence of lines does not prove compatibility.")
                    }
                    // Narrow log collection to avoid exporting unrelated app/user data.
                    val crash = Shell.cmd("logcat -d -t 2000 -v brief AndroidRuntime:E DEBUG:E linker:E FXGAMagisk:I *:S")
                        .exec().out.asSequence()
                        .filter { it.contains(app.pkg, true) || it.contains("FXGAMagisk") }
                        .take(300).joinToString("\n").take(64000)
                    contentResolver.openOutputStream(uri)?.use { stream ->
                        ZipOutputStream(stream).use { zip ->
                            zip.putNextEntry(ZipEntry("compatibility.txt"))
                            zip.write(info.toByteArray(Charsets.UTF_8))
                            zip.closeEntry()
                            zip.putNextEntry(ZipEntry("selected-crash-excerpt.txt"))
                            zip.write(crash.toByteArray(Charsets.UTF_8))
                            zip.closeEntry()
                        }
                    } ?: error("Cannot open selected ZIP destination")
                }
            }
            message = result.fold({ "Diagnostic ZIP exported for " + app.pkg },
                { "ZIP export failed: " + it.javaClass.simpleName })
            FxgaTelemetry.event("compat.export")
            busy = false
        }
    }

    suspend fun refresh() {
        busy = true
        val newState = withContext(Dispatchers.IO) {
            runCatching {
                val pm = packageManager
                val apps = pm.getInstalledApplications(0).map { info ->
                    AppRow(info.packageName, info.loadLabel(pm).toString(),
                        info.processName ?: info.packageName,
                        (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0)
                }.filter { validName(it.pkg) && validName(it.process) }
                    .sortedBy { it.name.lowercase() }
                val deny = Shell.cmd("magisk --denylist ls").exec()
                val enforced = Shell.cmd("magisk --denylist status").exec().isSuccess
                val excluded = if (deny.isSuccess) {
                    deny.out.map { it.substringBefore('|') }.toSet()
                } else emptySet()
                val issues = LocalModule.installed().mapNotNull { module ->
                    val issue = when {
                        !module.enable -> null
                        module.isRiru -> "Old Riru module format is not native Zygisk"
                        module.zygiskUnloaded -> "Zygisk loader reported this module unloaded"
                        else -> null
                    }
                    if (issue != null) ModuleRow(module.id, issue) else null
                }
                ScanState(apps, issues, excluded, enforced,
                    if (deny.isSuccess) null else "DenyList access needs root authorization")
            }.getOrElse { ScanState(error = "Cannot scan: " + it.javaClass.simpleName) }
        }
        state = newState
        message = newState.error ?: "Found " + newState.apps.size + " apps; unknown does not mean compatible"
        FxgaTelemetry.event("compat.rescan")
        busy = false
    }

    LaunchedEffect(Unit) { refresh() }

    Scaffold(topBar = { TopAppBar(title = { Text("FXGA Android 17 compatibility") }) }) { insets ->
        Column(
            Modifier.fillMaxSize().padding(insets).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(9.dp)
        ) {
            Text("Zygisk: " + if (Info.isZygiskEnabled) "Active this boot" else "Not active this boot",
                style = MaterialTheme.typography.titleMedium)
            Text("Normal-boot policy: enabled. Magisk emergency Safe Mode remains functional.")
            Text(message)
            OutlinedButton(onClick = { scope.launch { refresh() } }, enabled = !busy) { Text("Refresh") }
            if (busy) LinearProgressIndicator(Modifier.fillMaxWidth())
            state.issues.forEach { issue ->
                Text("Module " + issue.id + ": " + issue.issue,
                    color = MaterialTheme.colorScheme.error)
            }
            OutlinedTextField(value = search, onValueChange = { search = it.take(100) },
                label = { Text("Search installed apps") }, modifier = Modifier.fillMaxWidth())
            state.apps.asSequence().filter { !it.system && (
                search.isEmpty() || it.pkg.contains(search, true) || it.name.contains(search, true)
            ) }.take(100).forEach { app ->
                key(app.pkg) {
                    val isSelected = selected?.pkg == app.pkg
                    Card(Modifier.fillMaxWidth(), onClick = { selected = app }) {
                        Column(Modifier.padding(12.dp)) {
                            Text(app.name, style = MaterialTheme.typography.titleMedium)
                            Text(app.pkg)
                            Text(if (prefs.getBoolean(app.pkg, false)) "User-reported problem"
                                else if (app.pkg in state.excluded) "Excluded in DenyList"
                                else "Not tested")
                            if (isSelected) {
                                Text("Process: " + app.process)
                                Button(onClick = {
                                    prefs.edit().putBoolean(app.pkg, !prefs.getBoolean(app.pkg, false)).apply()
                                    message = "Problem report toggled for " + app.pkg
                                }) {
                                    Text(if (prefs.getBoolean(app.pkg, false)) "Clear report" else "Mark problem")
                                }
                                Button(onClick = {
                                    confirmAction = {
                                        scope.launch {
                                            busy = true
                                            val add = app.pkg !in state.excluded
                                            val op = if (add) "add" else "rm"
                                            val done = withContext(Dispatchers.IO) {
                                                Shell.cmd("magisk --denylist " + op + " '" + app.pkg +
                                                    "' '" + app.process + "'").exec().isSuccess
                                            }
                                            message = if (done) "DenyList changed; restart app process to apply"
                                                else "DenyList change failed"
                                            FxgaTelemetry.event("compat.denylist.change")
                                            refresh()
                                        }
                                    }
                                }, enabled = state.error == null && !busy) {
                                    Text(if (app.pkg in state.excluded) "Remove DenyList entry"
                                        else "Exclude this app's default process")
                                }
                                OutlinedButton(onClick = {
                                    selected = app
                                    exportZip.launch("FXGA-" + app.pkg + "-diagnostic.zip")
                                }) { Text("Export selected app diagnostic ZIP") }
                            }
                        }
                    }
                }
            }
        }
    }
    if (confirmAction != null) {
        AlertDialog(
            onDismissRequest = { confirmAction = null },
            title = { Text("Confirm DenyList change") },
            text = { Text("This changes whether Zygisk modules load in the selected process. It does not fix every incompatibility.") },
            confirmButton = {
                TextButton(onClick = { val action = confirmAction; confirmAction = null; action?.invoke() }) {
                    Text("Apply")
                }
            },
            dismissButton = { TextButton(onClick = { confirmAction = null }) { Text("Cancel") } }
        )
    }
}
