package com.cakewallet.bitbox_flutter

import android.content.Context
import android.hardware.usb.UsbManager
import com.cakewallet.bitbox_flutter.operations.BTCGetXPUBOperation
import com.cakewallet.bitbox_flutter.operations.BTCSignMessageOperation
import com.cakewallet.bitbox_flutter.operations.BTCSignPsbtOperation
import com.cakewallet.bitbox_flutter.operations.ChannelHashVerifyOperation
import com.cakewallet.bitbox_flutter.operations.CloseOperation
import com.cakewallet.bitbox_flutter.operations.ConnectBitBoxOperation
import com.cakewallet.bitbox_flutter.operations.ETHSignEIP1559Operation
import com.cakewallet.bitbox_flutter.operations.ETHSignMessageOperation
import com.cakewallet.bitbox_flutter.operations.ETHSignTransactionOperation
import com.cakewallet.bitbox_flutter.operations.ETHSignTypedMessageOperation
import com.cakewallet.bitbox_flutter.operations.GetChannelHashOperation
import com.cakewallet.bitbox_flutter.operations.GetDevicesOperation
import com.cakewallet.bitbox_flutter.operations.ETHGetAddressOperation
import com.cakewallet.bitbox_flutter.operations.ETHSignRLPTransactionOperation
import com.cakewallet.bitbox_flutter.operations.GetMasterFingerprintOperation
import com.cakewallet.bitbox_flutter.operations.InitBitBoxOperation
import com.cakewallet.bitbox_flutter.operations.RequestPermissionOperation
import com.cakewallet.bitbox_flutter.operations.SupportsETHOperation
import com.cakewallet.bitbox_flutter.operations.SupportsERC20Operation
import com.cakewallet.bitbox_flutter.operations.SupportsLTCOperation
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class BitboxFlutterPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel : MethodChannel
    private lateinit var context: Context
    private lateinit var usbManager: UsbManager
    private lateinit var registry: MethodCallRegistry
    private lateinit var bitboxManager: BitboxManager
    private lateinit var transportChannel: MethodChannel
    private lateinit var transport: BitboxUsbTransport

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.getBinaryMessenger(), "bitbox_usb")
        channel.setMethodCallHandler(this)
        context = binding.getApplicationContext()
        usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
        bitboxManager = BitboxManager(usbManager)

        transport = BitboxUsbTransport(usbManager)
        transportChannel = MethodChannel(binding.getBinaryMessenger(), BitboxUsbTransport.CHANNEL)
        transportChannel.setMethodCallHandler(transport)


        // Register the method calls
        registry = MethodCallRegistry()
        registry.registerMethodCall("getDevices", GetDevicesOperation(bitboxManager))
        registry.registerMethodCall("requestPermission", RequestPermissionOperation(bitboxManager))
        registry.registerMethodCall("open", ConnectBitBoxOperation(bitboxManager))
        registry.registerMethodCall("close", CloseOperation(bitboxManager))
        registry.registerMethodCall("initBitBox", InitBitBoxOperation(bitboxManager))
        registry.registerMethodCall("getChannelHash", GetChannelHashOperation(bitboxManager))
        registry.registerMethodCall("channelHashVerify", ChannelHashVerifyOperation(bitboxManager))
        registry.registerMethodCall("getMasterFingerprint", GetMasterFingerprintOperation(bitboxManager))
        registry.registerMethodCall("supportsETH", SupportsETHOperation(bitboxManager))
        registry.registerMethodCall("supportsERC20", SupportsERC20Operation(bitboxManager))
        registry.registerMethodCall("supportsLTC", SupportsLTCOperation(bitboxManager))

        registry.registerMethodCall("getBTCXPub", BTCGetXPUBOperation(bitboxManager))
        registry.registerMethodCall("signBTCPsbt", BTCSignPsbtOperation(bitboxManager))
        registry.registerMethodCall("signBTCMessage", BTCSignMessageOperation(bitboxManager))

        registry.registerMethodCall("getETHAddress", ETHGetAddressOperation(bitboxManager))
        registry.registerMethodCall("signETHTransaction", ETHSignTransactionOperation(bitboxManager))
        registry.registerMethodCall("signETHTransactionEIP1559", ETHSignEIP1559Operation(bitboxManager))
        registry.registerMethodCall("signETHMessage", ETHSignMessageOperation(bitboxManager))
        registry.registerMethodCall("signETHTypedMessage", ETHSignTypedMessageOperation(bitboxManager))
        registry.registerMethodCall("signETHRLPTransaction", ETHSignRLPTransactionOperation(bitboxManager))
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
