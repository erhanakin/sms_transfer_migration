package com.example.sms_transfer_migration

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "sms_transfer/sms"
    private val SMS_PERMISSION_REQUEST_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermissions" -> {
                    result.success(hasSmsPermissions())
                }
                "requestPermissions" -> {
                    requestSmsPermissions()
                    result.success(true)
                }
                "getAllSMS" -> {
                    try {
                        val messages = getAllSmsMessages()
                        result.success(messages)
                    } catch (e: Exception) {
                        result.error("SMS_ERROR", "Failed to get SMS messages", e.message)
                    }
                }
                "writeSMS" -> {
                    try {
                        val address = call.argument<String>("address") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        val date = call.argument<Long>("date") ?: System.currentTimeMillis()
                        val read = call.argument<Int>("read") ?: 1
                        val type = call.argument<Int>("type") ?: 1
                        val threadId = call.argument<String>("thread_id")

                        val success = writeSmsMessage(address, body, date, read, type, threadId)
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("SMS_WRITE_ERROR", "Failed to write SMS message", e.message)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasSmsPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermissions() {
        val permissions = arrayOf(
            Manifest.permission.READ_SMS,
            Manifest.permission.SEND_SMS,
            Manifest.permission.READ_PHONE_STATE
        )
        ActivityCompat.requestPermissions(this, permissions, SMS_PERMISSION_REQUEST_CODE)
    }

    private fun getAllSmsMessages(): List<Map<String, Any?>> {
        if (!hasSmsPermissions()) {
            return emptyList()
        }

        val messages = mutableListOf<Map<String, Any?>>()
        val columns = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.READ,
            Telephony.Sms.TYPE,
            Telephony.Sms.THREAD_ID
        )

        try {
            // Get inbox messages
            val inboxCursor: Cursor? = contentResolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                columns,
                null,
                null,
                "${Telephony.Sms.DATE} DESC"
            )

            inboxCursor?.use { cursor ->
                while (cursor.moveToNext()) {
                    val message = extractSmsFromCursor(cursor)
                    messages.add(message)
                }
            }

            // Get sent messages
            val sentCursor: Cursor? = contentResolver.query(
                Telephony.Sms.Sent.CONTENT_URI,
                columns,
                null,
                null,
                "${Telephony.Sms.DATE} DESC"
            )

            sentCursor?.use { cursor ->
                while (cursor.moveToNext()) {
                    val message = extractSmsFromCursor(cursor)
                    messages.add(message)
                }
            }

        } catch (e: Exception) {
            e.printStackTrace()
        }

        return messages
    }

    private fun extractSmsFromCursor(cursor: Cursor): Map<String, Any?> {
        return mapOf(
            "id" to cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms._ID)),
            "address" to (cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)) ?: ""),
            "body" to (cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)) ?: ""),
            "date" to cursor.getLong(cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)),
            "read" to cursor.getInt(cursor.getColumnIndexOrThrow(Telephony.Sms.READ)),
            "type" to cursor.getInt(cursor.getColumnIndexOrThrow(Telephony.Sms.TYPE)),
            "thread_id" to cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms.THREAD_ID))
        )
    }

    private fun writeSmsMessage(
        address: String,
        body: String,
        date: Long,
        read: Int,
        type: Int,
        threadId: String?
    ): Boolean {
        if (!hasSmsPermissions()) {
            return false
        }

        return try {
            val values = ContentValues().apply {
                put(Telephony.Sms.ADDRESS, address)
                put(Telephony.Sms.BODY, body)
                put(Telephony.Sms.DATE, date)
                put(Telephony.Sms.READ, read)
                put(Telephony.Sms.TYPE, type)
                threadId?.let { put(Telephony.Sms.THREAD_ID, it) }
            }

            val uri = when (type) {
                Telephony.Sms.MESSAGE_TYPE_SENT -> Telephony.Sms.Sent.CONTENT_URI
                else -> Telephony.Sms.Inbox.CONTENT_URI
            }

            val insertedUri = contentResolver.insert(uri, values)
            insertedUri != null
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}