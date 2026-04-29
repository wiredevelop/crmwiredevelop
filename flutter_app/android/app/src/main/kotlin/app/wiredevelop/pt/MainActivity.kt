package app.wiredevelop.pt

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TERMINAL_DIAGNOSTICS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDiagnostics" -> result.success(getTerminalDiagnostics())
                else -> result.notImplemented()
            }
        }
    }

    private fun getTerminalDiagnostics(): Map<String, Any?> {
        val packageManager = packageManager
        val nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "product" to Build.PRODUCT,
            "sdkInt" to Build.VERSION.SDK_INT,
            "androidRelease" to Build.VERSION.RELEASE,
            "securityPatch" to Build.VERSION.SECURITY_PATCH,
            "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
            "isDebuggableApp" to ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0),
            "developerOptionsEnabled" to (readGlobalInt(Settings.Global.DEVELOPMENT_SETTINGS_ENABLED) == 1),
            "adbEnabled" to (readGlobalInt(Settings.Global.ADB_ENABLED) == 1),
            "hasNfc" to packageManager.hasSystemFeature(PackageManager.FEATURE_NFC),
            "nfcEnabled" to (nfcAdapter?.isEnabled ?: false),
            "hasBluetoothLe" to packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE),
            "hasGooglePlayServices" to isPackageInstalled("com.google.android.gms"),
            "hasGooglePlayStore" to isPackageInstalled("com.android.vending"),
            "hasHardwareKeystore" to hasHardwareKeystore(packageManager),
            "hardwareKeystoreVersion100" to hasHardwareKeystoreVersion100(packageManager),
        )
    }

    private fun readGlobalInt(name: String): Int {
        return try {
            Settings.Global.getInt(contentResolver, name, 0)
        } catch (_: Exception) {
            0
        }
    }

    @Suppress("DEPRECATION")
    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun hasHardwareKeystore(packageManager: PackageManager): Boolean {
        return packageManager.hasSystemFeature("android.hardware.hardware_keystore")
    }

    private fun hasHardwareKeystoreVersion100(packageManager: PackageManager): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            packageManager.hasSystemFeature("android.hardware.hardware_keystore", 100)
        } else {
            false
        }
    }

    companion object {
        private const val TERMINAL_DIAGNOSTICS_CHANNEL = "app.wiredevelop.pt/terminal_diagnostics"
    }
}
