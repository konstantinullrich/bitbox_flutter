//
//  ETHSignTypedMessageOperation.swift
//
//  Created by Konstantin Ullrich on 28.03.26.
//

import Api
import Flutter

class ETHSignTypedMessageOperation: MethodCallOperation {
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
            let jsonMessage = args["jsonMessage"] as? FlutterStandardTypedData
        else {
            result("")
            return
        }

        DispatchQueue.global().async {
            let res = ApiETHSignTypedMessage(chainId, keypathHex, jsonMessage.data)
            DispatchQueue.main.async {
                result(res)
            }
        }
    }
}
