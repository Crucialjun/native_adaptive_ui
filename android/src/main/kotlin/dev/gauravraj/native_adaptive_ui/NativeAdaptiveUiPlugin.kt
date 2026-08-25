package dev.gauravraj.native_adaptive_ui

import android.content.res.Configuration
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Reports the Android version, API level and form factor to the Dart side.
 *
 * Android deliberately advertises **no** native platform views. Material 3
 * Expressive is a specification, not a set of embeddable widgets: reproducing it
 * in Flutter costs a few motion and shape tokens, while embedding Compose views
 * would drag a Compose runtime into every consumer's APK and reintroduce the
 * platform-view lifecycle problems this package exists to avoid. If that
 * trade-off changes, this is the one function that has to change with it.
 */
class NativeAdaptiveUiPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel
  private var configuration: Configuration? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    configuration = binding.applicationContext.resources.configuration
    channel = MethodChannel(binding.binaryMessenger, "dev.gauravraj/native_adaptive_ui")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    configuration = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "describePlatform" -> result.success(describePlatform())
      "availableComponents" -> result.success(emptyList<String>())
      else -> result.notImplemented()
    }
  }

  private fun describePlatform(): Map<String, Any?> = mapOf(
    "osName" to "android",
    "majorVersion" to majorVersion(),
    "minorVersion" to minorVersion(),
    "androidSdkInt" to Build.VERSION.SDK_INT,
    "formFactor" to formFactor(),
    "isSimulator" to isEmulator(),
  )

  /**
   * `Build.VERSION.RELEASE` is a marketing string ("16", "14.1", or on preview
   * builds something like "Baklava"), so it is parsed defensively and the API
   * level stays the authoritative signal on the Dart side.
   */
  private fun majorVersion(): Int =
    Build.VERSION.RELEASE?.substringBefore('.')?.toIntOrNull() ?: 0

  private fun minorVersion(): Int =
    Build.VERSION.RELEASE?.substringAfter('.', "")?.toIntOrNull() ?: 0

  /**
   * 600dp is Android's own tablet breakpoint, and `smallestScreenWidthDp`
   * survives rotation — screen width does not.
   */
  private fun formFactor(): String {
    val smallestWidth = configuration?.smallestScreenWidthDp ?: 0
    return if (smallestWidth >= 600) "tablet" else "phone"
  }

  private fun isEmulator(): Boolean =
    Build.FINGERPRINT.startsWith("generic") ||
      Build.FINGERPRINT.contains("vbox") ||
      Build.FINGERPRINT.contains("emulator") ||
      Build.MODEL.contains("Emulator") ||
      Build.MODEL.contains("Android SDK built for")
}
