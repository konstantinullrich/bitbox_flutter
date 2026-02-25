//
//  ConnectBitBoxOperation.swift
//  Pods
//
//  Created by Konstantin Ullrich on 14.01.26.
//

import Flutter

class ConnectBitBoxOperation: MethodCallOperation {
    private var manager: BluetoothManager
    
    init(manager: BluetoothManager) {
        self.manager = manager
    }
    
    override func onMethodCall(
        methodCall: FlutterMethodCall,
        result: FlutterResult
    ) {
        let identifier: String? = (methodCall.arguments as? Dictionary<String, String>)!["identifier"]

        self.manager.connect(to: UUID(uuidString: identifier!)!)
        result(true)
    }
}
