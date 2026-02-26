//
//  FinalConnectDeviceOperation.swift
//  Pods
//
//  Created by Konstantin Ullrich on 14.01.26.
//

import Api
import Flutter

class FinalConnectDeviceOperation: MethodCallOperation {
    private var manager: BluetoothManager
    
    init(manager: BluetoothManager) {
        self.manager = manager
    }
    
    override func onMethodCall(
        methodCall: FlutterMethodCall,
        result: FlutterResult
    ) {
        let connStatus = self.manager.isConnected()

        if (!connStatus) {
            result(false)
            return
        }

        let pInfo = self.manager.parseProduct()
        if (pInfo == nil) {
            result(false)
            return
        }

        let productInfo = manager.parseProduct();
        guard let productInfo = productInfo else {
            // Not ready or explicitly not connected (waiting for the device to enter
            // firmware or bootloader)
            result(false)
            return
        }

        let btInfo = BluetoothDeviceInfo(bluetoothManager: manager, productInfo: productInfo)
        do {
            let goDevice = try btInfo.open()
            ApiGetDevice(goDevice)
            result(true)
        } catch {
            result(false)
        }
    }
}
