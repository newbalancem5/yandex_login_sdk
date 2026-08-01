package io.github.newbalancem5.yandex_login_sdk

import androidx.activity.result.ActivityResultLauncher
import androidx.fragment.app.FragmentActivity
import com.yandex.authsdk.YandexAuthException
import com.yandex.authsdk.YandexAuthLoginOptions
import com.yandex.authsdk.YandexAuthOptions
import com.yandex.authsdk.YandexAuthResult
import com.yandex.authsdk.YandexAuthSdk
import com.yandex.authsdk.internal.strategy.LoginType
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class YandexLoginSdkPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var activity: FragmentActivity? = null
    private var sdk: YandexAuthSdk? = null
    private var launcher: ActivityResultLauncher<YandexAuthLoginOptions>? = null
    private var pendingResult: Result? = null
    private var loggingEnabled = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        val act = binding.activity as? FragmentActivity
            ?: throw IllegalStateException(
                "yandex_login_sdk requires the host Activity to be a FragmentActivity " +
                    "(use FlutterFragmentActivity in MainActivity.kt)."
            )
        activity = act
        recreateSdk(act)
    }

    /**
     * (Re)creates the SDK and the result launcher for [act]. REGISTRY_KEY is
     * stable across Activity recreations, so a result produced while the
     * Activity was being recreated (e.g. rotation during sign-in) is
     * redelivered here by the restored registry.
     */
    private fun recreateSdk(act: FragmentActivity) {
        launcher?.unregister()
        sdk = YandexAuthSdk.create(YandexAuthOptions(act, loggingEnabled))
        launcher = act.activityResultRegistry.register(
            REGISTRY_KEY,
            sdk!!.contract,
        ) { result -> deliverResult(result) }
    }

    override fun onDetachedFromActivity() {
        disposeActivity()
        pendingResult?.error("DETACHED", "Activity detached during sign-in", null)
        pendingResult = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() {
        // Keep pendingResult: the auth result survives the config change and
        // is redelivered through the re-registered launcher.
        disposeActivity()
    }

    private fun disposeActivity() {
        launcher?.unregister()
        launcher = null
        sdk = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "signIn" -> handleSignIn(call, result)
            "signOut" -> handleSignOut(result)
            else -> result.notImplemented()
        }
    }

    /**
     * Clears local sign-in state.
     *
     * The Yandex `authsdk` (3.x) is stateless and exposes no logout/revoke, so
     * there is no native SDK session to clear. This resolves successfully as a
     * documented no-op; the app should drop its own copy of the token. It does
     * not revoke the token on Yandex's servers nor clear the Yandex-app /
     * Chrome-tab cookie session.
     */
    private fun handleSignOut(result: Result) {
        nativeLog("debug", "signOut(): no-op on Android (stateless authsdk)")
        result.success(null)
    }

    private fun handleSignIn(call: MethodCall, result: Result) {
        if (pendingResult != null) {
            result.error("BUSY", "Another sign-in is in progress", null)
            return
        }
        if (launcher == null) {
            result.error("NO_ACTIVITY", "Plugin is not attached to a FragmentActivity", null)
            return
        }
        val nativeLogging = call.argument<Boolean>("nativeLogging") ?: false
        if (nativeLogging != loggingEnabled) {
            loggingEnabled = nativeLogging
            activity?.let { recreateSdk(it) }
        }
        // authsdk 3.2+ lets the login options override the manifest clientId
        // at runtime; blank/null falls back to the manifest value.
        val clientId = call.argument<String>("clientId")
        val loginType = when (call.argument<String>("strategy")) {
            "webOnly" -> LoginType.CHROME_TAB
            else -> LoginType.NATIVE
        }
        pendingResult = result
        nativeLog("debug", "launching sign-in (loginType=$loginType)")
        try {
            launcher!!.launch(YandexAuthLoginOptions(loginType, clientId))
        } catch (e: Throwable) {
            pendingResult = null
            nativeLog("error", "launcher.launch failed: ${e.message}")
            result.error("SDK_ERROR", e.message ?: "launcher.launch failed", null)
        }
    }

    private fun deliverResult(authResult: YandexAuthResult) {
        val pending = pendingResult ?: return
        pendingResult = null
        when (authResult) {
            is YandexAuthResult.Success -> {
                nativeLog("debug", "sign-in succeeded (expiresIn=${authResult.token.expiresIn})")
                pending.success(
                    mapOf(
                        "token" to authResult.token.value,
                        "expiresIn" to authResult.token.expiresIn,
                    )
                )
            }
            is YandexAuthResult.Failure -> {
                nativeLog("error", "sign-in failed: ${authResult.exception.message}")
                pending.error(
                    "SDK_ERROR",
                    authResult.exception.message ?: "Yandex auth failed",
                    (authResult.exception as? YandexAuthException)?.errors?.joinToString(),
                )
            }
            YandexAuthResult.Cancelled -> {
                nativeLog("info", "sign-in cancelled by user")
                pending.error("CANCELLED", "User cancelled", null)
            }
        }
    }

    /**
     * Mirrors a native diagnostic event into the Dart-side `YandexLoginSdk.onLog`
     * hook. Gated by the `nativeLogging` flag the Dart layer sends with each
     * signIn (true only while a log handler is installed).
     */
    private fun nativeLog(level: String, message: String) {
        if (!loggingEnabled) return
        channel.invokeMethod("log", mapOf("level" to level, "message" to message))
    }

    private companion object {
        const val CHANNEL = "yandex_login_sdk"
        const val REGISTRY_KEY = "yandex_login_sdk:auth"
    }
}
