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
        result: @escaping FlutterResult
    ) {
        let identifier = methodCall.arguments as? String

        self.manager.connect(to: UUID(uuidString: identifier!)!)
        let pInfo = self.manager.parseProduct()
        if (pInfo == nil) {
            result(false)
            return
        }

        result(true)
    }
}
