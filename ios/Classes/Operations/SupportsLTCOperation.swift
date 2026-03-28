//
//  SupportsLTCOperation.swift
//
//  Created by Konstantin Ullrich on 28.03.26.
//

import Api
import Flutter

class SupportsLTCOperation: MethodCallOperation {
    private var manager: BluetoothManager
    
    init(manager: BluetoothManager) {
        self.manager = manager
    }
    
    override func onMethodCall(
        methodCall: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        result(ApiSupportsLTC())
    }
}
