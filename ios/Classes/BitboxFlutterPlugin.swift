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

      registry.registerMethodCall(method: "iosStartScan", operation: StartScanDevicesOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "iosGetConnectionStatus", operation: GetConnectionStatusOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "iosFinalConnectDeviceOperation", operation: FinalConnectDeviceOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "getDevices", operation: ScanDevicesOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "initBitBox", operation: InitBitBoxOperation(manager: bluetoothManager))
      // registry.registerMethodCall(method: "requestPermission", operation: StartScanDevicesOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "open", operation: ConnectBitBoxOperation(manager: bluetoothManager))
      // registry.registerMethodCall(method: "close", CloseOperation(bluetoothManager))
      registry.registerMethodCall(method: "getChannelHash", operation: GetChannelHashOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "channelHashVerify", operation: ChannelHashVerifyOperation(manager: bluetoothManager))
      registry.registerMethodCall(method: "getMasterFingerprint", operation: GetMasterfingerPrintOperation(manager: bluetoothManager))
      // registry.registerMethodCall("supportsETH", SupportsETHOperation(bluetoothManager))
      // registry.registerMethodCall("supportsERC20", SupportsERC20Operation(bluetoothManager))
      // registry.registerMethodCall("supportsLTC", SupportsLTCOperation(bluetoothManager))

    let channel = FlutterMethodChannel(name: "bitbox_usb", binaryMessenger: registrar.messenger())
    let instance = BitboxFlutterPlugin(registry: registry, bluetoothManager: bluetoothManager)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      registry.onMethodCall(call: call, result: result)
  }
}
