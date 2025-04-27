#!/bin/bash

clear
echo "          _   _                       ____   _____  "
echo "     /\\  | | | |                     / __ \\ / ____| "
echo "    /  \\ | |_| |__   ___ _ __   __ _| |  | | (___   "
echo "   / /\\ \\| __| '_ \\ / _ \\ '_ \\ / _\` | |  | |\\___ \\  "
echo "  / ____ \\ |_| | | |  __/ | | | (_| | |__| |____) | "
echo " /_/    \\_\\__|_| |_|\\___|_| |_|\\__,_|\\____/|_____/  "

# Function for simple progress bar
progress() {
    local pid=$!
    local delay=0.2
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Try using sudo."
  exit 1
fi

echo "Starting AthenaOS setup..."

# Set hostname
( hostnamectl set-hostname AthenaOS ) &> /dev/null & progress

# Update /etc/hosts
( sed -i '/127.0.1.1/d' /etc/hosts && echo "127.0.1.1   AthenaOS" >> /etc/hosts ) &> /dev/null & progress

# Update and upgrade system
( apt update -qq && apt upgrade -y -qq ) & progress

# Create user 'athenaos' with no password
if id "athenaos" &> /dev/null; then
  echo "User 'athenaos' already exists."
else
  ( useradd -m -s /bin/bash athenaos && passwd -d athenaos ) &> /dev/null & progress
fi

# Install minimal Desktop Environment
( apt install --no-install-recommends openbox sudo git -y -qq && \
  apt install xinit xserver-xorg x11-xserver-utils plymouth plymouth-themes python3-venv python3-pip -y -qq && \
  apt install --no-install-recommends chromium feh -y -qq && \
  apt install -y network-manager wpasupplicant firmware-linux-nonfree wireless-tools iw rfkill -qq ) & progress

# Setup autologin
( mkdir -p /etc/systemd/system/getty@tty1.service.d && \
  tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin athenaos --noclear %I \$TERM
EOF
) &> /dev/null & progress

# Set Openbox autostart
( sudo -u athenaos bash -c 'echo "[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && exec startx" >> ~/.bash_profile' && \
  sudo -u athenaos bash -c 'echo "bash /home/athenaos/motd.sh" >> ~/.bashrc' && \
  mkdir -p /home/athenaos/.config/openbox && \
  cp -rf startup.sh /home/athenaos/.config/openbox/autostart && \
  chmod +x /home/athenaos/.config/openbox/autostart && \
  cp wallpaper.png /home/athenaos/ && \
  cp motd.sh /home/athenaos/ && chmod +x /home/athenaos/motd.sh && \
  chown -R athenaos:athenaos /home/athenaos/
) &> /dev/null & progress

# Clone AthenaOS_UI
( cd /home/athenaos/ && git clone https://github.com/quietvw/AthenaOS_UI && \
  cd AthenaOS_UI && pip3 install -r requirements.txt --break-system-packages && \
  chown -R athenaos:athenaos /home/athenaos/AthenaOS_UI
) &> /dev/null & progress

# Setup services
( cp athenaos.service /etc/systemd/system/athenaos.service && \
  systemctl enable athenaos && \
  systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
) &> /dev/null & progress

# Backup configs
( cp /etc/os-release /etc/os-release.bak && \
  cp /etc/lsb-release /etc/lsb-release.bak || echo "No /etc/lsb-release found." && \
  cp /etc/default/grub /etc/default/grub.bak
) &> /dev/null & progress

# Update OS info
( tee /etc/os-release > /dev/null <<EOL
PRETTY_NAME="AthenaOS (Bravo)"
NAME="AthenaOS"
VERSION_ID="1.0"
VERSION="1.0 (Bravo)"
ID=athenaos
HOME_URL="https://www.adaclare.com"
SUPPORT_URL="https://www.adaclare.com"
BUG_REPORT_URL="https://www.adaclare.com"
EOL
) &> /dev/null & progress

( tee /etc/lsb-release > /dev/null <<EOL
DISTRIB_ID=AthenaOS
DISTRIB_RELEASE=1.0
DISTRIB_CODENAME=bravo
DISTRIB_DESCRIPTION="AthenaOS 1.0 (Bravo)"
EOL
) &> /dev/null & progress

# Update GRUB
( sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="AthenaOS"/' /etc/default/grub || echo 'GRUB_DISTRIBUTOR="AthenaOS"' >> /etc/default/grub && \
  update-grub
) &> /dev/null & progress

# Setup login message
( cp /etc/issue /etc/issue.bak && cp /etc/motd /etc/motd.bak && \
  cp /etc/issue.net /etc/issue.net.bak || echo "No /etc/issue.net found." && \
  echo "                       AthenaOS - Bravo" | tee /etc/issue /etc/motd /etc/issue.net > /dev/null && \
  echo -e "\\n\\l" | tee -a /etc/issue > /dev/null
) &> /dev/null & progress

# Disable dynamic motd
( [ -d "/etc/update-motd.d/" ] && chmod -x /etc/update-motd.d/* ) &> /dev/null & progress

# Install Plymouth theme
( THEME_NAME="athenaos"
  THEME_DIR="/usr/share/plymouth/themes/$THEME_NAME"
  mkdir -p "$THEME_DIR"
  cp -r "$THEME_NAME" "$THEME_DIR" && \
  plymouth-set-default-theme -R "$THEME_NAME"
) &> /dev/null & progress

# Fix GRUB splash
( sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*/& splash/' /etc/default/grub && update-grub && update-initramfs -u ) &> /dev/null & progress

echo
echo "AthenaOS setup complete! Please reboot."
reboot
