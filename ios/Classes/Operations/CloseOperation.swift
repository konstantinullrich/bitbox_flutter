//
//  CloseOperation.swift
//  Pods
//
//  Created by Konstantin Ullrich on 14.01.26.
//

import Flutter
import Api

class CloseOperation: MethodCallOperation {
    private var manager: BluetoothManager
    
    init(manager: BluetoothManager) {
        self.manager = manager
    }
    
    override func onMethodCall(
        methodCall: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        self.manager.handleDisconnect()
        result(true)
    }
}
