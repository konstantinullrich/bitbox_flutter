package com.cakewallet.bitbox_flutter.operations

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class RequestPermissionOperation(usbManager: UsbManager) :
    UsbMethodCallOperation(usbManager) {
    public override fun onMethodCall(
        context: Context, methodCall: MethodCall, result: MethodChannel.Result
    ) {
        val identifier: kotlin.String? = methodCall.argument("identifier")
        val device: UsbDevice? = usbManager.getDeviceList().get(identifier)
        if (device == null) {
            result.success(false)
            return
        }

        if (usbManager.hasPermission(device)) {
            result.success(true)
            return
        }

        val receiver: BroadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                context.unregisterReceiver(this)
                if (ACTION_USB_PERMISSION == intent.action) {
                    val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                    result.success(granted)
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(
                receiver, IntentFilter(ACTION_USB_PERMISSION), Context.RECEIVER_EXPORTED
            )
        } else {
            context.registerReceiver(receiver, IntentFilter(ACTION_USB_PERMISSION))
        }

        usbManager.requestPermission(device, getPendingIntent(context))
    }

    fun getPendingIntent(context: Context?): PendingIntent? {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        return PendingIntent.getBroadcast(
            context, 0, Intent(ACTION_USB_PERMISSION), flags
        )
    }

    companion object {
        const val ACTION_USB_PERMISSION: String = "com.cakewallet.bitbox_flutter.USB_PERMISSION"
    }
}
