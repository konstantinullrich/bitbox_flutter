import Flutter
import Api

class MethodCallRegistry {
    private var operations: [String: MethodCallOperation] = [:]

    func registerMethodCall(method: String, operation: MethodCallOperation) {
        operations[method] = operation
    }

    func onMethodCall(
        call: FlutterMethodCall, result: @escaping FlutterResult
    ) {
        let operation = operations[call.method]
        if (operation == nil) {
            result(FlutterMethodNotImplemented)
            return;
        }

        operation!.onMethodCall(methodCall: call, result: result)
    }

    func clear() {
        operations = [:]
    }
}
