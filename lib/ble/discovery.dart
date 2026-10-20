import 'dart:async';
import 'dart:io';

import 'package:duo_guitar/ble/room_beacon.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Company id carried beside [RoomBeacon] manufacturer data.
const int beaconCompanyId = 0xD617;

Future<bool> ensureBlePermissions({required bool advertise}) async {
  if (!Platform.isAndroid) {
    return false;
  }
  final permissions = <Permission>[
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse,
    if (advertise) Permission.bluetoothAdvertise,
  ];
  final result = await permissions.request();
  return result.values.every((status) => status.isGranted || status.isLimited);
}

/// Body phone: advertise the room code and LAN address.
class BodyAdvertiser {
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  var _on = false;

  Future<void> start({required String roomCode, required String ip}) async {
    if (!Platform.isAndroid || ip.isEmpty || ip == '0.0.0.0') {
      return;
    }
    if (!await ensureBlePermissions(advertise: true)) {
      return;
    }
    final payload = RoomBeacon(roomCode: roomCode, ip: ip).encode();
    await _peripheral.start(
      advertiseData: AdvertiseDataCore(
        manufacturerId: beaconCompanyId,
        manufacturerData: payload,
      ),
    );
    _on = true;
  }

  Future<void> stop() async {
    if (!_on) {
      return;
    }
    _on = false;
    try {
      await _peripheral.stop();
    } on Object {
      // Already stopped.
    }
  }
}

/// Neck phone: scan until the matching room beacon appears.
Future<String?> findBodyIp({
  required String roomCode,
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (!Platform.isAndroid) {
    return null;
  }
  if (!await ensureBlePermissions(advertise: false)) {
    return null;
  }
  final found = Completer<String?>();
  final subscription = FlutterBluePlus.scanResults.listen((results) {
    for (final result in results) {
      final data = result.advertisementData.manufacturerData[beaconCompanyId];
      if (data == null) {
        continue;
      }
      final beacon = RoomBeacon.decode(data);
      if (beacon == null || beacon.roomCode != roomCode) {
        continue;
      }
      if (!found.isCompleted) {
        found.complete(beacon.ip);
      }
      return;
    }
  });
  try {
    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
      withMsd: [MsdFilter(beaconCompanyId)],
    );
    return await found.future.timeout(timeout, onTimeout: () => null);
  } finally {
    await subscription.cancel();
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
  }
}
