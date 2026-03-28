//
//  ETHGetAddressOperation.swift
//
//  Created by Konstantin Ullrich on 28.03.26.
//

import Api
import Flutter

class ETHGetAddressOperation: MethodCallOperation {
    private var manager: BluetoothManager

    init(manager: BluetoothManager) {
        self.manager = manager
    }

    override func onMethodCall(
        methodCall: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let args = methodCall.arguments as? [String: Any],
              let chainId = args["chainId"] as? Int,
              let keypathHex = args["keypath"] as? String,
              let outputType = args["outputType"] as? Int,
              let display = args["display"] as? Bool else {
            result("")
            return
        }

        DispatchQueue.global().async {
            let address = ApiETHGetAddress(chainId, keypathHex, 0, display, nil)
            DispatchQueue.main.async {
                result(address)
            }
        }
    }
}
