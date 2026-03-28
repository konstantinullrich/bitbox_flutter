//
//  SupportsETHOperation.swift
//
//  Created by Konstantin Ullrich on 28.03.26.
//

import Api
import Flutter

class SupportsETHOperation: MethodCallOperation {
    private var manager: BluetoothManager
    
    init(manager: BluetoothManager) {
        self.manager = manager
    }
    
    override func onMethodCall(
        methodCall: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let args = methodCall.arguments as? [String: Any],
              let chainId = args["chainId"] as? Int else {
            result(false)
            return
        }
        result(ApiSupportsETH(chainId))
    }
}
