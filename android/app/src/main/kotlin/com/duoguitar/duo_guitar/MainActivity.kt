package com.duoguitar.duo_guitar

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "duo_guitar/net")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquireMulticastLock" -> {
                        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        val lock = wifi.createMulticastLock("duo_guitar")
                        lock.setReferenceCounted(false)
                        if (!lock.isHeld) {
                            lock.acquire()
                        }
                        multicastLock = lock
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
