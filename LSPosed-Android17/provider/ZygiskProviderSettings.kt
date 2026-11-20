package org.matrix.vector.manager.ui.screens.home

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import org.matrix.vector.manager.di.ServiceLocator

/**
 * Android 17-only Zygisk provider preferences.
 *
 * The root daemon owns the choice in /data/adb/vector-provider/choice so it can be
 * reused by the installer even before the UI loads. Every modification is staged
 * for next reboot; never claim the provider is injected right after selection.
 */
@Composable
fun ZygiskProviderSettings(daemonAlive: Boolean) {
    val scope = rememberCoroutineScope()
    var selected by remember { mutableStateOf("auto") }
    var providerStatus by remember { mutableStateOf("Loading provider status…") }
    var applying by remember { mutableStateOf(false) }
    var choosePrompt by remember { mutableStateOf(false) }

    LaunchedEffect(daemonAlive) {
        if (!daemonAlive) {
            providerStatus = "Framework daemon unavailable. Provider changes are disabled."
        } else {
            val result =
                ServiceLocator.daemon.getZygiskProviderStatus()
                    .getOrElse { "error=Cannot read provider status: ${it.javaClass.simpleName}" }
            providerStatus = result
            val saved = result.lineSequence()
                .firstOrNull { it.startsWith("mode=") }?.substringAfter("=") ?: "auto"
            selected = saved.takeIf { it in setOf("auto", "magisk", "rezygisk") } ?: "auto"
            choosePrompt = result.lineSequence().any { it == "conflict=yes" }
        }
    }

    fun applyChoice(mode: String) {
        scope.launch {
            applying = true
            val result =
                ServiceLocator.daemon.selectZygiskProvider(mode)
                    .getOrElse { "error=Cannot stage provider: ${it.javaClass.simpleName}" }
            providerStatus = result
            if (!result.contains("error=")) selected = mode
            applying = false
            choosePrompt = false
        }
    }

    OutlinedCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("Zygisk provider", style = MaterialTheme.typography.titleMedium)
            Text(
                "Choose one injector for Android 17. Auto uses Magisk Zygisk if available, " +
                    "otherwise ReZygisk. Both providers cannot inject together.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            listOf(
                "auto" to "Automatic (recommended)",
                "magisk" to "Magisk built-in Zygisk",
                "rezygisk" to "ReZygisk",
            ).forEach { (value, label) ->
                Row(
                    modifier = Modifier.fillMaxWidth()
                        .clickable(enabled = daemonAlive && !applying) { selected = value },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    RadioButton(
                        selected = selected == value,
                        onClick = { selected = value },
                        enabled = daemonAlive && !applying,
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(label, style = MaterialTheme.typography.bodyMedium)
                }
            }
            Button(
                onClick = { applyChoice(selected) },
                enabled = daemonAlive && !applying,
            ) {
                Text(if (applying) "Applying…" else "Use selected provider")
            }
            Text(
                providerStatus,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                "A reboot is required after switching providers. This menu does not reboot " +
                    "your phone or restart system_server. Verify actual module hooks after reboot.",
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }

    if (choosePrompt) {
        AlertDialog(
            onDismissRequest = { choosePrompt = false },
            title = { Text("Choose a Zygisk provider") },
            text = {
                Text(
                    "Both Magisk Zygisk and ReZygisk appear enabled. " +
                        "The automatic default prefers Magisk. " +
                        "You can change the choice in this menu at any time."
                )
            },
            confirmButton = {
                TextButton(onClick = { choosePrompt = false }) {
                    Text("Choose below")
                }
            },
            dismissButton = {
                TextButton(onClick = { applyChoice("auto") }) {
                    Text("Use automatic")
                }
            },
        )
    }
}
