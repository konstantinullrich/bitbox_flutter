package com.cakewallet.bitbox_flutter

import android.content.Context
import android.hardware.usb.UsbManager
import com.cakewallet.bitbox_flutter.operations.GetDevicesOperation
import com.cakewallet.bitbox_flutter.operations.RequestPermissionOperation
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class BitboxFlutterPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel : MethodChannel
    private lateinit var context: Context
    private lateinit var usbManager: UsbManager
    private lateinit var registry: MethodCallRegistry
    private lateinit var transportChannel: MethodChannel
    private lateinit var transport: BitboxUsbTransport

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.getBinaryMessenger(), "bitbox_usb")
        channel.setMethodCallHandler(this)
        context = binding.getApplicationContext()
        usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager

        transport = BitboxUsbTransport(usbManager)
        transportChannel = MethodChannel(binding.getBinaryMessenger(), BitboxUsbTransport.CHANNEL)
        transportChannel.setMethodCallHandler(transport)

        // Register the method calls
        registry = MethodCallRegistry()
        registry.registerMethodCall("getDevices", GetDevicesOperation(usbManager))
        registry.registerMethodCall("requestPermission", RequestPermissionOperation(usbManager))
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        registry.onMethodCall(context, call, result)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        registry.clear()
        transportChannel.setMethodCallHandler(null)
        transport.dispose()
    }
}
