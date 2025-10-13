package com.example.notes_module

import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.IBinder
import android.os.PowerManager
import android.os.Vibrator
import android.util.Log
import java.io.IOException

class AlarmService : Service() {
    
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    
    companion object {
        const val TAG = "AlarmService"
        const val EXTRA_TASK_TITLE = "task_title"
        const val ACTION_STOP_ALARM = "STOP_ALARM"
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "🚨 AlarmService iniciado")
        
        when (intent?.action) {
            ACTION_STOP_ALARM -> {
                stopAlarm()
                return START_NOT_STICKY
            }
            else -> {
                val taskTitle = intent?.getStringExtra(EXTRA_TASK_TITLE) ?: "Tarea"
                startAlarm(taskTitle)
            }
        }
        
        return START_STICKY
    }
    
    private fun startAlarm(taskTitle: String) {
        try {
            // � Convertir en servicio en primer plano
            startForegroundService(taskTitle)
            
            // �🔓 Adquirir WakeLock para despertar el dispositivo
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or 
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "NotesApp:AlarmWakeLock"
            )
            wakeLock?.acquire(10 * 60 * 1000L) // 10 minutos máximo
            
            // 🎵 Configurar y reproducir sonido de alarma
            setupAndPlayAlarmSound()
            
            // 📳 Iniciar vibración
            startVibration()
            
            // ⏰ Auto-detener después de 5 minutos (para no molestar para siempre)
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                Log.d(TAG, "⏰ Timeout de 5 minutos alcanzado - deteniendo alarma automáticamente")
                stopAlarm()
            }, 5 * 60 * 1000L) // 5 minutos
            
            Log.d(TAG, "⏰ Alarma activada para: $taskTitle")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error al iniciar alarma: ${e.message}")
        }
    }
    
    private fun startForegroundService(taskTitle: String) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channelId = "alarm_service_channel"
            val channelName = "Servicio de Alarmas"
            
            val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            
            // Crear canal de notificación si no existe
            val channel = android.app.NotificationChannel(
                channelId,
                channelName,
                android.app.NotificationManager.IMPORTANCE_LOW
            )
            notificationManager.createNotificationChannel(channel)
            
            // Intent para detener la alarma al tocar la notificación
            val stopIntent = Intent(this, AlarmService::class.java).apply {
                action = ACTION_STOP_ALARM
            }
            val stopPendingIntent = android.app.PendingIntent.getService(
                this,
                0,
                stopIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            
            // Intent para acción de botón DETENER
            val stopAction = android.app.Notification.Action.Builder(
                android.R.drawable.ic_media_pause,
                "🛑 DETENER",
                stopPendingIntent
            ).build()
            
            // Crear notificación de servicio en primer plano
            val notification = android.app.Notification.Builder(this, channelId)
                .setContentTitle("🚨 ALARMA ACTIVA")
                .setContentText("⏰ $taskTitle - Toca para detener")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentIntent(stopPendingIntent) // Tocar notificación detiene alarma
                .addAction(stopAction) // Botón detener
                .setOngoing(true)
                .setAutoCancel(true)
                .build()
            
            startForeground(1, notification)
        }
    }
    
    private fun setupAndPlayAlarmSound() {
        try {
            // Obtener URI del tono de alarma predeterminado
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            
            mediaPlayer = MediaPlayer().apply {
                setDataSource(this@AlarmService, alarmUri)
                
                // Configurar para usar el canal de audio de ALARMA
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                
                // Configurar volumen al máximo del canal de alarma
                val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
                val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)
                
                // Reproducir en bucle
                isLooping = true
                
                setOnPreparedListener { mp ->
                    mp.start()
                    Log.d(TAG, "🔊 Sonido de alarma iniciado")
                }
                
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "❌ Error en MediaPlayer: what=$what, extra=$extra")
                    false
                }
                
                prepareAsync()
            }
            
        } catch (e: IOException) {
            Log.e(TAG, "❌ Error al configurar sonido: ${e.message}")
        }
    }
    
    private fun startVibration() {
        try {
            vibrator = getSystemService(VIBRATOR_SERVICE) as Vibrator
            
            // Patrón de vibración intenso: [pausa, vibra, pausa, vibra...]
            val pattern = longArrayOf(0, 1000, 500, 1000, 500, 1000, 500, 1000)
            
            vibrator?.vibrate(pattern, 0) // 0 = repetir desde el inicio
            
            Log.d(TAG, "📳 Vibración iniciada")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error al iniciar vibración: ${e.message}")
        }
    }
    
    private fun stopAlarm() {
        try {
            // Detener sonido
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
                mediaPlayer = null
            }
            
            // Detener vibración
            vibrator?.cancel()
            vibrator = null
            
            // Liberar WakeLock
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
                wakeLock = null
            }
            
            Log.d(TAG, "🛑 Alarma detenida")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error al detener alarma: ${e.message}")
        } finally {
            stopSelf()
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopAlarm()
        Log.d(TAG, "🗑️ AlarmService destruido")
    }
}