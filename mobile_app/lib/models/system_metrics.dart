class CpuMetrics {
  final double percent;
  final List<double> perCore;
  final int count;
  final double? temperatureC;
  final double loadAvg1m;
  final double loadAvg5m;
  final double loadAvg15m;
  final Map<String, dynamic> throttled;

  CpuMetrics({
    required this.percent,
    required this.perCore,
    required this.count,
    this.temperatureC,
    required this.loadAvg1m,
    required this.loadAvg5m,
    required this.loadAvg15m,
    required this.throttled,
  });

  factory CpuMetrics.fromMap(Map<String, dynamic> map) {
    return CpuMetrics(
      percent: (map['percent'] as num?)?.toDouble() ?? 0.0,
      perCore: (map['per_core'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      count: map['count'] ?? 1,
      temperatureC: (map['temperature_c'] as num?)?.toDouble(),
      loadAvg1m: (map['load_avg_1m'] as num?)?.toDouble() ?? 0.0,
      loadAvg5m: (map['load_avg_5m'] as num?)?.toDouble() ?? 0.0,
      loadAvg15m: (map['load_avg_15m'] as num?)?.toDouble() ?? 0.0,
      throttled: Map<String, dynamic>.from(map['throttled'] ?? {}),
    );
  }
}

class MemoryMetrics {
  final double totalMb;
  final double usedMb;
  final double availableMb;
  final double percent;

  MemoryMetrics({
    required this.totalMb,
    required this.usedMb,
    required this.availableMb,
    required this.percent,
  });

  factory MemoryMetrics.fromMap(Map<String, dynamic> map) {
    return MemoryMetrics(
      totalMb: (map['total_mb'] as num?)?.toDouble() ?? 0.0,
      usedMb: (map['used_mb'] as num?)?.toDouble() ?? 0.0,
      availableMb: (map['available_mb'] as num?)?.toDouble() ?? 0.0,
      percent: (map['percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DiskMetrics {
  final double totalGb;
  final double usedGb;
  final double freeGb;
  final double percent;

  DiskMetrics({
    required this.totalGb,
    required this.usedGb,
    required this.freeGb,
    required this.percent,
  });

  factory DiskMetrics.fromMap(Map<String, dynamic> map) {
    return DiskMetrics(
      totalGb: (map['total_gb'] as num?)?.toDouble() ?? 0.0,
      usedGb: (map['used_gb'] as num?)?.toDouble() ?? 0.0,
      freeGb: (map['free_gb'] as num?)?.toDouble() ?? 0.0,
      percent: (map['percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NetworkMetrics {
  final double uploadKbps;
  final double downloadKbps;
  final double totalSentMb;
  final double totalRecvMb;

  NetworkMetrics({
    required this.uploadKbps,
    required this.downloadKbps,
    required this.totalSentMb,
    required this.totalRecvMb,
  });

  factory NetworkMetrics.fromMap(Map<String, dynamic> map) {
    return NetworkMetrics(
      uploadKbps: (map['upload_kbps'] as num?)?.toDouble() ?? 0.0,
      downloadKbps: (map['download_kbps'] as num?)?.toDouble() ?? 0.0,
      totalSentMb: (map['total_sent_mb'] as num?)?.toDouble() ?? 0.0,
      totalRecvMb: (map['total_recv_mb'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DeviceInfo {
  final String model;
  final String hostname;
  final int uptimeSeconds;
  final String uptimeHuman;
  final String? tailscaleIp;

  DeviceInfo({
    required this.model,
    required this.hostname,
    required this.uptimeSeconds,
    required this.uptimeHuman,
    this.tailscaleIp,
  });

  factory DeviceInfo.fromMap(Map<String, dynamic> map) {
    return DeviceInfo(
      model: map['model'] ?? 'Raspberry Pi',
      hostname: map['hostname'] ?? 'raspberrypi',
      uptimeSeconds: map['uptime_seconds'] ?? 0,
      uptimeHuman: map['uptime_human'] ?? '0m',
      tailscaleIp: map['tailscale_ip'],
    );
  }
}

class SystemMetrics {
  final double timestamp;
  final DeviceInfo device;
  final CpuMetrics cpu;
  final MemoryMetrics memory;
  final DiskMetrics disk;
  final NetworkMetrics network;

  SystemMetrics({
    required this.timestamp,
    required this.device,
    required this.cpu,
    required this.memory,
    required this.disk,
    required this.network,
  });

  factory SystemMetrics.fromMap(Map<String, dynamic> map) {
    return SystemMetrics(
      timestamp: (map['timestamp'] as num?)?.toDouble() ?? 0.0,
      device: DeviceInfo.fromMap(map['device'] ?? {}),
      cpu: CpuMetrics.fromMap(map['cpu'] ?? {}),
      memory: MemoryMetrics.fromMap(map['memory'] ?? {}),
      disk: DiskMetrics.fromMap(map['disk'] ?? {}),
      network: NetworkMetrics.fromMap(map['network'] ?? {}),
    );
  }
}
