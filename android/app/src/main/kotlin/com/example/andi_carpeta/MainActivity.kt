package com.example.andi_carpeta

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val channelName = "andi_carpeta/sms_gateway"
    private val smsPermissionRequest = 4107
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareGateway" -> prepareGateway(result)
                "configureGateway" -> {
                    val deviceId = call.argument<String>("deviceId").orEmpty()
                    val secret = call.argument<String>("secret").orEmpty()
                    if (deviceId.isBlank() || secret.isBlank()) {
                        result.error("invalid_gateway", "Date gateway incomplete", null)
                    } else {
                        prefs().edit()
                            .putBoolean(SmsGatewayWorker.KEY_ENABLED, true)
                            .putString(SmsGatewayWorker.KEY_DEVICE_ID, deviceId)
                            .putString(SmsGatewayWorker.KEY_SECRET, secret)
                            .apply()
                        SmsGatewayWorker.schedule(this)
                        result.success(statusMap())
                    }
                }
                "disableGateway" -> {
                    prefs().edit().putBoolean(SmsGatewayWorker.KEY_ENABLED, false).apply()
                    SmsGatewayWorker.cancel(this)
                    result.success(statusMap())
                }
                "gatewayStatus" -> result.success(statusMap())
                "runGatewayNow" -> {
                    SmsGatewayWorker.runNow(this)
                    result.success(true)
                }
                "sendTestSms" -> {
                    try {
                        val phone = call.argument<String>("phone").orEmpty()
                        val message = call.argument<String>("message").orEmpty()
                        if (phone.isBlank() || message.isBlank()) throw IllegalArgumentException("Număr sau mesaj lipsă")
                        SmsGatewayWorker.sendTestSms(this, phone, message)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("sms_failed", e.message ?: e.toString(), null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun prefs() = getSharedPreferences(SmsGatewayWorker.PREFS, Context.MODE_PRIVATE)

    private fun prepareGateway(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
            result.success(credentials())
            return
        }
        permissionResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), smsPermissionRequest)
    }

    private fun credentials(): Map<String, Any> {
        val p = prefs()
        var deviceId = p.getString(SmsGatewayWorker.KEY_DEVICE_ID, "").orEmpty()
        var secret = p.getString(SmsGatewayWorker.KEY_SECRET, "").orEmpty()
        if (deviceId.isBlank()) deviceId = "android-${UUID.randomUUID()}"
        if (secret.length < 20) secret = UUID.randomUUID().toString() + UUID.randomUUID().toString()
        // Le ținem local chiar înainte de activare, astfel încât un retry să folosească aceeași identitate.
        p.edit().putString(SmsGatewayWorker.KEY_DEVICE_ID, deviceId).putString(SmsGatewayWorker.KEY_SECRET, secret).apply()
        return mapOf("deviceId" to deviceId, "secret" to secret, "permission" to true)
    }

    private fun statusMap(): Map<String, Any> {
        val p = prefs()
        return mapOf(
            "supported" to true,
            "enabled" to p.getBoolean(SmsGatewayWorker.KEY_ENABLED, false),
            "permission" to (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED),
            "deviceId" to p.getString(SmsGatewayWorker.KEY_DEVICE_ID, "").orEmpty(),
            "lastCheckAt" to p.getLong(SmsGatewayWorker.KEY_LAST_CHECK_AT, 0L),
            "lastSentAt" to p.getLong(SmsGatewayWorker.KEY_LAST_SENT_AT, 0L),
            "lastError" to p.getString(SmsGatewayWorker.KEY_LAST_ERROR, "").orEmpty(),
        )
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != smsPermissionRequest) return
        val pending = permissionResult ?: return
        permissionResult = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            pending.success(credentials())
        } else {
            pending.error("sms_permission_denied", "Permisiunea SMS a fost refuzată.", null)
        }
    }
}
