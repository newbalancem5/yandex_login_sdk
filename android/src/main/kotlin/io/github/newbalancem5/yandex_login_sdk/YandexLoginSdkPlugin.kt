package io.github.newbalancem5.yandex_login_sdk

import androidx.activity.result.ActivityResultLauncher
import androidx.fragment.app.FragmentActivity
import com.yandex.authsdk.YandexAuthException
import com.yandex.authsdk.YandexAuthLoginOptions
import com.yandex.authsdk.YandexAuthOptions
import com.yandex.authsdk.YandexAuthResult
import com.yandex.authsdk.YandexAuthSdk
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
        sdk = YandexAuthSdk.create(YandexAuthOptions(act, false))
        launcher = act.activityResultRegistry.register(
            REGISTRY_KEY,
            sdk!!.contract,
        ) { result -> deliverResult(result) }
    }

    override fun onDetachedFromActivity() {
        launcher?.unregister()
        launcher = null
        sdk = null
        activity = null
        pendingResult?.error("DETACHED", "Activity detached during sign-in", null)
        pendingResult = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "signIn" -> handleSignIn(result)
            else -> result.notImplemented()
        }
    }

    private fun handleSignIn(result: Result) {
        if (pendingResult != null) {
            result.error("BUSY", "Another sign-in is in progress", null)
            return
        }
        val launcher = this.launcher
        if (launcher == null) {
            result.error("NO_ACTIVITY", "Plugin is not attached to a FragmentActivity", null)
            return
        }
        pendingResult = result
        try {
            launcher.launch(YandexAuthLoginOptions())
        } catch (e: Throwable) {
            pendingResult = null
            result.error("SDK_ERROR", e.message ?: "launcher.launch failed", null)
        }
    }

    private fun deliverResult(authResult: YandexAuthResult) {
        val pending = pendingResult ?: return
        pendingResult = null
        when (authResult) {
            is YandexAuthResult.Success -> pending.success(
                mapOf(
                    "token" to authResult.token.value,
                    "expiresIn" to authResult.token.expiresIn,
                )
            )
            is YandexAuthResult.Failure -> pending.error(
                "SDK_ERROR",
                authResult.exception.message ?: "Yandex auth failed",
                (authResult.exception as? YandexAuthException)?.errors?.joinToString(),
            )
            YandexAuthResult.Cancelled -> pending.error("CANCELLED", "User cancelled", null)
        }
    }

    private companion object {
        const val CHANNEL = "yandex_login_sdk"
        const val REGISTRY_KEY = "yandex_login_sdk:auth"
    }
}
