//
//  GetConnectionStatusOperation.swift
//  Pods
//
//  Created by Konstantin Ullrich on 14.01.26.
//

import Flutter

class GetConnectionStatusOperation: MethodCallOperation {
    private var manager: BluetoothManager
    
    init(manager: BluetoothManager) {
        self.manager = manager
    }
    
    override func onMethodCall(
        methodCall: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        let conStatus = self.manager.isConnected()
        result(conStatus)
    }
}
