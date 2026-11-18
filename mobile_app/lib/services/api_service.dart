import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/pi_device.dart';
import '../models/system_metrics.dart';

class ApiService {
  final http.Client _client = http.Client();

  /// Pings both Local LAN and Tailscale IPs to find the fastest reachable route
  Future<ConnectionRoute> determineBestRoute(PiDevice device) async {
    // 1. Try local first
    bool localOk = await pingHost(device.localHost, device.port, device.token);
    if (localOk) {
      return ConnectionRoute.local;
    }

    // 2. Try Tailscale if configured
    if (device.tailscaleHost != null && device.tailscaleHost!.isNotEmpty) {
      bool tsOk = await pingHost(device.tailscaleHost!, device.port, device.token);
      if (tsOk) {
        return ConnectionRoute.tailscale;
      }
    }

    return ConnectionRoute.local;
  }

  Future<bool> pingHost(String host, int port, String token) async {
    try {
      final res = await _client.get(
        Uri.parse('http://$host:$port/api/health'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(milliseconds: 1500));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch full snapshot of system metrics
  Future<SystemMetrics> fetchMetrics(PiDevice device) async {
    final response = await _client.get(
      Uri.parse('${device.baseUrl}/api/system/metrics'),
      headers: {'Authorization': 'Bearer ${device.token}'},
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return SystemMetrics.fromMap(data);
    } else {
      throw Exception('Failed to load metrics: ${response.statusCode}');
    }
  }

  /// Fetch top CPU/RAM processes
  Future<List<Map<String, dynamic>>> fetchProcesses(PiDevice device, {int limit = 15}) async {
    final response = await _client.get(
      Uri.parse('${device.baseUrl}/api/system/processes?limit=$limit'),
      headers: {'Authorization': 'Bearer ${device.token}'},
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['processes'] ?? []);
    } else {
      throw Exception('Failed to load processes: ${response.statusCode}');
    }
  }

  /// Trigger reboot or shutdown
  Future<bool> sendPowerAction(PiDevice device, String action) async {
    final response = await _client.post(
      Uri.parse('${device.baseUrl}/api/system/power/$action'),
      headers: {'Authorization': 'Bearer ${device.token}'},
    ).timeout(const Duration(seconds: 6));

    return response.statusCode == 200;
  }

  /// Check WayVNC / RealVNC server status
  Future<Map<String, dynamic>> fetchDesktopStatus(PiDevice device) async {
    final response = await _client.get(
      Uri.parse('${device.baseUrl}/api/desktop/status'),
      headers: {'Authorization': 'Bearer ${device.token}'},
    ).timeout(const Duration(seconds: 3));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return {'vnc_running': false};
  }

  /// Start desktop service if not currently running
  Future<bool> startDesktopService(PiDevice device) async {
    final response = await _client.post(
      Uri.parse('${device.baseUrl}/api/desktop/start'),
      headers: {'Authorization': 'Bearer ${device.token}'},
    ).timeout(const Duration(seconds: 5));

    return response.statusCode == 200;
  }

  /// Connect to real-time WebSocket telemetry stream
  WebSocketChannel connectMetricsStream(PiDevice device) {
    return WebSocketChannel.connect(Uri.parse(device.wsMetricsUrl));
  }
}
