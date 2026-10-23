package ar.rf8.rf8_app

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity es requerido por local_auth (biometría).
class MainActivity : FlutterFragmentActivity() {
    // Deben coincidir con los <activity-alias> del AndroidManifest y AppIconVariant.all
    private val icons = listOf("Default", "Night", "Gold", "Neon", "Light", "Fire")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ar.rf8.app/app_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getIcon" -> result.success(currentIcon())
                    "setIcon" -> {
                        val id = call.argument<String>("id")
                        if (id == null || id !in icons) {
                            result.error("invalid_icon", "Ícono desconocido: $id", null)
                        } else {
                            setIcon(id)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun alias(id: String) = ComponentName(this, "$packageName.Icon$id")

    private fun currentIcon(): String = icons.firstOrNull { id ->
        when (packageManager.getComponentEnabledSetting(alias(id))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> id == icons.first()
            else -> false
        }
    } ?: icons.first()

    private fun setIcon(selected: String) {
        // Primero habilitar el nuevo para que nunca quede la app sin ícono.
        packageManager.setComponentEnabledSetting(
            alias(selected),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        icons.filter { it != selected }.forEach { id ->
            packageManager.setComponentEnabledSetting(
                alias(id),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
