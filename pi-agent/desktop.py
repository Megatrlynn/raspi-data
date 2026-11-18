"""
desktop.py - Raspberry Pi Remote Desktop (VNC/Wayland) Manager & Web Bridge
Supports WayVNC (Bookworm/Wayfire), TigerVNC/RealVNC (X11), and noVNC WebSocket streaming.
"""

import os
import shutil
import subprocess
import logging
from typing import Dict, Any

logger = logging.getLogger("pi-agent.desktop")

class RemoteDesktopManager:
    def __init__(self, vnc_port: int = 5900):
        self.vnc_port = vnc_port

    def get_status(self) -> Dict[str, Any]:
        """Detect active display server and VNC server status."""
        wayland_active = bool(os.environ.get("WAYLAND_DISPLAY") or os.path.exists("/run/user/1000/wayland-0"))
        x11_active = bool(os.environ.get("DISPLAY"))

        is_running = self._is_port_open("127.0.0.1", self.vnc_port) or self._is_process_running(["wayvnc", "vncserver", "vncserver-x11"])

        return {
            "vnc_running": is_running,
            "vnc_port": self.vnc_port,
            "display_server": "Wayland (Wayfire/Labwc)" if wayland_active else ("X11" if x11_active else "Headless/Terminal"),
            "wayvnc_installed": shutil.which("wayvnc") is not None,
            "realvnc_installed": shutil.which("vncserver-x11") is not None or shutil.which("vncserver") is not None,
            "novnc_available": True
        }

    def start_desktop_service(self) -> Dict[str, Any]:
        """Attempt to activate or start the appropriate VNC daemon."""
        # 1. Try systemd service for wayvnc
        try:
            res = subprocess.run(["systemctl", "--user", "start", "wayvnc"], capture_output=True, text=True)
            if res.returncode == 0:
                return {"success": True, "message": "WayVNC user service started"}
        except Exception:
            pass

        # 2. Try raspi-config / vnc system service
        try:
            res = subprocess.run(["sudo", "systemctl", "start", "vncserver-x11-serviced"], capture_output=True, text=True)
            if res.returncode == 0:
                return {"success": True, "message": "RealVNC service started"}
        except Exception:
            pass

        return {"success": False, "message": "Could not auto-start VNC. Ensure VNC is enabled via 'sudo raspi-config'"}

    @staticmethod
    def _is_process_running(names: list) -> bool:
        try:
            import psutil
            for p in psutil.process_iter(['name']):
                if p.info['name'] in names:
                    return True
        except Exception:
            pass
        return False

    @staticmethod
    def _is_port_open(host: str, port: int) -> bool:
        import socket
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(0.5)
            return s.connect_ex((host, port)) == 0
