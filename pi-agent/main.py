"""
main.py - Raspberry Pi Remote Agent
Provides authenticated REST & WebSocket APIs for real-time telemetry, power management,
and desktop streaming proxy over LAN and Tailscale mesh.
"""

import os
import json
import secrets
import asyncio
import logging
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException, Security, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials, APIKeyHeader
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from metrics import SystemMetricsCollector
from discovery import DeviceAnnouncer
from desktop import RemoteDesktopManager

# Setup Logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("pi-agent")

# Configuration Management
CONFIG_DIR = Path.home() / ".config" / "pi-agent"
CONFIG_FILE = CONFIG_DIR / "config.json"

def load_or_create_config():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass

    # Generate fresh security token
    token = secrets.token_urlsafe(24)
    config = {
        "auth_token": token,
        "port": 8765,
        "service_name": "Raspberry Pi Agent",
        "vnc_port": 5900,
    }
    with open(CONFIG_FILE, "w") as f:
        json.dump(config, f, indent=2)
    logger.info(f"Generated new authentication token: {token}")
    return config

config = load_or_create_config()
AUTH_TOKEN = config.get("auth_token")
AGENT_PORT = config.get("port", 8765)
VNC_PORT = config.get("vnc_port", 5900)

app = FastAPI(
    title="PiMobile Agent",
    description="High-performance secure daemon for Raspberry Pi remote management",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

metrics_collector = SystemMetricsCollector()
desktop_manager = RemoteDesktopManager(vnc_port=VNC_PORT)
announcer = DeviceAnnouncer(
    service_name=config.get("service_name", "Raspberry Pi"),
    port=AGENT_PORT,
    model=metrics_collector._pi_model
)

# Authentication Dependencies
bearer_scheme = HTTPBearer(auto_error=False)
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

def verify_token(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(bearer_scheme),
    api_key: Optional[str] = Security(api_key_header)
):
    token = None
    if credentials:
        token = credentials.credentials
    elif api_key:
        token = api_key

    if not token or token != AUTH_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return token

@app.on_event("startup")
async def startup_event():
    logger.info(f"Starting Pi-Agent on port {AGENT_PORT}")
    logger.info(f"Authentication Token: {AUTH_TOKEN}")
    announcer.start()

@app.on_event("shutdown")
async def shutdown_event():
    announcer.stop()

@app.get("/")
def root():
    return {
        "service": "PiMobile Agent",
        "status": "online",
        "version": "1.0.0",
        "model": metrics_collector._pi_model
    }

@app.get("/api/health")
def health_check():
    return {"status": "ok", "timestamp": metrics_collector.collect()["timestamp"]}

@app.get("/api/system/metrics", dependencies=[Depends(verify_token)])
def get_metrics():
    return metrics_collector.collect()

@app.get("/api/system/processes", dependencies=[Depends(verify_token)])
def get_processes(limit: int = 15):
    return {"processes": metrics_collector.get_top_processes(limit=limit)}

@app.post("/api/system/power/{action}", dependencies=[Depends(verify_token)])
def power_action(action: str):
    if action not in ["reboot", "shutdown"]:
        raise HTTPException(status_code=400, detail="Action must be 'reboot' or 'shutdown'")

    cmd = ["sudo", "reboot"] if action == "reboot" else ["sudo", "poweroff"]
    try:
        import subprocess
        subprocess.Popen(cmd)
        return {"success": True, "message": f"System {action} initiated"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/desktop/status", dependencies=[Depends(verify_token)])
def desktop_status():
    return desktop_manager.get_status()

@app.post("/api/desktop/start", dependencies=[Depends(verify_token)])
def start_desktop():
    return desktop_manager.start_desktop_service()

# Real-Time Telemetry WebSocket
@app.websocket("/ws/metrics")
async def websocket_metrics(websocket: WebSocket, token: Optional[str] = None):
    # Accept token either via query param or headers
    auth_header = websocket.headers.get("authorization")
    client_token = token
    if not client_token and auth_header and auth_header.startswith("Bearer "):
        client_token = auth_header.split(" ")[1]

    if client_token != AUTH_TOKEN:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await websocket.accept()
    try:
        while True:
            data = metrics_collector.collect()
            await websocket.send_json(data)
            await asyncio.sleep(1.0)
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.warning(f"Metrics WebSocket exception: {e}")

# VNC WebSocket Proxy Endpoint (Streams RFB raw bytes between client and local VNC server)
@app.websocket("/ws/vnc")
async def websocket_vnc_bridge(websocket: WebSocket, token: Optional[str] = None):
    if token != AUTH_TOKEN:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await websocket.accept(subprotocol="binary")
    try:
        # Open TCP connection to local VNC server
        reader, writer = await asyncio.open_connection("127.0.0.1", VNC_PORT)
    except Exception as e:
        logger.error(f"Cannot connect to VNC server on port {VNC_PORT}: {e}")
        await websocket.close(code=status.WS_1011_INTERNAL_ERROR)
        return

    async def forward_ws_to_vnc():
        try:
            while True:
                msg = await websocket.receive_bytes()
                writer.write(msg)
                await writer.drain()
        except Exception:
            pass
        finally:
            writer.close()

    async def forward_vnc_to_ws():
        try:
            while True:
                data = await reader.read(4096)
                if not data:
                    break
                await websocket.send_bytes(data)
        except Exception:
            pass

    try:
        await asyncio.gather(forward_ws_to_vnc(), forward_vnc_to_ws())
    finally:
        try:
            writer.close()
            await writer.wait_closed()
        except Exception:
            pass

# Embedded noVNC HTML5 Web Viewer for Mobile App WebView
@app.get("/desktop", response_class=HTMLResponse)
def embedded_desktop_ui(token: Optional[str] = None):
    """
    Delivers a responsive, touch-optimized HTML5 VNC viewer that runs
    inside the Flutter WebView or any mobile browser.
    """
    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Raspberry Pi Remote Desktop</title>
    <style>
        body, html {{
            margin: 0; padding: 0; width: 100%; height: 100%;
            background-color: #121212; color: #fff;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            overflow: hidden;
        }}
        #toolbar {{
            display: flex; align-items: center; justify-content: space-between;
            padding: 8px 12px; background: #1e1e1e; border-bottom: 1px solid #333;
        }}
        .btn {{
            background: #2563eb; color: #fff; border: none; padding: 6px 12px;
            border-radius: 4px; font-weight: 500; cursor: pointer;
        }}
        #screen-container {{
            width: 100%; height: calc(100% - 45px);
            display: flex; align-items: center; justify-content: center;
        }}
        #rfb-canvas {{
            max-width: 100%; max-height: 100%;
            box-shadow: 0 4px 12px rgba(0,0,0,0.5);
        }}
        #status-msg {{
            position: absolute; bottom: 10px; left: 10px;
            background: rgba(0,0,0,0.7); padding: 4px 8px; border-radius: 4px; font-size: 12px;
        }}
    </style>
    <!-- Lightweight RFB client script -->
    <script src="https://cdn.jsdelivr.net/npm/@novnc/novnc@1.4.0/core/rfb.js" type="module"></script>
</head>
<body>
    <div id="toolbar">
        <div><strong>Raspberry Pi OS Desktop</strong></div>
        <div>
            <button class="btn" id="ctrl-alt-del">Ctrl+Alt+Del</button>
            <button class="btn" id="reconnect">Reconnect</button>
        </div>
    </div>
    <div id="screen-container">
        <div id="noVNC_canvas"></div>
    </div>
    <div id="status-msg">Connecting to desktop...</div>

    <script type="module">
        import RFB from 'https://cdn.jsdelivr.net/npm/@novnc/novnc@1.4.0/core/rfb.js';

        const token = "{token or ''}" || new URLSearchParams(window.location.search).get("token");
        const statusEl = document.getElementById("status-msg");
        let rfb = null;

        function connect() {{
            statusEl.textContent = "Connecting to WayVNC/VNC bridge...";
            const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
            const wsUrl = `${{protocol}}//${{window.location.host}}/ws/vnc?token=${{encodeURIComponent(token)}}`;

            rfb = new RFB(document.getElementById('noVNC_canvas'), wsUrl, {{
                credentials: {{ password: '' }}
            }});

            rfb.scaleViewport = true;
            rfb.resizeSession = true;

            rfb.addEventListener("connect", () => {{
                statusEl.textContent = "Connected (Online)";
                statusEl.style.color = "#4ade80";
            }});

            rfb.addEventListener("disconnect", (e) => {{
                statusEl.textContent = "Disconnected: " + (e.detail.clean ? "Normal" : "Server unreachable");
                statusEl.style.color = "#f87171";
            }});
        }}

        document.getElementById("reconnect").onclick = () => {{
            if (rfb) rfb.disconnect();
            connect();
        }};
        document.getElementById("ctrl-alt-del").onclick = () => {{
            if (rfb) rfb.sendCtrlAltDel();
        }};

        connect();
    </script>
</body>
</html>
"""
    return HTMLResponse(content=html_content)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=AGENT_PORT, log_level="info")
