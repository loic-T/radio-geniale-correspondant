package com.cloudwebrtc.vdon_flutter

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
                                call.argument<String>("texte") ?: "Touchez pour revenir à l'appli."
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("MIC_SERVICE", e.message, null)
                        }
                    }
                    "stop" -> {
                        MicService.arreter(applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        // Fermeture de l'appli : on ne laisse pas le micro tourner.
        if (isFinishing) MicService.arreter(applicationContext)
        super.onDestroy()
    }
}
