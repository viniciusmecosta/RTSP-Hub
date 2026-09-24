import 'dart:async';
import 'dart:io';

class LocalNetworkScanner {
  Future<List<NetworkInterface>> interfaces() async {
    final result = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    return result
        .where(
          (interface) => interface.addresses.any(
            (address) =>
                !address.isLoopback &&
                !address.isLinkLocal &&
                !address.isMulticast &&
                address.address != '0.0.0.0',
          ),
        )
        .toList(growable: false);
  }

  String? suggestedRange(NetworkInterface interface) {
    for (final address in interface.addresses) {
      if (address.type == InternetAddressType.IPv4 &&
          !address.isLoopback &&
          !address.isLinkLocal) {
        final octets = address.address.split('.');
        if (octets.length == 4) return '${octets.take(3).join('.')}.0/24';
      }
    }
    return null;
  }

  List<String> hostsInRange(String cidr) {
    final parts = cidr.trim().split('/');
    if (parts.length != 2) throw const FormatException('Informe a rede CIDR.');
    final address = InternetAddress.tryParse(parts.first);
    final prefix = int.tryParse(parts.last);
    if (address == null ||
        address.type != InternetAddressType.IPv4 ||
        prefix == null ||
        prefix < 16 ||
        prefix > 30) {
      throw const FormatException('Use uma rede IPv4 entre /16 e /30.');
    }
    final octets = address.address.split('.').map(int.parse).toList();
    final integer =
        (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
    final boundedPrefix = prefix < 24 ? 24 : prefix;
    final mask = (0xffffffff << (32 - boundedPrefix)) & 0xffffffff;
    final network = integer & mask;
    final count = 1 << (32 - boundedPrefix);
    if (count > 65536) throw const FormatException('A rede é grande demais.');
    return [
      for (var offset = 1; offset < count - 1; offset++)
        _formatIpv4(network + offset),
    ];
  }

  Future<bool> isRtspPortOpen(
    String host,
    int port, {
    Duration timeout = const Duration(milliseconds: 250),
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      return true;
    } on Object {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  Stream<ScanProgress> scan(
    List<String> hosts,
    int port, {
    required bool Function() isCancelled,
    int concurrency = 32,
  }) async* {
    var completed = 0;
    final found = <String>[];
    for (var start = 0; start < hosts.length; start += concurrency) {
      if (isCancelled()) return;
      final batch = hosts.skip(start).take(concurrency).toList();
      final results = await Future.wait(
        batch.map((host) async {
          final open = await isRtspPortOpen(host, port);
          return open ? host : null;
        }),
      );
      found.addAll(results.whereType<String>());
      completed += batch.length;
      yield ScanProgress(completed, hosts.length, List.unmodifiable(found));
    }
  }

  String _formatIpv4(int value) =>
      '${(value >> 24) & 255}.${(value >> 16) & 255}.${(value >> 8) & 255}.${value & 255}';
}

class ScanProgress {
  const ScanProgress(this.completed, this.total, this.openHosts);

  final int completed;
  final int total;
  final List<String> openHosts;
}
