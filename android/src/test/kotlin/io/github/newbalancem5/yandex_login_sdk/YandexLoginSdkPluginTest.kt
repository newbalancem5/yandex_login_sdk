package io.github.newbalancem5.yandex_login_sdk

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

/*
 * Unit tests for the method-call dispatch of the Kotlin plugin layer. The
 * happy path of signIn needs a real FragmentActivity + the Yandex SDK and is
 * covered manually via the example app; these tests pin down the branches
 * that are reachable without an Activity.
 *
 * Run with `./gradlew yandex_login_sdk:testDebugUnitTest` from
 * `example/android/` (also executed in CI).
 */
internal class YandexLoginSdkPluginTest {

    @Test
    fun signOut_resolvesSuccessfullyAsNoOp() {
        val plugin = YandexLoginSdkPlugin()
        val mockResult = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("signOut", null), mockResult)

        Mockito.verify(mockResult).success(null)
        Mockito.verifyNoMoreInteractions(mockResult)
    }

    @Test
    fun signIn_withoutActivity_errorsWithNoActivity() {
        val plugin = YandexLoginSdkPlugin()
        val mockResult = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("signIn", mapOf("clientId" to "cid")), mockResult)

        Mockito.verify(mockResult).error(
            Mockito.eq("NO_ACTIVITY"),
            Mockito.anyString(),
            Mockito.isNull(),
        )
        Mockito.verifyNoMoreInteractions(mockResult)
    }

    @Test
    fun unknownMethod_reportsNotImplemented() {
        val plugin = YandexLoginSdkPlugin()
        val mockResult = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("getPlatformVersion", null), mockResult)

        Mockito.verify(mockResult).notImplemented()
        Mockito.verifyNoMoreInteractions(mockResult)
    }
}
