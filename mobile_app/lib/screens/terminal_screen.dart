import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../models/pi_device.dart';
import '../providers/device_provider.dart';
import '../services/ssh_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_button.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  late final Terminal _terminal;
  final SSHService _sshService = SSHService();
  bool _isConnecting = false;
  bool _ctrlActive = false;
  bool _altActive = false;
  StreamSubscription? _stdoutSub;

  final List<String> _quickMacros = [
    'htop',
    'docker ps',
    'systemctl status',
    'tailscale status',
    'uname -a',
    'df -h',
    'clear',
  ];

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 3000);
    _terminal.onOutput = (data) {
      _sshService.write(data);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectSSH();
    });
  }

  Future<void> _connectSSH() async {
    final device = ref.read(selectedDeviceProvider);
    if (device == null) return;

    setState(() {
      _isConnecting = true;
    });

    _terminal.write('\x1b[38;5;45m⚡ Initiating secure SSH shell to ${device.sshUsername}@${device.activeHost}:${device.sshPort}...\x1b[0m\r\n');

    try {
      final stdoutStream = await _sshService.startTerminalSession(
        device: device,
        onError: (err) {
          _terminal.write('\r\n\x1b[31;1m[SSH Error]: $err\x1b[0m\r\n');
        },
      );

      _stdoutSub = stdoutStream.listen(
        (data) {
          _terminal.write(String.fromCharCodes(data));
        },
        onDone: () {
          _terminal.write('\r\n\x1b[33m[Connection closed by remote host]\x1b[0m\r\n');
          if (mounted) setState(() {});
        },
      );

      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  void _sendKey(String key) {
    HapticFeedback.lightImpact();
    if (_ctrlActive && key.length == 1) {
      final code = key.toUpperCase().codeUnitAt(0) - 64;
      if (code >= 0 && code <= 31) {
        _sshService.write(String.fromCharCode(code));
      }
      setState(() => _ctrlActive = false);
    } else {
      _sshService.write(key);
    }
  }

  void _runMacro(String cmd) {
    HapticFeedback.mediumImpact();
    _sshService.write('$cmd\r');
  }

  @override
  void dispose() {
    _stdoutSub?.cancel();
    _sshService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(selectedDeviceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF07090E) : const Color(0xFF1E222D),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFF161922),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.cyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.terminal_rounded, size: 16, color: AppColors.cyan),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device != null ? '${device.sshUsername}@${device.activeHost}' : 'SSH Terminal',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isConnecting ? 'Authenticating...' : (_sshService.isConnected ? 'Connected • PTY active' : 'Disconnected'),
                    style: TextStyle(
                      fontSize: 10,
                      color: _sshService.isConnected ? AppColors.emerald : AppColors.darkTextMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.cyan),
            tooltip: 'Reconnect',
            onPressed: _connectSSH,
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded, color: AppColors.darkTextMuted),
            tooltip: 'Clear Output',
            onPressed: () => _terminal.eraseDisplay(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isConnecting)
            const LinearProgressIndicator(
              minHeight: 2.5,
              color: AppColors.berry,
              backgroundColor: AppColors.darkSurface,
            ),

          // Terminal Emulator Viewport
          Expanded(
            child: Container(
              color: const Color(0xFF07090E),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: TerminalView(
                _terminal,
                backgroundOpacity: 0.0,
                autofocus: true,
              ),
            ),
          ),

          // Quick Snippets / Macros Bar
          Container(
            height: 38,
            color: const Color(0xFF0E121B),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: _quickMacros.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final macro = _quickMacros[idx];
                return InkWell(
                  onTap: () => _runMacro(macro),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF171E2D),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF253047), width: 0.8),
                    ),
                    child: Text(
                      macro,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Tactile Programmer Accessory Toolbar
          _buildAccessoryBar(),
        ],
      ),
    );
  }

  Widget _buildAccessoryBar() {
    return Container(
      height: 48,
      color: const Color(0xFF141926),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _barButton('ESC', () => _sendKey('\x1b')),
          _barButton('TAB', () => _sendKey('\t')),
          _barToggle('CTRL', _ctrlActive, () => setState(() => _ctrlActive = !_ctrlActive)),
          _barToggle('ALT', _altActive, () => setState(() => _altActive = !_altActive)),
          _barButton('^C', () => _sendKey('\x03'), color: const Color(0xFFEF4444)),
          _barButton('|', () => _sendKey('|')),
          _barButton('~', () => _sendKey('~')),
          _barButton('/', () => _sendKey('/')),
          _barButton('-', () => _sendKey('-')),
          _barButton('$', () => _sendKey('\$')),
          _barButton('↑', () => _sendKey('\x1b[A')),
          _barButton('↓', () => _sendKey('\x1b[B')),
          _barButton('←', () => _sendKey('\x1b[D')),
          _barButton('→', () => _sendKey('\x1b[C')),
        ],
      ),
    );
  }

  Widget _barButton(String label, VoidCallback onPressed, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: const Color(0xFF1F2637),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2C364E)),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color ?? Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _barToggle(String label, bool active, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: active ? AppColors.cyan : const Color(0xFF1F2637),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            HapticFeedback.selectionClick();
            onPressed();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? AppColors.cyan : const Color(0xFF2C364E)),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : AppColors.darkTextSecondary,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
