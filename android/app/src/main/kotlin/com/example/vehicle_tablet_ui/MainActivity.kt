package com.example.vehicle_tablet_ui

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var bluetoothSystem: BluetoothSystemChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bluetoothSystem = BluetoothSystemChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        bluetoothSystem?.dispose()
        bluetoothSystem = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
