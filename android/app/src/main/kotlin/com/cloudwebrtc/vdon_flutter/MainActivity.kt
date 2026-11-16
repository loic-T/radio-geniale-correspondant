package com.cloudwebrtc.vdon_flutter

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal « vdoninja/device_info » utilisé par la signalisation VDO.Ninja.
        flutterEngine.plugins.add(VDONinjaPlugin())

        // Radio Géniale : démarrage / arrêt du service micro en arrière-plan.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "radiogeniale/micservice")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            MicService.demarrer(
                                applicationContext,
                                call.argument<String>("titre") ?: "Radio Géniale – micro actif",
                                call.argument<String>("texte") ?: "Touchez pour revenir à l'appli.",
                                call.argument<String>("mode") ?: MicService.MODE_MICRO
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("MIC_SERVICE", e.message, null)
                        }
                    }
                    "stop" -> {
                        // Si un mode est précisé, on n'arrête que s'il est actif
                        // (évite que l'arrêt de la radio coupe le micro, et inversement).
                        val mode = call.argument<String>("mode")
                        if (mode == null || mode == MicService.modeActuel) {
                            MicService.arreter(applicationContext)
                        }
                        result.success(true)
                    }
                    "signalACote" -> result.success(ouvrirSignalACote())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Ouvre Signal à côté de l'appli (écran partagé). Android place Signal
     * dans l'autre moitié de l'écran quand l'appareil le permet ; sinon
     * Signal s'ouvre normalement. Renvoie "ok" ou "absent".
     */
    private fun ouvrirSignalACote(): String {
        val signal = packageManager.getLaunchIntentForPackage(SIGNAL)
        if (signal == null) {
            val store = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$SIGNAL"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                startActivity(store)
            } catch (e: ActivityNotFoundException) {
                startActivity(Intent(Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/apps/details?id=$SIGNAL"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
            return "absent"
        }
        signal.addFlags(Intent.FLAG_ACTIVITY_LAUNCH_ADJACENT or Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(signal)
        return "ok"
    }

    companion object {
        private const val SIGNAL = "org.thoughtcrime.securesms"
    }

    override fun onDestroy() {
        // Fermeture de l'appli : on ne laisse pas le micro tourner.
        if (isFinishing) MicService.arreter(applicationContext)
        super.onDestroy()
    }
}
