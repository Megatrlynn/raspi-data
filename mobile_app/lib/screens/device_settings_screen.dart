import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pi_device.dart';
import '../providers/device_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/glass_card.dart';

class DeviceSettingsScreen extends ConsumerStatefulWidget {
  final PiDevice? deviceToEdit;

  const DeviceSettingsScreen({super.key, this.deviceToEdit});

  @override
  ConsumerState<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends ConsumerState<DeviceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _localHostCtrl;
  late TextEditingController _tailscaleHostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _tokenCtrl;
  late TextEditingController _sshUserCtrl;
  late TextEditingController _sshPortCtrl;
  late TextEditingController _sshPasswordCtrl;
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final d = widget.deviceToEdit;
    _nameCtrl = TextEditingController(text: d?.name ?? 'Raspberry Pi 5');
    _localHostCtrl = TextEditingController(text: d?.localHost ?? 'raspberrypi.local');
    _tailscaleHostCtrl = TextEditingController(text: d?.tailscaleHost ?? '');
    _portCtrl = TextEditingController(text: (d?.port ?? 8765).toString());
    _tokenCtrl = TextEditingController(text: d?.token ?? '');
    _sshUserCtrl = TextEditingController(text: d?.sshUsername ?? 'pi');
    _sshPortCtrl = TextEditingController(text: (d?.sshPort ?? 22).toString());
    _sshPasswordCtrl = TextEditingController(text: d?.sshPassword ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _localHostCtrl.dispose();
    _tailscaleHostCtrl.dispose();
    _portCtrl.dispose();
    _tokenCtrl.dispose();
    _sshUserCtrl.dispose();
    _sshPortCtrl.dispose();
    _sshPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final api = ref.read(apiServiceProvider);
    final port = int.tryParse(_portCtrl.text) ?? 8765;
    final token = _tokenCtrl.text.trim();

    bool localOk = await api.pingHost(_localHostCtrl.text.trim(), port, token);
    bool tsOk = false;
    if (_tailscaleHostCtrl.text.trim().isNotEmpty) {
      tsOk = await api.pingHost(_tailscaleHostCtrl.text.trim(), port, token);
    }

    setState(() {
      _isTesting = false;
      if (localOk && tsOk) {
        _testResult = '✓ Both Local LAN & Tailscale mesh connections succeeded!';
      } else if (localOk) {
        _testResult = '✓ Local LAN connected. (Tailscale unreachable or not set)';
      } else if (tsOk) {
        _testResult = '✓ Tailscale remote mesh connected! (Local LAN offline)';
      } else {
        _testResult = '✗ Unable to reach Pi-Agent. Verify IP and Auth Token.';
      }
    });
  }

  void _saveDevice() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    final id = widget.deviceToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final newDevice = PiDevice(
      id: id,
      name: _nameCtrl.text.trim(),
      localHost: _localHostCtrl.text.trim(),
      tailscaleHost: _tailscaleHostCtrl.text.trim().isEmpty ? null : _tailscaleHostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text) ?? 8765,
      token: _tokenCtrl.text.trim(),
      sshUsername: _sshUserCtrl.text.trim(),
      sshPort: int.tryParse(_sshPortCtrl.text) ?? 22,
      sshPassword: _sshPasswordCtrl.text.isEmpty ? null : _sshPasswordCtrl.text,
    );

    ref.read(deviceListProvider.notifier).addOrUpdateDevice(newDevice);
    ref.read(selectedDeviceProvider.notifier).state = newDevice;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved "${newDevice.name}" successfully'),
        backgroundColor: AppColors.emerald,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.deviceToEdit != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        title: Text(
          isEditing ? 'Edit Raspberry Pi' : 'Add New Raspberry Pi',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: BouncingButton(
              height: 38,
              label: 'SAVE',
              onPressed: _saveDevice,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Device Identity
            _sectionHeader('Device Profile', isDark),
            GlassCard(
              child: _buildTextField(
                _nameCtrl,
                'Device Friendly Name',
                Icons.label_rounded,
                isDark,
                validator: (v) => v!.isEmpty ? 'Name required' : null,
              ),
            ),
            const SizedBox(height: 20),

            // Networking & Tailscale
            _sectionHeader('Network Endpoints', isDark),
            GlassCard(
              child: Column(
                children: [
                  _buildTextField(
                    _localHostCtrl,
                    'Local LAN IP / Hostname',
                    Icons.wifi_rounded,
                    isDark,
                    helperText: 'e.g. 192.168.1.150 or raspberrypi.local',
                    validator: (v) => v!.isEmpty ? 'Local IP or hostname required' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    _tailscaleHostCtrl,
                    'Tailscale Mesh IP (Remote Internet)',
                    Icons.vpn_lock_rounded,
                    isDark,
                    helperText: 'e.g. 100.x.y.z or pi-name.tailnet.ts.net (Optional)',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildTextField(
                          _portCtrl,
                          'Agent Port',
                          Icons.tag_rounded,
                          isDark,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          _tokenCtrl,
                          'Auth Token',
                          Icons.key_rounded,
                          isDark,
                          obscureText: true,
                          validator: (v) => v!.isEmpty ? 'Token required' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SSH Credentials
            _sectionHeader('SSH Terminal Access', isDark),
            GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField(_sshUserCtrl, 'SSH Username', Icons.person_rounded, isDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _buildTextField(_sshPortCtrl, 'Port', Icons.numbers_rounded, isDark, keyboardType: TextInputType.number),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(_sshPasswordCtrl, 'SSH Password', Icons.password_rounded, isDark, obscureText: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Test Connection Button with Debouncing
            BouncingButton(
              height: 52,
              label: 'Test Connection Route',
              icon: Icons.network_check_rounded,
              isLoading: _isTesting,
              gradient: AppColors.cyanGradient,
              textColor: Colors.black,
              onPressed: _testConnection,
            ),

            if (_testResult != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _testResult!.startsWith('✓') ? AppColors.emerald.withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _testResult!.startsWith('✓') ? AppColors.emerald : const Color(0xFFEF4444),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _testResult!.startsWith('✓') ? Icons.check_circle_rounded : Icons.error_rounded,
                      color: _testResult!.startsWith('✓') ? AppColors.emerald : const Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: _testResult!.startsWith('✓') ? AppColors.emerald : const Color(0xFFEF4444),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (isEditing) ...[
              const SizedBox(height: 36),
              BouncingButton(
                isSecondary: true,
                label: 'Remove Raspberry Pi',
                icon: Icons.delete_outline_rounded,
                textColor: const Color(0xFFEF4444),
                borderColor: const Color(0xFFEF4444).withOpacity(0.4),
                onPressed: () {
                  ref.read(deviceListProvider.notifier).removeDevice(widget.deviceToEdit!.id);
                  Navigator.pop(context);
                },
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isDark, {
    String? helperText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          fontSize: 13,
        ),
        helperText: helperText,
        helperStyle: TextStyle(
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          fontSize: 11,
        ),
        prefixIcon: Icon(icon, color: AppColors.cyan, size: 20),
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
        ),
      ),
    );
  }
}
