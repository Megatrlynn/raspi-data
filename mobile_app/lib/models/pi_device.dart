import 'dart:convert';

enum ConnectionRoute { local, tailscale }

class PiDevice {
  final String id;
  final String name;
  final String localHost;
  final String? tailscaleHost;
  final int port;
  final String token;
  final int sshPort;
  final String sshUsername;
  final String? sshPassword;
  final String? sshPrivateKey;
  final ConnectionRoute preferredRoute;
  final bool isOnline;

  const PiDevice({
    required this.id,
    required this.name,
    required this.localHost,
    this.tailscaleHost,
    this.port = 8765,
    required this.token,
    this.sshPort = 22,
    this.sshUsername = 'pi',
    this.sshPassword,
    this.sshPrivateKey,
    this.preferredRoute = ConnectionRoute.local,
    this.isOnline = false,
  });

  /// Active IP/hostname depending on current connection route
  String get activeHost {
    if (preferredRoute == ConnectionRoute.tailscale && tailscaleHost != null && tailscaleHost!.isNotEmpty) {
      return tailscaleHost!;
    }
    return localHost;
  }

  /// Base HTTP API URL
  String get baseUrl => 'http://$activeHost:$port';

  /// WebSocket URL for telemetry streaming
  String get wsMetricsUrl => 'ws://$activeHost:$port/ws/metrics?token=$token';

  /// URL for the embedded remote desktop web viewer
  String get desktopUrl => '$baseUrl/desktop?token=$token';

  PiDevice copyWith({
    String? id,
    String? name,
    String? localHost,
    String? tailscaleHost,
    int? port,
    String? token,
    int? sshPort,
    String? sshUsername,
    String? sshPassword,
    String? sshPrivateKey,
    ConnectionRoute? preferredRoute,
    bool? isOnline,
  }) {
    return PiDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      localHost: localHost ?? this.localHost,
      tailscaleHost: tailscaleHost ?? this.tailscaleHost,
      port: port ?? this.port,
      token: token ?? this.token,
      sshPort: sshPort ?? this.sshPort,
      sshUsername: sshUsername ?? this.sshUsername,
      sshPassword: sshPassword ?? this.sshPassword,
      sshPrivateKey: sshPrivateKey ?? this.sshPrivateKey,
      preferredRoute: preferredRoute ?? this.preferredRoute,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'localHost': localHost,
      'tailscaleHost': tailscaleHost,
      'port': port,
      'token': token,
      'sshPort': sshPort,
      'sshUsername': sshUsername,
      'sshPassword': sshPassword,
      'sshPrivateKey': sshPrivateKey,
      'preferredRoute': preferredRoute.name,
    };
  }

  factory PiDevice.fromMap(Map<String, dynamic> map) {
    return PiDevice(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Raspberry Pi',
      localHost: map['localHost'] ?? '',
      tailscaleHost: map['tailscaleHost'],
      port: map['port']?.toInt() ?? 8765,
      token: map['token'] ?? '',
      sshPort: map['sshPort']?.toInt() ?? 22,
      sshUsername: map['sshUsername'] ?? 'pi',
      sshPassword: map['sshPassword'],
      sshPrivateKey: map['sshPrivateKey'],
      preferredRoute: map['preferredRoute'] == 'tailscale'
          ? ConnectionRoute.tailscale
          : ConnectionRoute.local,
      isOnline: false,
    );
  }

  String toJson() => json.encode(toMap());

  factory PiDevice.fromJson(String source) => PiDevice.fromMap(json.decode(source));
}
