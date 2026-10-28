package com.cakewallet.bitbox_flutter.operations

import android.content.Context
import android.hardware.usb.UsbManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class GetDevicesOperation(usbManager: UsbManager) :
    UsbMethodCallOperation(usbManager) {
    override fun onMethodCall(
        context: Context,
        methodCall: MethodCall,
        result: MethodChannel.Result
    ) {
        val devices: MutableList<MutableMap<String?, Any?>?> =
            ArrayList()
        for (entry in usbManager.getDeviceList().entries) {
            val map: MutableMap<String?, Any?> = HashMap()
            map.put("identifier", entry.key)
            map.put("vendorId", entry.value.vendorId)
            map.put("deviceId", entry.value.deviceId)
            map.put("deviceName", entry.value.deviceName)
            map.put("productId", entry.value.productId)
            map.put("productName", entry.value.productName)
            map.put("manufacturerName", entry.value.manufacturerName)
            map.put("configurationCount", entry.value.configurationCount)
            map.put("isUsb", true)
            devices.add(map)
        }

        result.success(devices)
    }
}
