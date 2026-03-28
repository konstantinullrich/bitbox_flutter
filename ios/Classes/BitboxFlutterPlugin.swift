import Flutter
import UIKit

public class BitboxFlutterPlugin: NSObject, FlutterPlugin {
    private let registry: MethodCallRegistry
    private let bluetoothManager: BluetoothManager
    
    init(registry: MethodCallRegistry, bluetoothManager: BluetoothManager) {
        self.registry = registry
        self.bluetoothManager = bluetoothManager
    }
    
  public static func register(with registrar: FlutterPluginRegistrar) {
    let registry = MethodCallRegistry()
    let bluetoothManager = BluetoothManager()

      registry.registerMethodCall(method: "iosGetConnectionStatus", operation: GetConnectionStatusOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "getDevices", operation: ScanDevicesOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "open", operation: ConnectBitBoxOperation(manager: bluetoothManager))

      registry.registerMethodCall(method: "initBitBox", operation: InitBitBoxOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "close", operation: CloseOperation(bluetoothManager))
      registry.registerMethodCall(method: "getChannelHash", operation: GetChannelHashOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "channelHashVerify", operation: ChannelHashVerifyOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "getMasterFingerprint", operation: GetMasterfingerPrintOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "supportsETH", operation: SupportsETHOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "supportsERC20", operation: SupportsERC20Operation(manager: bluetoothManager))
      registry.registerMethodCall(method: "supportsLTC", operation: SupportsLTCOperation(manager: bluetoothManager))

      registry.registerMethodCall(method:"getBTCXPub", operation: BTCGetXPUBOperation(manager: bluetoothManager))
      registry.registerMethodCall(method:"signBTCPsbt", operation: BTCSignPsbtOperation(manager: bluetoothManager))
      registry.registerMethodCall(method:"signBTCMessage", operation: BTCSignMessageOperation(manager: bluetoothManager))

      registry.registerMethodCall(method: "getETHAddress", operation: ETHGetAddressOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "signETHTransaction", operation: ETHSignTransactionOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "signETHTransactionEIP1559", operation: ETHSignEIP1559Operation(manager: bluetoothManager))
      registry.registerMethodCall(method: "signETHMessage", operation: ETHSignMessageOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "signETHTypedMessage", operation: ETHSignTypedMessageOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "signETHRLPTransaction", operation: ETHSignRLPTransactionOperation(manager: bluetoothManager))

    let channel = FlutterMethodChannel(name: "bitbox_usb", binaryMessenger: registrar.messenger())
    let instance = BitboxFlutterPlugin(registry: registry, bluetoothManager: bluetoothManager)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      registry.onMethodCall(call: call, result: result)
  }
}
