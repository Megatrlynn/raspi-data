"""
metrics.py - Hardware and OS Telemetry Collector for Raspberry Pi
Extracts real-time CPU, RAM, Disk, Network, SoC Thermal Sensors, and Pi-specific diagnostics.
"""

import os
import time
import subprocess
import psutil
from typing import Dict, Any, List, Optional


class SystemMetricsCollector:
    def __init__(self):
        self.last_net_io = psutil.net_io_counters()
        self.last_net_time = time.time()
        self._pi_model = self._detect_pi_model()

    def _detect_pi_model(self) -> str:
        """Read Raspberry Pi hardware model from device-tree."""
        model_paths = [
            "/proc/device-tree/model",
            "/sys/firmware/devicetree/base/model"
        ]
        for path in model_paths:
            if os.path.exists(path):
                try:
                    with open(path, "r", encoding="utf-8", errors="ignore") as f:
                        return f.read().strip("\x00 \n\r")
                except Exception:
                    pass
        return "Generic Linux / Raspberry Pi"

    def get_cpu_temperature(self) -> Optional[float]:
        """Read Raspberry Pi SoC temperature in Celsius."""
        # 1. Direct sysfs path (standard Linux thermal subsystem)
        thermal_path = "/sys/class/thermal/thermal_zone0/temp"
        if os.path.exists(thermal_path):
            try:
                with open(thermal_path, "r") as f:
                    temp_millidegrees = int(f.read().strip())
                    return round(temp_millidegrees / 1000.0, 1)
            except Exception:
                pass

        # 2. Raspberry Pi vcgencmd utility
        try:
            output = subprocess.check_output(["vcgencmd", "measure_temp"], stderr=subprocess.DEVNULL).decode()
            # Format: temp=48.2'C
            if "temp=" in output:
                temp_str = output.split("=")[1].split("'")[0]
                return float(temp_str)
        except Exception:
            pass

        # 3. psutil fallback for generic platforms
        try:
            temps = psutil.sensors_temperatures()
            if temps:
                for name, entries in temps.items():
                    for entry in entries:
                        if entry.current is not None:
                            return round(entry.current, 1)
        except Exception:
            pass

        return None

    def get_throttled_state(self) -> Dict[str, Any]:
        """
        Check for undervoltage, frequency capping, or thermal throttling
        via vcgencmd get_throttled.
        Bit 0: Under-voltage detected
        Bit 1: ARM frequency capped
        Bit 2: Currently throttled
        Bit 3: Soft temperature limit reached
        """
        result = {
            "raw": "0x0",
            "under_voltage": False,
            "freq_capped": False,
            "throttled": False,
            "soft_temp_limit": False,
        }
        try:
            output = subprocess.check_output(["vcgencmd", "get_throttled"], stderr=subprocess.DEVNULL).decode()
            if "throttled=" in output:
                raw_hex = output.split("=")[1].strip()
                val = int(raw_hex, 16)
                result["raw"] = raw_hex
                result["under_voltage"] = bool(val & 0x1)
                result["freq_capped"] = bool(val & 0x2)
                result["throttled"] = bool(val & 0x4)
                result["soft_temp_limit"] = bool(val & 0x8)
        except Exception:
            pass
        return result

    def get_tailscale_ip(self) -> Optional[str]:
        """Retrieve current Tailscale mesh IPv4 address if installed and active."""
        try:
            output = subprocess.check_output(["tailscale", "ip", "-4"], stderr=subprocess.DEVNULL).decode().strip()
            if output:
                return output.splitlines()[0]
        except Exception:
            pass
        return None

    def get_network_rates(self) -> Dict[str, float]:
        """Compute upload and download rates in KB/s."""
        curr_io = psutil.net_io_counters()
        curr_time = time.time()
        time_delta = max(curr_time - self.last_net_time, 0.001)

        bytes_sent_delta = curr_io.bytes_sent - self.last_net_io.bytes_sent
        bytes_recv_delta = curr_io.bytes_recv - self.last_net_io.bytes_recv

        self.last_net_io = curr_io
        self.last_net_time = curr_time

        return {
            "upload_kbps": round((bytes_sent_delta / 1024.0) / time_delta, 1),
            "download_kbps": round((bytes_recv_delta / 1024.0) / time_delta, 1),
            "total_sent_mb": round(curr_io.bytes_sent / (1024.0 * 1024.0), 1),
            "total_recv_mb": round(curr_io.bytes_recv / (1024.0 * 1024.0), 1),
        }

    def collect(self) -> Dict[str, Any]:
        """Collect snapshot of all system telemetry."""
        cpu_pct = psutil.cpu_percent(interval=None)
        cpu_per_core = psutil.cpu_percent(interval=None, percpu=True)
        mem = psutil.virtual_memory()
        swap = psutil.swap_memory()
        disk = psutil.disk_usage('/')
        load_avg = os.getloadavg() if hasattr(os, "getloadavg") else (0.0, 0.0, 0.0)
        uptime_seconds = int(time.time() - psutil.boot_time())

        return {
            "timestamp": time.time(),
            "device": {
                "model": self._pi_model,
                "hostname": os.uname().nodename if hasattr(os, "uname") else "raspberrypi",
                "uptime_seconds": uptime_seconds,
                "uptime_human": self._format_uptime(uptime_seconds),
                "tailscale_ip": self.get_tailscale_ip(),
            },
            "cpu": {
                "percent": cpu_pct,
                "per_core": cpu_per_core,
                "count": psutil.cpu_count(logical=True),
                "temperature_c": self.get_cpu_temperature(),
                "load_avg_1m": round(load_avg[0], 2),
                "load_avg_5m": round(load_avg[1], 2),
                "load_avg_15m": round(load_avg[2], 2),
                "throttled": self.get_throttled_state(),
            },
            "memory": {
                "total_mb": round(mem.total / (1024 * 1024), 1),
                "used_mb": round(mem.used / (1024 * 1024), 1),
                "available_mb": round(mem.available / (1024 * 1024), 1),
                "percent": mem.percent,
            },
            "swap": {
                "total_mb": round(swap.total / (1024 * 1024), 1),
                "used_mb": round(swap.used / (1024 * 1024), 1),
                "percent": swap.percent,
            },
            "disk": {
                "total_gb": round(disk.total / (1024 ** 3), 2),
                "used_gb": round(disk.used / (1024 ** 3), 2),
                "free_gb": round(disk.free / (1024 ** 3), 2),
                "percent": disk.percent,
            },
            "network": self.get_network_rates(),
        }

    def get_top_processes(self, limit: int = 15) -> List[Dict[str, Any]]:
        """Return top running processes sorted by CPU and memory."""
        procs = []
        for p in psutil.process_iter(['pid', 'name', 'username', 'cpu_percent', 'memory_percent']):
            try:
                info = p.info
                procs.append({
                    "pid": info['pid'],
                    "name": info['name'],
                    "user": info['username'],
                    "cpu_percent": round(info['cpu_percent'] or 0.0, 1),
                    "memory_percent": round(info['memory_percent'] or 0.0, 1),
                })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        # Sort by CPU descending
        procs.sort(key=lambda x: x["cpu_percent"], reverse=True)
        return procs[:limit]

    @staticmethod
    def _format_uptime(seconds: int) -> str:
        days = seconds // 86400
        hours = (seconds % 86400) // 3600
        minutes = (seconds % 3600) // 60
        if days > 0:
            return f"{days}d {hours}h {minutes}m"
        elif hours > 0:
            return f"{hours}h {minutes}m"
        else:
            return f"{minutes}m"
