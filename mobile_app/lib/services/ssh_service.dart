import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../models/pi_device.dart';

class SSHService {
  SSHClient? _client;
  SSHSession? _session;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  /// Connects to the Raspberry Pi over SSH and initiates an interactive PTY shell
  Future<Stream<Uint8List>> startTerminalSession({
    required PiDevice device,
    required Function(String error) onError,
    int width = 80,
    int height = 24,
  }) async {
    try {
      final socket = await SSHSocket.connect(
        device.activeHost,
        device.sshPort,
        timeout: const Duration(seconds: 10),
      );

      _client = SSHClient(
        socket,
        username: device.sshUsername,
        onPasswordRequest: () {
          if (device.sshPassword != null && device.sshPassword!.isNotEmpty) {
            return device.sshPassword!;
          }
          throw Exception('SSH password required but not provided');
        },
        identities: device.sshPrivateKey != null && device.sshPrivateKey!.isNotEmpty
            ? [
                ...SSHKeyPair.fromPem(device.sshPrivateKey!),
              ]
            : null,
      );

      await _client!.authenticated;

      _session = await _client!.shell(
        pty: SSHPtyConfig(
          width: width,
          height: height,
        ),
      );

      _isConnected = true;
      return _session!.stdout;
    } catch (e) {
      _isConnected = false;
      onError(e.toString());
      rethrow;
    }
  }

  /// Sends keystrokes/data from terminal input into the remote PTY
  void write(String data) {
    if (_session != null && _isConnected) {
      _session!.stdin.add(utf8.encode(data));
    }
  }

  /// Resizes the remote PTY window when mobile orientation changes
  void resize(int width, int height) {
    if (_session != null && _isConnected) {
      _session!.resizeTerminal(width, height);
    }
  }

  /// Disconnects the active session cleanly
  Future<void> disconnect() async {
    _isConnected = false;
    try {
      _session?.close();
      _client?.close();
    } catch (_) {}
    _session = null;
    _client = null;
  }
}
