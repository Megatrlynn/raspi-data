import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/pi_device.dart';
import '../models/system_metrics.dart';
import '../providers/device_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/gauge_card.dart';
import '../widgets/status_pill.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/cyber_loader.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_counter.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDevice = ref.watch(selectedDeviceProvider);
    final metricsAsync = ref.watch(liveMetricsProvider);
    final api = ref.watch(apiServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activeDevice == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.berry.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.developer_board, size: 54, color: AppColors.berry),
              ),
              const SizedBox(height: 20),
              Text(
                'No Raspberry Pi Selected',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add or select a Raspberry Pi device to start live telemetry.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              floating: true,
              pinned: false,
              backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
              elevation: 0,
              title: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeDevice.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StatusPill(
                          isOnline: activeDevice.isOnline,
                          isTailscale: activeDevice.preferredRoute == ConnectionRoute.tailscale,
                          label: activeDevice.preferredRoute == ConnectionRoute.tailscale
                              ? 'Tailscale Mesh (${activeDevice.activeHost})'
                              : 'Local LAN (${activeDevice.activeHost})',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                // Theme Toggle with Micro-Interaction
                IconButton(
                  tooltip: 'Toggle Theme',
                  icon: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    color: isDark ? AppColors.amber : AppColors.purple,
                  ),
                  onPressed: () {
                    ref.read(themeProvider.notifier).toggleTheme();
                  },
                ),
                // Power Actions Menu
                IconButton(
                  tooltip: 'Power Management',
                  icon: const Icon(Icons.power_settings_new_rounded, color: Color(0xFFEF4444)),
                  onPressed: () => _showPowerModal(context, activeDevice, api),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
          body: metricsAsync.when(
            data: (metrics) {
              if (metrics == null) {
                return const Center(
                  child: CyberOrbitalLoader(
                    label: 'Syncing telemetry stream...',
                  ),
                );
              }
              return _buildDashboardContent(context, ref, activeDevice, metrics, isDark);
            },
            loading: () => const Center(
              child: CyberOrbitalLoader(
                label: 'Connecting to Pi-Agent...',
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 52, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text(
                      'Connection Offline',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Could not reach ${activeDevice.activeHost}:${activeDevice.port}.\nVerify Wi-Fi or Tailscale connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    BouncingButton(
                      label: 'Retry Connection',
                      icon: Icons.refresh_rounded,
                      width: 190,
                      onPressed: () => ref.refresh(liveMetricsProvider),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    PiDevice device,
    SystemMetrics metrics,
    bool isDark,
  ) {
    final tempC = metrics.cpu.temperatureC;
    final isOverheating = tempC != null && tempC >= 75.0;
    final isThrottled = metrics.cpu.throttled['throttled'] == true ||
        metrics.cpu.throttled['under_voltage'] == true;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Hero Device Info Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.berryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.berryGlow.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.memory_rounded, size: 28, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metrics.device.model,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 13, color: Colors.white70),
                        const SizedBox(width: 5),
                        Text(
                          'Uptime: ${metrics.device.uptimeHuman}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isThrottled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.amber),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'THROTTLED',
                        style: TextStyle(color: AppColors.amber, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(height: 18),

        // Section Title: Hardware Telemetry
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LIVE HARDWARE VITALS',
              style: TextStyle(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.emerald,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '1s Refresh',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 2x2 Grid of Futuristic Gauges
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.12,
          children: [
            MetricGaugeCard(
              title: 'CPU LOAD',
              numericValue: metrics.cpu.percent,
              suffix: '%',
              subtitle: '${metrics.cpu.count} Cores • 1m: ${metrics.cpu.loadAvg1m}',
              percent: metrics.cpu.percent / 100.0,
              icon: Icons.speed_rounded,
              activeColor: AppColors.blue,
            ).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.92, 0.92)),
            MetricGaugeCard(
              title: 'SOC TEMP',
              numericValue: tempC ?? 0.0,
              suffix: '°C',
              subtitle: isOverheating ? 'Active Cooling Advised' : 'Optimal Thermal Zone',
              percent: tempC != null ? (tempC / 85.0) : 0.0,
              icon: Icons.thermostat_rounded,
              activeColor: AppColors.amber,
              isWarning: isOverheating || isThrottled,
            ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.92, 0.92)),
            MetricGaugeCard(
              title: 'RAM MEMORY',
              numericValue: metrics.memory.percent,
              suffix: '%',
              subtitle: '${metrics.memory.usedMb.toInt()} / ${metrics.memory.totalMb.toInt()} MB',
              percent: metrics.memory.percent / 100.0,
              icon: Icons.data_usage_rounded,
              activeColor: AppColors.emerald,
            ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.92, 0.92)),
            MetricGaugeCard(
              title: 'NVME / SD DISK',
              numericValue: metrics.disk.percent,
              suffix: '%',
              subtitle: '${metrics.disk.usedGb.toStringAsFixed(1)} / ${metrics.disk.totalGb.toStringAsFixed(1)} GB',
              percent: metrics.disk.percent / 100.0,
              icon: Icons.pie_chart_outline_rounded,
              activeColor: AppColors.purple,
            ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.92, 0.92)),
          ],
        ),

        const SizedBox(height: 18),

        // Real-Time Network I/O Telemetry Card
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withOpacity(isDark ? 0.16 : 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.swap_vert_rounded, size: 16, color: AppColors.cyan),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'NETWORK BANDWIDTH',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Live TX/RX',
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.cyan),
                              const SizedBox(width: 4),
                              Text(
                                'Upload',
                                style: TextStyle(
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AnimatedCounterText(
                            value: metrics.network.uploadKbps,
                            suffix: ' KB/s',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sent: ${metrics.network.totalSentMb} MB',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.emerald),
                              const SizedBox(width: 4),
                              Text(
                                'Download',
                                style: TextStyle(
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AnimatedCounterText(
                            value: metrics.network.downloadKbps,
                            suffix: ' KB/s',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Recv: ${metrics.network.totalRecvMb} MB',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(height: 28),
      ],
    );
  }

  void _showPowerModal(BuildContext context, PiDevice device, dynamic api) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Power Controls',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Transmit graceful reboot or poweroff signal to ${device.name}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: BouncingButton(
                        label: 'Reboot',
                        icon: Icons.restart_alt_rounded,
                        backgroundColor: AppColors.amber,
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final confirmed = await _confirmDialog(context, 'Reboot');
                          if (confirmed) {
                            await api.sendPowerAction(device, 'reboot');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Rebooting Raspberry Pi...')),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BouncingButton(
                        label: 'Shutdown',
                        icon: Icons.power_settings_new_rounded,
                        backgroundColor: const Color(0xFFEF4444),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final confirmed = await _confirmDialog(context, 'Shutdown');
                          if (confirmed) {
                            await api.sendPowerAction(device, 'shutdown');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Shutting down Raspberry Pi...')),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDialog(BuildContext context, String action) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              '$action Confirmation',
              style: TextStyle(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              'Are you sure you want to $action this Raspberry Pi? Active sessions will be closed.',
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(action, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }
}
