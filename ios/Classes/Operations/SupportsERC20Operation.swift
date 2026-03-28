//
//  SupportsERC20Operation.swift
//
//  Created by Konstantin Ullrich on 28.03.26.
//

import Api
import Flutter

class SupportsERC20Operation: MethodCallOperation {
    private var manager: BluetoothManager
    
    init(manager: BluetoothManager) {
        self.manager = manager
    }
    
    override func onMethodCall(
        methodCall: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let args = methodCall.arguments as? [String: Any],
              let contractAddress = args["contractAddress"] as? String else {
            result(false)
            return
        }
        result(ApiSupportsERC20(contractAddress))
    }
}
