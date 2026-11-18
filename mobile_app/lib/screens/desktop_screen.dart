import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/device_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/cyber_loader.dart';

class DesktopScreen extends ConsumerStatefulWidget {
  const DesktopScreen({super.key});

  @override
  ConsumerState<DesktopScreen> createState() => _DesktopScreenState();
}

class _DesktopScreenState extends ConsumerState<DesktopScreen> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  bool _isVncRunning = true;
  String? _statusMessage;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _checkVncAndInit();
  }

  Future<void> _checkVncAndInit() async {
    final device = ref.read(selectedDeviceProvider);
    final api = ref.read(apiServiceProvider);
    if (device == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Detecting WayVNC / X11 display server...';
    });

    try {
      final status = await api.fetchDesktopStatus(device);
      _isVncRunning = status['vnc_running'] == true;

      if (!_isVncRunning) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Raspberry Pi OS Desktop server is inactive.';
        });
        return;
      }

      _initWebView(device.desktopUrl);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Could not establish bridge to Pi-Agent: $e';
      });
    }
  }

  void _initWebView(String url) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F1117))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {
      _webViewController = controller;
    });
  }

  Future<void> _startVncServer() async {
    final device = ref.read(selectedDeviceProvider);
    final api = ref.read(apiServiceProvider);
    if (device == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Launching WayVNC desktop daemon...';
    });

    final success = await api.startDesktopService(device);
    if (success) {
      await Future.delayed(const Duration(seconds: 2));
      await _checkVncAndInit();
    } else {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Could not auto-start VNC. Enable VNC via raspi-config.';
      });
    }
  }

  void _toggleFullscreen() {
    HapticFeedback.lightImpact();
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(selectedDeviceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (device == null) {
      return const Center(child: Text('No device selected', style: TextStyle(color: Colors.white)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C12),
      appBar: _isFullscreen
          ? null
          : AppBar(
              backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFF161922),
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.desktop_windows_rounded, size: 16, color: AppColors.purple),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Raspberry Pi OS GUI',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded, color: AppColors.cyan),
                  tooltip: 'Fullscreen',
                  onPressed: _toggleFullscreen,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Reload',
                  onPressed: () {
                    if (_webViewController != null) {
                      _webViewController!.reload();
                    } else {
                      _checkVncAndInit();
                    }
                  },
                ),
              ],
            ),
      body: Stack(
        children: [
          if (_webViewController != null && _isVncRunning)
            WebViewWidget(controller: _webViewController!),

          // Floating Controls in Fullscreen Mode
          if (_isFullscreen)
            Positioned(
              top: 20,
              right: 20,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 20),
                        onPressed: _toggleFullscreen,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: AppColors.cyan, size: 20),
                        onPressed: () => _webViewController?.reload(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Inactive / Offline VNC Prompt
          if (!_isVncRunning)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.desktop_access_disabled_rounded, size: 54, color: AppColors.amber),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _statusMessage ?? 'Desktop Server Inactive',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Bookworm Wayland runs WayVNC, while X11 uses RealVNC. Tap below to launch the display server.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    BouncingButton(
                      label: 'Start Desktop Daemon',
                      icon: Icons.play_arrow_rounded,
                      width: 220,
                      onPressed: _startVncServer,
                    ),
                  ],
                ),
              ),
            ),

          if (_isLoading)
            Container(
              color: const Color(0xFF0A0C12).withOpacity(0.85),
              child: Center(
                child: CyberOrbitalLoader(
                  label: _statusMessage ?? 'Connecting to display canvas...',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
