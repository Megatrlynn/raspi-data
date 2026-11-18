"""
discovery.py - Zero-configuration mDNS Broadcaster
Enables mobile apps on the same Wi-Fi / LAN to discover Raspberry Pi devices automatically.
"""

import socket
import logging
from typing import Optional
from zeroconf import IPVersion, ServiceInfo, Zeroconf

logger = logging.getLogger("pi-agent.discovery")

class DeviceAnnouncer:
    def __init__(self, service_name: str, port: int, model: str):
        self.service_name = service_name
        self.port = port
        self.model = model
        self.zeroconf: Optional[Zeroconf] = None
        self.info: Optional[ServiceInfo] = None

    def start(self):
        """Register the mDNS service advertisement."""
        try:
            self.zeroconf = Zeroconf(ip_version=IPVersion.V4Only)
            hostname = socket.gethostname()
            local_ip = self._get_primary_ip()

            desc = {
                "version": "1.0.0",
                "model": self.model,
                "hostname": hostname,
                "api": "pi-agent-v1"
            }

            service_type = "_pi-remote._tcp.local."
            full_name = f"{self.service_name}.{service_type}"

            self.info = ServiceInfo(
                service_type,
                full_name,
                addresses=[socket.inet_aton(local_ip)],
                port=self.port,
                properties=desc,
                server=f"{hostname}.local.",
            )

            self.zeroconf.register_service(self.info)
            logger.info(f"mDNS registered: {full_name} on {local_ip}:{self.port}")
        except Exception as e:
            logger.warning(f"Could not initialize mDNS broadcast: {e}")

    def stop(self):
        """Unregister the service advertisement on shutdown."""
        if self.zeroconf and self.info:
            try:
                self.zeroconf.unregister_service(self.info)
                self.zeroconf.close()
                logger.info("mDNS unregistered successfully")
            except Exception as e:
                logger.error(f"Error closing mDNS: {e}")

    def _get_primary_ip(self) -> str:
        """Find the active local network IP address."""
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            # Does not actually transmit packets, just routes to local interface
            s.connect(('8.8.8.8', 80))
            ip = s.getsockname()[0]
        except Exception:
            ip = '127.0.0.1'
        finally:
            s.close()
        return ip
