import 'package:duo_guitar/net/lan_ip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wifi address wins over the cellular rmnet address', () {
    final address = chooseLanIpv4(const [
      (name: 'rmnet_data4', address: '10.49.36.225'),
      (name: 'wlan0', address: '192.168.3.3'),
    ]);
    expect(address, '192.168.3.3');
  });

  test('cellular address is used only when nothing else exists', () {
    final address = chooseLanIpv4(const [
      (name: 'rmnet_data0', address: '10.1.2.3'),
    ]);
    expect(address, '10.1.2.3');
  });

  test('loopback and link-local addresses are ignored', () {
    final address = chooseLanIpv4(const [
      (name: 'lo', address: '127.0.0.1'),
      (name: 'wlan0', address: '169.254.1.1'),
      (name: 'eth0', address: '192.168.0.8'),
    ]);
    expect(address, '192.168.0.8');
  });
}
