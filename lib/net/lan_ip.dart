import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel _netChannel = MethodChannel('duo_guitar/net');

/// Android needs this before UDP broadcast is delivered.
Future<void> acquireMulticastLock() async {
  if (!Platform.isAndroid) {
    return;
  }
  try {
    await _netChannel.invokeMethod<void>('acquireMulticastLock');
  } on Object {
    // Tests and desktop builds have no Android channel.
  }
}

/// Wi-Fi address when one exists. Cellular interfaces such as `rmnet` are skipped
/// so two phones on the same wireless network see a reachable address.
String chooseLanIpv4(Iterable<({String name, String address})> entries) {
  final usable = <({String name, String address})>[];
  for (final entry in entries) {
    if (entry.address.startsWith('127.') ||
        entry.address.startsWith('169.254.')) {
      continue;
    }
    usable.add(entry);
  }
  for (final entry in usable) {
    if (_isWifi(entry.name)) {
      return entry.address;
    }
  }
  for (final entry in usable) {
    if (!_isCellular(entry.name)) {
      return entry.address;
    }
  }
  if (usable.isNotEmpty) {
    return usable.first.address;
  }
  return '0.0.0.0';
}

bool _isWifi(String name) {
  final normalized = name.toLowerCase();
  return normalized.contains('wlan') ||
      normalized.contains('wifi') ||
      normalized.startsWith('eth') ||
      normalized.startsWith('en');
}

bool _isCellular(String name) {
  final normalized = name.toLowerCase();
  return normalized.contains('rmnet') ||
      normalized.startsWith('ccmni') ||
      normalized.startsWith('pdp') ||
      normalized.startsWith('wwan');
}

/// Wi-Fi IPv4 when the device has one, otherwise another non-cellular address.
/// Returns `0.0.0.0` when none is available.
Future<String> localLanIpv4() async {
  final interfaces = await NetworkInterface.list(
    includeLinkLocal: true,
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  );
  final entries = <({String name, String address})>[];
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (address.isLoopback || address.type != InternetAddressType.IPv4) {
        continue;
      }
      entries.add((name: interface.name, address: address.address));
    }
  }
  return chooseLanIpv4(entries);
}
