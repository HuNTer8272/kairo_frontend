package com.example.vehicle_tablet_ui

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothA2dp
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * System Bluetooth information that flutter_blue_plus does not cover.
 *
 * Read-only by design: Android offers no public API for third-party apps to
 * connect/disconnect Classic audio (A2DP) or call (HFP) profiles, so those
 * stay in the system Bluetooth settings.
 */
class BluetoothSystemChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val context: Context = activity.applicationContext
    private val adapter: BluetoothAdapter? =
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
    private val methods = MethodChannel(messenger, "kairo/bluetooth_system")
    private val events = EventChannel(messenger, "kairo/bluetooth_system/changes")

    private val proxies = mutableMapOf<Int, BluetoothProfile>()
    private var proxiesRequested = false
    private var sink: EventChannel.EventSink? = null
    private var receiverRegistered = false

    private val profileListener = object : BluetoothProfile.ServiceListener {
        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
            proxies[profile] = proxy
            sink?.success(null)
        }

        override fun onServiceDisconnected(profile: Int) {
            proxies.remove(profile)
        }
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            sink?.success(null)
        }
    }

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "openBluetoothSettings" -> result.success(openBluetoothSettings())
            "pairedDevices" -> pairedDevices(result)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            addAction(BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED)
            addAction(BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED)
        }
        // System broadcasts are still delivered to non-exported receivers.
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
        receiverRegistered = true
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        unregisterReceiver()
    }

    fun dispose() {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink = null
        unregisterReceiver()
        for ((profile, proxy) in proxies) {
            adapter?.closeProfileProxy(profile, proxy)
        }
        proxies.clear()
    }

    private fun unregisterReceiver() {
        if (!receiverRegistered) return
        context.unregisterReceiver(receiver)
        receiverRegistered = false
    }

    private fun openBluetoothSettings(): Boolean = try {
        activity.startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
        true
    } catch (e: ActivityNotFoundException) {
        false
    }

    private fun hasConnectPermission(): Boolean =
        Build.VERSION.SDK_INT < 31 ||
            context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission") // Checked by hasConnectPermission().
    private fun pairedDevices(result: MethodChannel.Result) {
        val adapter = adapter
        if (adapter == null || !adapter.isEnabled) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }
        if (!hasConnectPermission()) {
            result.error("permission", "Bluetooth permission is required", null)
            return
        }
        requestProxies(adapter)
        val audio = connectedAddresses(BluetoothProfile.A2DP)
        val calls = connectedAddresses(BluetoothProfile.HEADSET)

        val devices = adapter.bondedDevices.orEmpty().map { device ->
            mapOf(
                "address" to device.address,
                "name" to device.name,
                "type" to when (device.type) {
                    BluetoothDevice.DEVICE_TYPE_CLASSIC -> "classic"
                    BluetoothDevice.DEVICE_TYPE_LE -> "le"
                    BluetoothDevice.DEVICE_TYPE_DUAL -> "dual"
                    else -> "unknown"
                },
                "category" to category(device.bluetoothClass),
                // null = the profile proxy has not connected yet (unknown).
                "audioConnected" to audio?.contains(device.address),
                "callsConnected" to calls?.contains(device.address),
            )
        }
        result.success(devices)
    }

    private fun requestProxies(adapter: BluetoothAdapter) {
        if (proxiesRequested) return
        proxiesRequested = true
        adapter.getProfileProxy(context, profileListener, BluetoothProfile.A2DP)
        adapter.getProfileProxy(context, profileListener, BluetoothProfile.HEADSET)
    }

    @SuppressLint("MissingPermission")
    private fun connectedAddresses(profile: Int): Set<String>? =
        proxies[profile]?.connectedDevices?.map { it.address }?.toSet()

    private fun category(bluetoothClass: BluetoothClass?): String =
        when (bluetoothClass?.majorDeviceClass) {
            BluetoothClass.Device.Major.AUDIO_VIDEO -> "audio"
            BluetoothClass.Device.Major.PHONE -> "phone"
            BluetoothClass.Device.Major.COMPUTER -> "computer"
            BluetoothClass.Device.Major.PERIPHERAL -> "peripheral"
            BluetoothClass.Device.Major.WEARABLE -> "wearable"
            else -> "other"
        }
}
