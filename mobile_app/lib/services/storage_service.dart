import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pi_device.dart';

class StorageService {
  static const String _devicesKey = 'pimobile_saved_devices';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Loads saved Raspberry Pi configurations
  Future<List<PiDevice>> loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_devicesKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> list = json.decode(jsonStr);
      List<PiDevice> devices = [];
      for (var item in list) {
        final device = PiDevice.fromMap(item);
        // Load secret credentials from Secure Storage
        final password = await _secureStorage.read(key: 'ssh_pwd_${device.id}');
        final privateKey = await _secureStorage.read(key: 'ssh_key_${device.id}');
        final token = await _secureStorage.read(key: 'token_${device.id}') ?? device.token;

        devices.add(device.copyWith(
          sshPassword: password,
          sshPrivateKey: privateKey,
          token: token,
        ));
      }
      return devices;
    } catch (_) {
      return [];
    }
  }

  /// Saves a device configuration and its security credentials
  Future<void> saveDevice(PiDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    final devices = await loadDevices();

    final existingIndex = devices.indexWhere((d) => d.id == device.id);
    if (existingIndex >= 0) {
      devices[existingIndex] = device;
    } else {
      devices.add(device);
    }

    // Persist sensitive secrets in hardware keychain/keystore
    if (device.sshPassword != null) {
      await _secureStorage.write(key: 'ssh_pwd_${device.id}', value: device.sshPassword);
    }
    if (device.sshPrivateKey != null) {
      await _secureStorage.write(key: 'ssh_key_${device.id}', value: device.sshPrivateKey);
    }
    await _secureStorage.write(key: 'token_${device.id}', value: device.token);

    // Save metadata in shared preferences
    final serializable = devices.map((d) {
      final map = d.toMap();
      map.remove('sshPassword');
      map.remove('sshPrivateKey');
      return map;
    }).toList();

    await prefs.setString(_devicesKey, json.encode(serializable));
  }

  /// Removes a device and purges its stored secrets
  Future<void> deleteDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final devices = await loadDevices();
    devices.removeWhere((d) => d.id == deviceId);

    await _secureStorage.delete(key: 'ssh_pwd_$deviceId');
    await _secureStorage.delete(key: 'ssh_key_$deviceId');
    await _secureStorage.delete(key: 'token_$deviceId');

    final serializable = devices.map((d) {
      final map = d.toMap();
      map.remove('sshPassword');
      map.remove('sshPrivateKey');
      return map;
    }).toList();

    await prefs.setString(_devicesKey, json.encode(serializable));
  }
}
