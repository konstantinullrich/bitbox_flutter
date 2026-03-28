//
//  BTCGetXPUBOperation.swift
//
//  Created by Konstantin Ullrich on 28.03.26.
//

import Api
import Flutter

class BTCGetXPUBOperation: MethodCallOperation {
    private var manager: BluetoothManager

    init(manager: BluetoothManager) {
        self.manager = manager
    }

    override func onMethodCall(
        methodCall: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let args = methodCall.arguments as? [String: Any],
              let coinType = args["coinType"] as? Int,
              let keypathHex = args["keypath"] as? String,
              let addressType = args["addressType"] as? Int,
              let display = args["display"] as? Bool else {
            result("")
            return
        }

        DispatchQueue.global().async {
            let address = ApiBTCxPub(coinType, keypathHex, addressType, display)
            DispatchQueue.main.async {
                result(address)
            }
        }
    }
}
