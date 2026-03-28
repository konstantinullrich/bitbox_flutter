//
//  BTCSignPsbtOperation.swift
//
//  Created by Konstantin Ullrich on 28.03.26.
//

import Api
import Flutter

class BTCSignPsbtOperation: MethodCallOperation {
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
            let psbt = args["psbt"] as? String
        else {
            result("")
            return
        }

        DispatchQueue.global().async {
            let res = ApiBTCSignPSBT(coinType, psbt)
            DispatchQueue.main.async {
                result(res)
            }
        }
    }
}
