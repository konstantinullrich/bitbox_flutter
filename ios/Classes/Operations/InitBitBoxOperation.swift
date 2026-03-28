//
//  Created by Konstantin Ullrich on 14.01.26.
//

import Api
import Flutter

class InitBitBoxOperation: MethodCallOperation {
    private var manager: BluetoothManager

    init(manager: BluetoothManager) {
        self.manager = manager
    }

    override func onMethodCall(
        methodCall: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        // Wait for BLE to be fully ready (connected, notifications enabled, paired)
        DispatchQueue.global().async {
            var attempts = 0
            // Wait for: connected + paired (isConnected), notifications enabled (isBLEReady), and product info
            while (!self.manager.isConnected() || !self.manager.isBLEReady() || self.manager.parseProduct() == nil) && attempts < 100 {
                Thread.sleep(forTimeInterval: 0.1)
                attempts += 1
            }

            guard self.manager.isConnected(),
                  self.manager.isBLEReady(),
                  let productInfo = self.manager.parseProduct() else {
                DispatchQueue.main.async {
                    print("initBitBox: not ready (isConnected=\(self.manager.isConnected()), isBLEReady=\(self.manager.isBLEReady()), product=\(String(describing: self.manager.parseProduct())))")
                    result(false)
                }
                return
            }

            print("initBitBox: BLE fully ready, starting communication")

            let deviceInfo = BluetoothDeviceInfo(bluetoothManager: self.manager, productInfo: productInfo)

            do {
                // Clear any stale data in the read buffer before starting communication
                self.manager.clearReadBuffer()

                let rwc = try deviceInfo.open()
                // Use GetDeviceWithInfo for Bluetooth - pass version and product from BLE characteristic
                ApiGetDeviceWithInfo(rwc, productInfo.version, productInfo.product)
                let success = ApiInitDevice()
                DispatchQueue.main.async {
                    result(success)
                }
            } catch {
                print("initBitBox error: \(error)")
                DispatchQueue.main.async {
                    result(false)
                }
            }
        }
    }
}
