package com.topjohnwu.magisk.ui.module

import android.os.Bundle
import android.util.Base64
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.topjohnwu.magisk.core.model.module.LocalModule
import com.topjohnwu.superuser.Shell
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject

/**
 * FXGA Module Settings: metadata for all modules; opt-in editable controls.
 * Never invoke code supplied by a module manifest.
 * See docs/fxga/MODULE_PROTOCOL.md.
 */
class FxgaModuleSettingsActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme { FxgaModuleSettingsPage() } }
    }
}

private data class FxgaSetting(
    val key: String, val label: String, val type: String, val default: String,
    val choices: List<String> = emptyList(), val min: Int = -100000, val max: Int = 100000,
) {
    fun accepts(value: String): Boolean = when (type) {
        "toggle" -> value == "true" || value == "false"
        "select" -> value in choices
        "integer" -> value.toIntOrNull()?.let { it in min..max } == true
        else -> false
    }
}

private data class FxgaModule(
    val id: String, val name: String, val author: String, val version: String,
    val description: String, val enabled: Boolean, val zygisk: Boolean,
    val hasAction: Boolean, val settings: List<FxgaSetting>,
    val values: Map<String, String>, val warning: String?,
)

private object FxgaModuleStore {
    private val idPattern = Regex("[A-Za-z0-9][A-Za-z0-9_.-]{0,79}")
    private val keyPattern = Regex("[A-Za-z][A-Za-z0-9_]{0,63}")
    private val choicePattern = Regex("[A-Za-z0-9_.:-]{1,48}")
    private const val TAG = "FXGA/Modules"

    private fun dir(id: String): String {
        require(idPattern.matches(id) && id != "." && id != "..") { "Invalid module ID" }
        return "/data/adb/modules/" + id
    }

    private fun read(path: String): String? {
        val result = Shell.cmd("cat '" + path + "'").exec()
        return if (result.isSuccess) result.out.joinToString("\n").take(65536) else null
    }

    private fun definitions(raw: String): List<FxgaSetting> {
        val root = JSONObject(raw)
        require(root.optInt("schema") == 1) { "Unsupported schema" }
        val fields = root.getJSONArray("settings")
        require(fields.length() <= 40) { "Too many settings" }
        val keys = hashSetOf<String>()
        return List(fields.length()) { index ->
            val obj = fields.getJSONObject(index)
            val key = obj.getString("key")
            require(keyPattern.matches(key) && keys.add(key)) { "Invalid setting key" }
            val type = obj.getString("type")
            require(type in setOf("toggle", "select", "integer")) { "Unsupported type" }
            val choices = if (type == "select") {
                val opts = obj.getJSONArray("options")
                require(opts.length() in 1..16) { "Invalid options" }
                List(opts.length()) { opts.getString(it) }.also {
                    require(it.distinct().size == it.size && it.all(choicePattern::matches)) {
                        "Invalid choice value"
                    }
                }
            } else emptyList()
            val min = obj.optInt("min", -100000)
            val max = obj.optInt("max", 100000)
            require(min >= -100000 && max <= 100000 && min <= max) { "Invalid bounds" }
            val default = when (type) {
                "toggle" -> obj.optBoolean("default", false).toString()
                "select" -> obj.optString("default", choices.first())
                else -> obj.optInt("default", min).toString()
            }
            FxgaSetting(key, obj.optString("label", key).take(80), type, default, choices, min, max)
                .also { require(it.accepts(default)) { "Invalid default" } }
        }
    }

    suspend fun list(): List<FxgaModule> = withContext(Dispatchers.IO) {
        val result = LocalModule.installed().mapNotNull { module ->
            val id = module.base.name
            if (!idPattern.matches(id) || id == "." || id == "..") return@mapNotNull null
            val path = dir(id)
            var warning: String? = null
            val schema = read(path + "/fxga-settings.json")?.let { raw ->
                runCatching { definitions(raw) }.getOrElse {
                    warning = "Invalid settings schema: " + (it.message ?: "unknown error").take(100)
                    emptyList()
                }
            }.orEmpty()
            val allowed = schema.associateBy { it.key }
            val values = mutableMapOf<String, String>()
            read(path + "/fxga-settings.conf")?.lineSequence()?.forEach { line ->
                val key = line.substringBefore('=', "")
                val value = line.substringAfter('=', "")
                val spec = allowed[key]
                if (spec != null && spec.accepts(value)) values[key] = value
            }
            FxgaModule(id, module.name, module.author, module.version, module.description,
                module.enable, module.isZygisk, module.hasAction, schema, values, warning)
        }
        Log.i(TAG, "scan modules=" + result.size)
        result
    }

    suspend fun save(module: FxgaModule, proposed: Map<String, String>): Boolean =
        withContext(Dispatchers.IO) {
            require(module.settings.isNotEmpty()) { "Module exposes no editable settings" }
            val content = module.settings.joinToString("\n") { spec ->
                val value = proposed[spec.key] ?: module.values[spec.key] ?: spec.default
                require(spec.accepts(value)) { "Invalid value for " + spec.key }
                spec.key + "=" + value
            } + "\n"
            val b64 = Base64.encodeToString(content.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
            val root = dir(module.id)
            val out = root + "/fxga-settings.conf"
            val tmp = out + ".new"
            val command = listOf(
                "set -e", "umask 077",
                "[ -d '" + root + "' ] && [ ! -L '" + root + "' ]",
                "[ -f '" + root + "/module.prop' ] && [ -f '" + root + "/fxga-settings.json' ]",
                "[ ! -L '" + out + "' ] && [ ! -L '" + tmp + "' ]",
                "printf '%s' '" + b64 + "' | base64 -d > '" + tmp + "'",
                "chmod 600 '" + tmp + "'",
                "mv -f '" + tmp + "' '" + out + "'",
            ).joinToString("\n")
            val ok = Shell.cmd(command).exec().isSuccess
            Log.i(TAG, "save module=" + module.id + " fields=" + module.settings.size + " ok=" + ok)
            ok
        }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FxgaModuleSettingsPage() {
    val scope = rememberCoroutineScope()
    var modules by remember { mutableStateOf<List<FxgaModule>>(emptyList()) }
    var selected by remember { mutableStateOf<String?>(null) }
    val draft = remember { mutableStateMapOf<String, String>() }
    var busy by remember { mutableStateOf(true) }
    var status by remember { mutableStateOf("Reading modules…") }

    suspend fun refresh() {
        busy = true
        runCatching { FxgaModuleStore.list() }
            .onSuccess { modules = it; status = "Found " + it.size + " installed modules" }
            .onFailure { status = "Root module scan failed: " + (it.message ?: "unknown") }
        busy = false
    }

    LaunchedEffect(Unit) { refresh() }
    Scaffold(topBar = { TopAppBar(title = { Text("FXGA module settings") }) }) { insets ->
        Column(Modifier.fillMaxSize().padding(insets).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Module details are always visible. Editable controls require fxga-settings.json supplied by the module developer.")
            Text(status)
            OutlinedButton(onClick = { scope.launch { refresh() } }, enabled = !busy) { Text("Rescan") }
            if (busy) LinearProgressIndicator(Modifier.fillMaxWidth())
            modules.forEach { mod ->
                key(mod.id) {
                    Card(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(mod.name, style = MaterialTheme.typography.titleMedium)
                            Text(mod.id + " · " + mod.version + " · " + if (mod.enabled) "Enabled" else "Disabled")
                            Text("Author: " + mod.author.ifBlank { "unknown" } +
                                " · " + if (mod.zygisk) "Zygisk" else "Standard")
                            Text(mod.description.ifBlank { "No description provided" })
                            TextButton(onClick = {
                                if (selected == mod.id) selected = null else {
                                    selected = mod.id
                                    draft.clear()
                                    mod.settings.forEach { draft[it.key] = mod.values[it.key] ?: it.default }
                                }
                            }) { Text(if (selected == mod.id) "Close module menu" else "Open module menu") }
                            if (selected == mod.id) {
                                mod.warning?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                                if (mod.settings.isEmpty()) {
                                    Text("This module has no FXGA settings interface. Check its existing action.sh in the Modules tab.")
                                } else {
                                    mod.settings.forEach { spec ->
                                        val value = draft[spec.key] ?: spec.default
                                        when (spec.type) {
                                            "toggle" -> Row(Modifier.fillMaxWidth(),
                                                horizontalArrangement = Arrangement.SpaceBetween) {
                                                Text(spec.label)
                                                Switch(value == "true", onCheckedChange = {
                                                    draft[spec.key] = it.toString()
                                                })
                                            }
                                            "select" -> {
                                                var open by remember { mutableStateOf(false) }
                                                Text(spec.label)
                                                Box {
                                                    OutlinedButton(onClick = { open = true }) { Text(value) }
                                                    DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                                                        spec.choices.forEach { choice ->
                                                            DropdownMenuItem(text = { Text(choice) }, onClick = {
                                                                draft[spec.key] = choice
                                                                open = false
                                                            })
                                                        }
                                                    }
                                                }
                                            }
                                            "integer" -> OutlinedTextField(
                                                value = value,
                                                onValueChange = {
                                                    if (it.matches(Regex("-?[0-9]{0,7}"))) draft[spec.key] = it
                                                },
                                                singleLine = true,
                                                label = { Text(spec.label + " (" + spec.min + ".." + spec.max + ")") },
                                                modifier = Modifier.fillMaxWidth()
                                            )
                                        }
                                    }
                                    Button(onClick = {
                                        val values = draft.toMap()
                                        scope.launch {
                                            busy = true
                                            runCatching { FxgaModuleStore.save(mod, values) }
                                                .onSuccess {
                                                    status = if (it) "Saved " + mod.name + " settings; module may need restart"
                                                    else "Root write failed"
                                                }
                                                .onFailure { status = "Rejected: " + (it.message ?: "invalid settings") }
                                            busy = false
                                        }
                                    }, enabled = !busy && mod.settings.all {
                                        it.accepts(draft[it.key] ?: it.default)
                                    }) { Text("Save settings") }
                                }
                                if (mod.hasAction) Text("An action.sh is present; run it only using Magisk's existing Modules UI.")
                            }
                        }
                    }
                }
            }
        }
    }
}
