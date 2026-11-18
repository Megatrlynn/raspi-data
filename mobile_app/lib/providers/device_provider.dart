import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/pi_device.dart';
import '../models/system_metrics.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

final apiServiceProvider = Provider((ref) => ApiService());
final storageServiceProvider = Provider((ref) => StorageService());

/// State for all registered Pi devices
class DeviceListNotifier extends StateNotifier<List<PiDevice>> {
  final StorageService _storage;
  final ApiService _api;

  DeviceListNotifier(this._storage, this._api) : super([]) {
    refreshDevices();
  }

  Future<void> refreshDevices() async {
    final devices = await _storage.loadDevices();
    state = devices;
    checkAllHealth();
  }

  Future<void> checkAllHealth() async {
    List<PiDevice> updated = [];
    for (var d in state) {
      final route = await _api.determineBestRoute(d);
      final isOnline = await _api.pingHost(
        route == ConnectionRoute.tailscale && d.tailscaleHost != null ? d.tailscaleHost! : d.localHost,
        d.port,
        d.token,
      );
      updated.add(d.copyWith(preferredRoute: route, isOnline: isOnline));
    }
    state = updated;
  }

  Future<void> addOrUpdateDevice(PiDevice device) async {
    await _storage.saveDevice(device);
    await refreshDevices();
  }

  Future<void> removeDevice(String id) async {
    await _storage.deleteDevice(id);
    await refreshDevices();
  }
}

final deviceListProvider = StateNotifierProvider<DeviceListNotifier, List<PiDevice>>((ref) {
  return DeviceListNotifier(
    ref.watch(storageServiceProvider),
    ref.watch(apiServiceProvider),
  );
});

/// Currently selected active device
final selectedDeviceProvider = StateProvider<PiDevice?>((ref) {
  final devices = ref.watch(deviceListProvider);
  return devices.isNotEmpty ? devices.first : null;
});

/// Real-time live metrics provider stream for the active device
final liveMetricsProvider = StreamProvider.autoDispose<SystemMetrics?>((ref) {
  final device = ref.watch(selectedDeviceProvider);
  final api = ref.watch(apiServiceProvider);

  if (device == null) {
    return Stream.value(null);
  }

  final controller = StreamController<SystemMetrics?>();
  WebSocketChannel? channel;
  Timer? reconnectTimer;
  bool isDisposed = false;

  void connect() {
    if (isDisposed) return;
    try {
      channel = api.connectMetricsStream(device);
      channel!.stream.listen(
        (data) {
          try {
            final parsed = json.decode(data);
            controller.add(SystemMetrics.fromMap(parsed));
          } catch (_) {}
        },
        onError: (err) {
          reconnectTimer = Timer(const Duration(seconds: 3), connect);
        },
        onDone: () {
          reconnectTimer = Timer(const Duration(seconds: 3), connect);
        },
      );
    } catch (_) {
      reconnectTimer = Timer(const Duration(seconds: 3), connect);
    }
  }

  connect();

  ref.onDispose(() {
    isDisposed = true;
    reconnectTimer?.cancel();
    channel?.sink.close();
    controller.close();
  });

  return controller.stream;
});
