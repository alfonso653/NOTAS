package com.example.notes_module

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*

class MainActivity : FlutterActivity() {
    
    private val CHANNEL = "com.example.notes_module/alarm"
    private val TAG = "MainActivity"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    val taskTitle = call.argument<String>("taskTitle") ?: ""
                    val scheduledTime = call.argument<Long>("scheduledTime") ?: 0L
                    
                    val success = scheduleAlarm(taskId, taskTitle, scheduledTime)
                    result.success(success)
                }
                "cancelAlarm" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    val success = cancelAlarm(taskId)
                    result.success(success)
                }
                "stopAlarm" -> {
                    stopCurrentAlarm()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun scheduleAlarm(taskId: String, taskTitle: String, scheduledTime: Long): Boolean {
        return try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // Crear intent para el BroadcastReceiver
            val intent = Intent(this, AlarmReceiver::class.java).apply {
                putExtra(AlarmReceiver.EXTRA_TASK_ID, taskId)
                putExtra(AlarmReceiver.EXTRA_TASK_TITLE, taskTitle)
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                taskId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Programar alarma exacta
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    scheduledTime,
                    pendingIntent
                )
                Log.d(TAG, "⏰ Alarma programada con setExactAndAllowWhileIdle")
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    scheduledTime,
                    pendingIntent
                )
                Log.d(TAG, "⏰ Alarma programada con setExact")
            }
            
            val date = Date(scheduledTime)
            Log.d(TAG, "✅ Alarma programada para: $date")
            Log.d(TAG, "📝 Tarea: $taskTitle (ID: $taskId)")
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error al programar alarma: ${e.message}")
            false
        }
    }
    
    private fun cancelAlarm(taskId: String): Boolean {
        return try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            val intent = Intent(this, AlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                taskId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
            
            Log.d(TAG, "🗑️ Alarma cancelada para ID: $taskId")
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error al cancelar alarma: ${e.message}")
            false
        }
    }
    
    private fun stopCurrentAlarm() {
        try {
            val stopIntent = Intent(this, AlarmService::class.java).apply {
                action = AlarmService.ACTION_STOP_ALARM
            }
            startService(stopIntent)
            Log.d(TAG, "🛑 Comando de parar alarma enviado")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error al parar alarma: ${e.message}")
        }
    }
}
