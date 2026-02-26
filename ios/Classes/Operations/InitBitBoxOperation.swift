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
        result: FlutterResult
    ) {
        let initialized = Api.ApiInitDevice()
        result(initialized == true)
    }
}
