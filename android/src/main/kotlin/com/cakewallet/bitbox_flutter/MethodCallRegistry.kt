package com.cakewallet.bitbox_flutter

import com.cakewallet.bitbox_flutter.operations.MethodCallOperation
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MethodCallRegistry {
    private val operations: MutableMap<String?, MethodCallOperation?> =
        HashMap<String?, MethodCallOperation?>()

    fun registerMethodCall(method: String, operation: MethodCallOperation) {
        this.operations.put(method, operation)
    }

    fun onMethodCall(
        context: android.content.Context,
        methodCall: MethodCall,
        result: MethodChannel.Result
    ) {
        val operation = this.operations[methodCall.method]
        if (operation == null) {
            result.notImplemented()
            return
        }

        operation.onMethodCall(context, methodCall, result)
    }

    fun clear() {
        this.operations.clear()
    }
}
