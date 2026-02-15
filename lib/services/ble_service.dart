import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  static final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  static const int manufacturerId = 1234;

  // Request permissions
  static Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  // STUDENT SIDE - Start Advertising
  static Future<bool> startAdvertising(String rollNo) async {
    try {
      bool granted = await requestPermissions();
      if (!granted) return false;

      final advertiseData = AdvertiseData(
        manufacturerId: manufacturerId,
        manufacturerData: Uint8List.fromList(rollNo.codeUnits),
        includeDeviceName: false,
      );

      await _peripheral.start(advertiseData: advertiseData);
      return true;
    } catch (e) {
      print('Error starting advertising: $e');
      return false;
    }
  }

  static Future<void> stopAdvertising() async {
    try {
      await _peripheral.stop();
    } catch (e) {
      print('Error stopping advertising: $e');
    }
  }

  // TEACHER SIDE - Start Scanning
  static Future<bool> startScanning(Function(String) onDeviceFound) async {
    try {
      bool granted = await requestPermissions();
      if (!granted) return false;

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 60));

      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          final data = result.advertisementData.manufacturerData;
          if (data.containsKey(manufacturerId)) {
            final rollBytes = data[manufacturerId]!;
            final rollNo = String.fromCharCodes(rollBytes);
            onDeviceFound(rollNo);
          }
        }
      });

      return true;
    } catch (e) {
      print('Error starting scan: $e');
      return false;
    }
  }

  static Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Error stopping scan: $e');
    }
  }
}