//
//  BTCSignMessageOperation.swift
//
//  Created by Konstantin Ullrich on 28.03.26.
//

import Api
import Flutter

class BTCSignMessageOperation: MethodCallOperation {
    private var manager: BluetoothManager

    init(manager: BluetoothManager) {
        self.manager = manager
    }

    override func onMethodCall(
        methodCall: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let args = methodCall.arguments as? [String: Any],
            let coinType = args["coinTyp"] as? Int,
            let keypathHex = args["keypath"] as? String,
            let message = args["message"] as? FlutterStandardTypedData
        else {
            result("")
            return
        }

        DispatchQueue.global().async {
            let res = ApiBTCSignMessage(coinType, keypathHex, message.data)
            DispatchQueue.main.async {
                result(res)
            }
        }
    }
}
