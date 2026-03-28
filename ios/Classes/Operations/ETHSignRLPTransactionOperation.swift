//
//  ETHSignRLPTransactionOperation.swift
//
//  Created by Konstantin Ullrich on 28.03.26.
//

import Api
import Flutter

class ETHSignRLPTransactionOperation: MethodCallOperation {
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
            let txData = args["txData"] as? String,
            let isEIP1559 = args["isEIP1559"] as? Bool
        else {
            result("")
            return
        }

        DispatchQueue.global().async {
            let res = ApiETHSignRPLTx(chainId, keypathHex, txData, isEIP1559)
            DispatchQueue.main.async {
                result(res)
            }
        }
    }
}
