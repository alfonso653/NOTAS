package com.emethagenda.notes

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    
    companion object {
        const val TAG = "AlarmReceiver"
        const val EXTRA_TASK_TITLE = "task_title"
        const val EXTRA_TASK_ID = "task_id"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "🚨 Alarma recibida!")
        
        val taskTitle = intent.getStringExtra(EXTRA_TASK_TITLE) ?: "Tarea"
        val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: ""
        
        Log.d(TAG, "📝 Ejecutando alarma para: $taskTitle (ID: $taskId)")
        
        // Iniciar el servicio de alarma que reproducirá el sonido
        val alarmServiceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra(AlarmService.EXTRA_TASK_TITLE, taskTitle)
            putExtra(AlarmService.EXTRA_TASK_ID, taskId)
        }
        
        try {
            context.startForegroundService(alarmServiceIntent)
            Log.d(TAG, "✅ Servicio de alarma iniciado")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error al iniciar servicio de alarma: ${e.message}")
        }
    }
}