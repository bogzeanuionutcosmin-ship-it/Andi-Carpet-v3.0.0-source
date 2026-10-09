package com.example.andi_carpeta

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.telephony.SmsManager
import androidx.core.content.ContextCompat
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

class SmsGatewayWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val prefs = applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return@withContext Result.success()
        if (ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            prefs.edit().putString(KEY_LAST_ERROR, "Permisiunea SEND_SMS lipsește").apply()
            return@withContext Result.failure()
        }
        val deviceId = prefs.getString(KEY_DEVICE_ID, "").orEmpty()
        val secret = prefs.getString(KEY_SECRET, "").orEmpty()
        if (deviceId.isBlank() || secret.isBlank()) return@withContext Result.failure()

        try {
            val response = postJson(PULL_URL, JSONObject(), deviceId, secret)
            val jobs = response.optJSONArray("jobs") ?: return@withContext Result.success()
            for (i in 0 until jobs.length()) {
                val job = jobs.optJSONObject(i) ?: continue
                val id = job.optString("id")
                val phone = job.optString("phone")
                val message = job.optString("message")
                if (id.isBlank() || phone.isBlank() || message.isBlank()) continue
                try {
                    sendSms(phone, message)
                    postJson(ACK_URL, JSONObject().put("jobId", id).put("success", true), deviceId, secret)
                    prefs.edit()
                        .putLong(KEY_LAST_SENT_AT, System.currentTimeMillis())
                        .putString(KEY_LAST_ERROR, "")
                        .apply()
                } catch (e: Exception) {
                    try {
                        postJson(
                            ACK_URL,
                            JSONObject().put("jobId", id).put("success", false).put("error", e.message ?: e.toString()),
                            deviceId,
                            secret,
                        )
                    } catch (_: Exception) {}
                    prefs.edit().putString(KEY_LAST_ERROR, e.message ?: e.toString()).apply()
                }
            }
            prefs.edit().putLong(KEY_LAST_CHECK_AT, System.currentTimeMillis()).apply()
            Result.success()
        } catch (e: Exception) {
            prefs.edit().putString(KEY_LAST_ERROR, e.message ?: e.toString()).apply()
            Result.retry()
        }
    }

    @Suppress("DEPRECATION")
    private fun sendSms(phone: String, message: String) {
        val manager = SmsManager.getDefault()
        val parts = manager.divideMessage(message)
        if (parts.size <= 1) {
            manager.sendTextMessage(phone, null, message, null, null)
        } else {
            manager.sendMultipartTextMessage(phone, null, ArrayList(parts), null, null)
        }
    }

    private fun postJson(url: String, body: JSONObject, deviceId: String, secret: String): JSONObject {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 20_000
            readTimeout = 20_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=utf-8")
            setRequestProperty("X-SMS-Gateway-Id", deviceId)
            setRequestProperty("X-SMS-Gateway-Secret", secret)
        }
        connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
        val code = connection.responseCode
        val stream = if (code in 200..299) connection.inputStream else connection.errorStream
        val text = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
        connection.disconnect()
        if (code !in 200..299) throw IllegalStateException("Gateway HTTP $code: $text")
        return if (text.isBlank()) JSONObject() else JSONObject(text)
    }

    companion object {
        const val PREFS = "andi_sms_gateway"
        const val KEY_ENABLED = "enabled"
        const val KEY_DEVICE_ID = "device_id"
        const val KEY_SECRET = "secret"
        const val KEY_LAST_CHECK_AT = "last_check_at"
        const val KEY_LAST_SENT_AT = "last_sent_at"
        const val KEY_LAST_ERROR = "last_error"

        private const val PERIODIC_NAME = "andi_manager_sms_gateway"
        private const val IMMEDIATE_NAME = "andi_manager_sms_gateway_now"
        private const val PULL_URL = "https://europe-central2-andicarpet-e777e.cloudfunctions.net/pullManagerSmsJobs"
        private const val ACK_URL = "https://europe-central2-andicarpet-e777e.cloudfunctions.net/ackManagerSmsJob"

        fun schedule(context: Context) {
            val constraints = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
            val request = PeriodicWorkRequestBuilder<SmsGatewayWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                PERIODIC_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request,
            )
            runNow(context)
        }

        fun runNow(context: Context) {
            val constraints = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
            val request = OneTimeWorkRequestBuilder<SmsGatewayWorker>().setConstraints(constraints).build()
            WorkManager.getInstance(context).enqueueUniqueWork(IMMEDIATE_NAME, ExistingWorkPolicy.REPLACE, request)
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(PERIODIC_NAME)
            WorkManager.getInstance(context).cancelUniqueWork(IMMEDIATE_NAME)
        }

        @Suppress("DEPRECATION")
        fun sendTestSms(context: Context, phone: String, message: String) {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                throw SecurityException("Permisiunea SEND_SMS lipsește")
            }
            val manager = SmsManager.getDefault()
            val parts = manager.divideMessage(message)
            if (parts.size <= 1) manager.sendTextMessage(phone, null, message, null, null)
            else manager.sendMultipartTextMessage(phone, null, ArrayList(parts), null, null)
        }
    }
}
