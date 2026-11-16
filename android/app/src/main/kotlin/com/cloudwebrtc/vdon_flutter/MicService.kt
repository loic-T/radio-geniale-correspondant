package com.cloudwebrtc.vdon_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Radio Géniale : service de premier plan de type « microphone ».
 *
 * Tant qu'il tourne, Android autorise l'application à continuer d'utiliser
 * le micro quand elle est en arrière-plan ou que l'écran est verrouillé.
 * Il tient aussi un verrou de veille (CPU) et un verrou Wi-Fi pour que le
 * flux ne soit pas coupé par la mise en veille.
 */
class MicService : Service() {

    companion object {
        private const val TAG = "RadioGenialeMic"
        private const val CANAL_ID = "radiogeniale_micro"
        private const val NOTIF_ID = 4242
        const val EXTRA_TITRE = "titre"
        const val EXTRA_TEXTE = "texte"
        const val EXTRA_MODE = "mode"
        const val MODE_MICRO = "micro"
        const val MODE_RADIO = "radio"

        /** Mode en cours (micro ou radio), null si le service est arrêté. */
        @Volatile var modeActuel: String? = null

        fun demarrer(context: Context, titre: String, texte: String, mode: String = MODE_MICRO) {
            val intent = Intent(context, MicService::class.java)
                .putExtra(EXTRA_TITRE, titre)
                .putExtra(EXTRA_TEXTE, texte)
                .putExtra(EXTRA_MODE, mode)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun arreter(context: Context) {
            context.stopService(Intent(context, MicService::class.java))
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val titre = intent?.getStringExtra(EXTRA_TITRE) ?: "Radio Géniale – micro actif"
        val texte = intent?.getStringExtra(EXTRA_TEXTE) ?: "Touchez pour revenir à l'appli."
        val mode = intent?.getStringExtra(EXTRA_MODE) ?: MODE_MICRO

        creerCanal()
        val notification = construireNotification(titre, texte)

        try {
            val type = when {
                mode == MODE_RADIO && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ->
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                mode == MODE_MICRO && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ->
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                else -> 0
            }
            ServiceCompat.startForeground(this, NOTIF_ID, notification, type)
        } catch (e: Exception) {
            Log.e(TAG, "Impossible de démarrer le service micro", e)
            stopSelf()
            return START_NOT_STICKY
        }

        modeActuel = mode
        acquerirVerrous()
        return START_NOT_STICKY
    }

    private fun creerCanal() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CANAL_ID) == null) {
                val canal = NotificationChannel(
                    CANAL_ID,
                    "Radio Géniale en cours",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Écoute de la radio ou micro en direct"
                    setShowBadge(false)
                }
                manager.createNotificationChannel(canal)
            }
        }
    }

    private fun construireNotification(titre: String, texte: String): Notification {
        val ouvrir = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        }
        val pendingIntent = ouvrir?.let {
            PendingIntent.getActivity(
                this, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        return NotificationCompat.Builder(this, CANAL_ID)
            .setSmallIcon(R.drawable.ic_stat_micro)
            .setContentTitle(titre)
            .setContentText(texte)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .apply { if (pendingIntent != null) setContentIntent(pendingIntent) }
            .build()
    }

    @Suppress("DEPRECATION")
    private fun acquerirVerrous() {
        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK, "RadioGeniale:micro"
            ).apply {
                setReferenceCounted(false)
                acquire()
            }
        }
        if (wifiLock == null) {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }
            wifiLock = wm.createWifiLock(mode, "RadioGeniale:wifi").apply {
                setReferenceCounted(false)
                acquire()
            }
        }
    }

    private fun libererVerrous() {
        try { wakeLock?.takeIf { it.isHeld }?.release() } catch (e: Exception) { Log.w(TAG, "Verrou déjà libéré", e) }
        try { wifiLock?.takeIf { it.isHeld }?.release() } catch (e: Exception) { Log.w(TAG, "Verrou déjà libéré", e) }
        wakeLock = null
        wifiLock = null
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // L'utilisateur a balayé l'appli dans les applis récentes : on coupe tout.
        libererVerrous()
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        modeActuel = null
        libererVerrous()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
