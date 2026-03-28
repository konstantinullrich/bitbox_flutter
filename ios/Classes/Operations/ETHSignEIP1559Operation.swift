//
//  ETHSignEIP1559Operation.swift
//
//  Created by Konstantin Ullrich on 28.03.26.
//

import Api
import Flutter

class ETHSignEIP1559Operation: MethodCallOperation {
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
            let nonce = args["nonce"] as? Int,
            let maxPriorityFeePerGas: String? = args["maxPriorityFeePerGas"] as? String,
            let maxFeePerGas = args["maxFeePerGas"] as? String,
            let gasLimit = args["gasLimit"] as? Int,
            let recipient = args["recipient"] as? FlutterStandardTypedData,
            let value = args["value"] as? String,
            let data = args["data"] as? FlutterStandardTypedData,
            let recipientAddressCase = args["recipientAddressCase"] as? Int
        else {
            result("")
            return
        }

        DispatchQueue.global().async {
            let res = ApiETHSignEIP1559(chainId, keypathHex, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, recipient.data, value, data.data, recipientAddressCase)
            DispatchQueue.main.async {
                result(res)
            }
        }
    }
}
