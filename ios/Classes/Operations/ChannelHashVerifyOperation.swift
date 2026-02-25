//
//  Created by Konstantin Ullrich on 14.01.26.
//

import Api
import Flutter

class ChannelHashVerifyOperation: MethodCallOperation {
    private var manager: BluetoothManager

    init(manager: BluetoothManager) {
        self.manager = manager
    }

    override func onMethodCall(
        methodCall: FlutterMethodCall,
        result: FlutterResult
    ) {
        Api.ApiChannelHashVerify(true)
        result(true)
    }
}
