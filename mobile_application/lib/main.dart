import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reactive_ble_mobile/reactive_ble_mobile.dart';
import 'package:reactive_ble_platform_interface/reactive_ble_platform_interface.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:battery_plus/battery_plus.dart';

/// takes Color object, return MaterialColor object
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

// global style configuration
final ThemeData themeData = ThemeData(
  canvasColor: createMaterialColor(const Color(0xFFffffff)),
  primarySwatch: createMaterialColor(const Color(0xFF6e9cff)),
  secondaryHeaderColor: createMaterialColor(const Color(0xffffc966)),
);


void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Map<int, String> processedMessages = {};
  Map<int, String> forwardedMessages = {};
  var battery = Battery();

  String _bestDevice = "no-known-devices";
  int _bestAkku = 0;

  bool _scanning = false;
  bool _advertise = false;

  // Bluetooth related variables
  final flutterReactiveBle = FlutterReactiveBle();
  late StreamSubscription<DiscoveredDevice> _scanStream;
  late QualifiedCharacteristic _rxCharacteristic;

  // These are the UUIDs of your device
  final Uuid serviceUuid = Uuid.parse("75C276C3-8F97-20BC-A143-B354244886D4");
  final Uuid characteristicUuid = Uuid.parse("6ACF4F08-CC9D-D495-6B41-AA7E60C4E8A6");

  // peripheral
  final FlutterBlePeripheral blePeripheral = FlutterBlePeripheral();

  AdvertiseData advertiseData = AdvertiseData(
    serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
    includeDeviceName: true,
    includePowerLevel: true,
    //serviceData: Uint8List.fromList([1, 2]),
    manufacturerId: 1234,
    manufacturerData: Uint8List.fromList([55, 2, 174, 0, 5, 6, 5, 5, 5, 5, 5, 5, 5]),
  );

  final AdvertiseSettings advertiseSettings = AdvertiseSettings(
    advertiseMode: AdvertiseMode.advertiseModeBalanced,
    txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
    timeout: 3000,
  );

  final AdvertiseSetParameters advertiseSetParameters = AdvertiseSetParameters(
    txPowerLevel: txPowerMedium,
  );

  /*Future<void> _toggleAdvertise() async {
    if (await blePeripheral.isAdvertising) {
      await blePeripheral.stop();
    } else {
      await blePeripheral.start(advertiseData: advertiseData);
    }
  }*/

  Future<void> toggleAdvertiseSet() async {
    _advertise = !_advertise;
    setState(() {});
    if (await blePeripheral.isAdvertising) {
      await blePeripheral.stop();
    } else {
      await blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSetParameters: advertiseSetParameters,
      );
    }
    Fluttertoast.showToast(
        msg: (!_advertise) ? "bluetooth_advertisements_disabled" : "bluetooth_advertisements_enabled",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.TOP_RIGHT,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.grey[600],
        textColor: Colors.white,
        fontSize: 16.0
    );
  }

  // input controllers
  final controllerClientId = TextEditingController();
  final controllerMessage = TextEditingController();
  final controllerTargetId = TextEditingController();

  @override
  void initState() {
    super.initState();
    toggleScan();
    // runs every 1 second
    Timer.periodic(const Duration(seconds: 60), (timer) {
      toggleScan();
      if(!_scanning) toggleScan();
    });
    Timer.periodic(const Duration(seconds: 10), (timer) {
      _bestAkku = 0;
    });
  }

  Future<bool> _checkPermission() async {
    var statePermBlueScan = await Permission.bluetoothScan.request();
    if(statePermBlueScan.isDenied) return false;

    var statePermBlueAdvertise = await Permission.bluetoothAdvertise.request();
    if(statePermBlueAdvertise.isDenied) return false;

    var statePermBlueConnect = await Permission.bluetoothConnect.request();
    if(statePermBlueConnect.isDenied) return false;

    return true;
  }

  void toggleScan() async {
    if (!_scanning) {
      _scanning = true;
      setState(() {});
      bool permGranted = false;
      setState(() { });
      PermissionStatus permission;
      if (Platform.isAndroid) {
        permission = await Permission.location.request();
        if (permission.isGranted) permGranted = true;
      } else if (Platform.isIOS) {
        permGranted = true;
      }
      // Main scanning logic happens here ⤵️
      if (permGranted) {
        _scanStream = flutterReactiveBle.scanForDevices(withServices: []).listen((
            device) {
          if (device.name != "" && device.manufacturerData.isNotEmpty) {
            //print(device.manufacturerData);
            try {
              int clientId = int.parse(controllerClientId.text);
              List<int> data = device.manufacturerData;
              int sourceId = int.parse(data[2].toString());
              int recipientId = int.parse(data[3].toString());
              int verify = int.parse(data[4].toString());
              int akku = int.parse(data[5].toString());
              if(verify == 174) {
                if(akku > _bestAkku) {
                  _bestAkku = akku;
                  _bestDevice = "${device.name}: $akku%";
                  setState(() { });
                }
                List<int> encodedData = [];
                for (int i = 6; i < data.length; i++) {
                  encodedData.add(data[i]);
                }
                String message = utf8.decode(encodedData);
                if (recipientId == clientId) {
                  if(processedMessages[sourceId] != message) {
                    print("message_received: $message akku: $akku%");
                    processedMessages[sourceId] = message;
                    //print(device.serviceUuids);
                    //print(device.serviceData);
                    //print(device.name);
                    //print(device.id);
                    Fluttertoast.showToast(
                        msg: utf8.decode(encodedData),
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.TOP_RIGHT,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.grey[600],
                        textColor: Colors.white,
                        fontSize: 16.0
                    );
                    setState(() {});
                    print("=========================");
                  }
                } else {
                  // forward messages if needed TODO: implement loop detection
                  if(forwardedMessages[recipientId] != message) {
                    forwardedMessages[recipientId] = message;
                    forwardMessage(sourceId, recipientId, message);
                  }
                  //if(processedMessages[source_id] != message) {
                   // processedMessages[source_id] = message;
                   // forwardMessage(recipient_id, message);
                  //}
                }
              }
            } catch (e) {
              if(!_scanning) toggleScan();
              // print("error_invalid_advertisement");
            }
          }
        });
      } else {
        print("error_no_permissions");
        if(!_scanning) toggleScan();
      }
    } else {
      _scanning = false;
      _scanStream.cancel();
      setState(() {});
    }
    Fluttertoast.showToast(
        msg: (!_scanning) ? "bluetooth_discovery_disabled" : "bluetooth_discovery_enabled",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.TOP_RIGHT,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.grey[600],
        textColor: Colors.white,
        fontSize: 16.0
    );
  }

  Future<void> forwardMessage(int sourceId, int targetId, String payload) async {
    print("forward messsage $sourceId $targetId $payload");
    if (await blePeripheral.isAdvertising) {
      await blePeripheral.stop();
    }
    int akku = await battery.batteryLevel;
    List<int> manData = [sourceId, targetId, 174, akku]; // basic message layout
    setState(() {});
    manData.addAll(utf8.encode(payload));
    advertiseData = AdvertiseData(
      serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
      includeDeviceName: true,
      includePowerLevel: true,
      manufacturerId: 1234,
      manufacturerData: Uint8List.fromList(manData),
    );
    if (!await blePeripheral.isAdvertising) {
      await blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSetParameters: advertiseSetParameters,
      );
    }
    _advertise = true;
    setState(() {});
  }

  Future<void> sendMessage() async {
    if (await blePeripheral.isAdvertising) {
      await blePeripheral.stop();
    }
    try {
      int clientId = int.parse(controllerClientId.text);
      int targetId = int.parse(controllerTargetId.text);
      int akku = await battery.batteryLevel;
      List<int> manData = [clientId, targetId, 174, akku]; // basic message layout
      setState(() {});
      manData.addAll(utf8.encode(controllerMessage.text));
      advertiseData = AdvertiseData(
        serviceUuid: 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7',
        includeDeviceName: true,
        includePowerLevel: true,
        manufacturerId: 1234,
        manufacturerData: Uint8List.fromList(manData),
      );
    } catch (e) {
      Fluttertoast.showToast(
          msg: "please enter valid device addresses",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.TOP_RIGHT,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.grey[600],
          textColor: Colors.white,
          fontSize: 16.0
      );
    }
    if (!await blePeripheral.isAdvertising) {
      await blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSetParameters: advertiseSetParameters,
      );
    }
    _advertise = true;
    setState(() {});
  }

  /*void connectToDevice() {
    // We're done scanning, we can cancel it
    _scanStream.cancel();
    flutterReactiveBle.connectToAdvertisingDevice(
      id: _ubiqueDevice.id,
      withServices: [serviceUuid],
      prescanDuration: const Duration(seconds: 5),
      servicesWithCharacteristicsToDiscover: {},
      connectionTimeout: const Duration(seconds:  2),
    ).listen((connectionState) {
      print(connectionState.toString());
      // Handle connection state updates
    }, onError: (dynamic error) {
      print("connection closed");
      // Handle a possible error
    });
  }*/

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: themeData,
      debugShowCheckedModeBanner: false,
      title: 'PeerPower',
      home: Scaffold(
          appBar: AppBar(
            title: const Text('PeerPower', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(_bestDevice, style: const TextStyle(fontSize: 20)),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextField(
                  keyboardType: TextInputType.number,
                  controller: controllerClientId,
                  inputFormatters: [
                    FilteringTextInputFormatter(RegExp(r'^([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])$'), allow: true),
                  ],
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    hintText: 'client_id (0 ... 255)',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextField(
                  keyboardType: TextInputType.number,
                  controller: controllerTargetId,
                  inputFormatters: [
                    FilteringTextInputFormatter(RegExp(r'^([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])$'), allow: true),
                  ],
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    hintText: 'target_id (0 ... 255)',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextField(
                  controller: controllerMessage,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    hintText: 'message',
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: themeData.secondaryHeaderColor,
                ),
                onPressed: () async {
                Fluttertoast.showToast(
                    msg: (await _checkPermission()) ? "permissions_granted" : "permissions_denied",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.TOP_RIGHT,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Colors.grey[600],
                    textColor: Colors.white,
                    fontSize: 16.0
                );
              }, child: const Text("request-system-permissions"),
              ),
            ],
          ),
          floatingActionButton: Row (
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: FloatingActionButton(
                  backgroundColor: (_advertise) ? themeData.secondaryHeaderColor : Colors.grey,
                  onPressed: () {
                    toggleAdvertiseSet();
                  },
                  child: const Icon(Icons.arrow_circle_up_outlined),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: FloatingActionButton(
                  backgroundColor: (_scanning) ? themeData.secondaryHeaderColor : Colors.grey,
                  onPressed: () {
                    toggleScan();
                  },
                  child: const Icon(Icons.arrow_circle_down_outlined),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: FloatingActionButton(
                  backgroundColor: themeData.secondaryHeaderColor,
                  onPressed: () {
                    sendMessage();
                  },
                  child: const Icon(Icons.send),
                ),
              ),
            ],
          )
      ),
    );
  }
}