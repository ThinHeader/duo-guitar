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

/// First non-loopback IPv4 address, or `0.0.0.0` when none is available.
Future<String> localLanIpv4() async {
  final interfaces = await NetworkInterface.list(
    includeLinkLocal: true,
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  );
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (address.isLoopback || address.type != InternetAddressType.IPv4) {
        continue;
      }
      return address.address;
    }
  }
  return '0.0.0.0';
}
