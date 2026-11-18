#!/usr/bin/env bash
# ==============================================================================
# PiMobile Agent - Automated Installation Script for Raspberry Pi OS
# ==============================================================================
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}   PiMobile Agent Installer for Raspberry Pi OS        ${NC}"
echo -e "${CYAN}======================================================${NC}"

# Check for sudo / root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run this script with sudo: sudo ./install.sh${NC}"
    exit 1
fi

CURRENT_USER="${SUDO_USER:-$(whoami)}"
INSTALL_DIR="/opt/pi-agent"

echo -e "\n${YELLOW}[1/5] Updating package lists & installing system dependencies...${NC}"
apt-get update -qq
apt-get install -y -qq python3 python3-pip python3-venv curl libglib2.0-dev avahi-daemon

# Ensure avahi-daemon is running for mDNS local discovery
systemctl enable --now avahi-daemon

echo -e "\n${YELLOW}[2/5] Setting up installation directory at ${INSTALL_DIR}...${NC}"
mkdir -p "${INSTALL_DIR}"
cp main.py metrics.py discovery.py desktop.py requirements.txt "${INSTALL_DIR}/"

echo -e "\n${YELLOW}[3/5] Creating Python virtual environment & installing modules...${NC}"
python3 -m venv "${INSTALL_DIR}/venv"
"${INSTALL_DIR}/venv/bin/pip" install --upgrade pip -q
"${INSTALL_DIR}/venv/bin/pip" install -r "${INSTALL_DIR}/requirements.txt" -q

echo -e "\n${YELLOW}[4/5] Checking Tailscale mesh networking...${NC}"
if command -v tailscale >/dev/null 2>&1; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not logged in")
    echo -e "${GREEN}✓ Tailscale is installed! IP: ${TAILSCALE_IP}${NC}"
else
    echo -e "${YELLOW}Tailscale is not installed.${NC}"
    read -p "Would you like to install Tailscale now for secure internet access? [y/N]: " -r INSTALL_TS || true
    if [[ "${INSTALL_TS:-n}" =~ ^[Yy]$ ]]; then
        curl -fsSL https://tailscale.com/install.sh | sh
        echo -e "${GREEN}✓ Tailscale installed. Run 'sudo tailscale up' after setup to authenticate.${NC}"
    fi
fi

echo -e "\n${YELLOW}[5/5] Configuring systemd service...${NC}"
sed "s|User=%I|User=${CURRENT_USER}|g" pi-agent.service > /etc/systemd/system/pi-agent.service
chown -R "${CURRENT_USER}:${CURRENT_USER}" "${INSTALL_DIR}"

systemctl daemon-reload
systemctl enable --now pi-agent.service

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}✓ PiMobile Agent successfully installed and running!  ${NC}"
echo -e "${GREEN}======================================================${NC}"

# Read generated config token
CONFIG_PATH="/home/${CURRENT_USER}/.config/pi-agent/config.json"
sleep 1
if [ -f "${CONFIG_PATH}" ]; then
    AUTH_TOKEN=$(grep -o '"auth_token": "[^"]*' "${CONFIG_PATH}" | grep -o '[^"]*$')
    echo -e "Your Authentication Token: ${CYAN}${AUTH_TOKEN}${NC}"
    echo -e "Keep this token safe! You will enter it in your mobile app."
fi

PRIMARY_IP=$(hostname -I | awk '{print $1}')
echo -e "\nLocal Network URL:    ${CYAN}http://${PRIMARY_IP}:8765${NC}"
if command -v tailscale >/dev/null 2>&1; then
    TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
    if [ -n "$TS_IP" ]; then
        echo -e "Tailscale Remote URL: ${CYAN}http://${TS_IP}:8765${NC}"
    fi
fi
echo -e "Embedded Desktop UI:  ${CYAN}http://${PRIMARY_IP}:8765/desktop${NC}"
echo -e "Check service logs:   ${YELLOW}sudo journalctl -u pi-agent -f${NC}\n"
