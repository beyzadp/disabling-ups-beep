#!/bin/bash

# Check if the user is running the script as root
if [[ $(id -u) -ne 0 ]]
then
    echo "This script must be run as root. Try again with 'sudo'."
    exit 1
fi

# Check system distro
distro=$(lsb_release -is)

# Select package manager based on system distribution

if [ "$distro" == "Debian" ] || [ "$distro" == "Ubuntu" ] || [ "$distro" == "Raspbian" ] || [ "$distro" == "Kali" ]; then
  package_manager=apt
elif [ "$distro" == "Fedora" ] || [ "$distro" == "CentOS" ] || [ "$distro" == "RedHat" ]; then
  package_manager=dnf
elif [ "$distro" == "Manjaro" ] || [ "$distro" == "Arch" ]; then
  package_manager=pacman
else
  echo "Sorry, I don't know how to install packages on your system."
  exit 1
fi

# Update with package manager
if [ "$package_manager" == "apt" ] || [ "$package_manager" == "dnf" ]; then
  $package_manager update
elif [ "$package_manager" == "pacman" ]; then
  $package_manager -Sy
fi

# install nut package
if [ "$package_manager" == "pacman" ]; then
  $package_manager -S nut
elif [ "$package_manager" == "dnf" ]; then
  $package_manager install nut
fi


if [ "$package_manager" == "pacman" ] || [ "$package_manager" == "dnf" ]; then

  # Get path to /etc/nut/ups.conf
  config_file="/etc/nut/ups.conf"

  # Open the file and write in
  echo "[eaton]" >> "$config_file" >/dev/null 2>&1
  echo "driver = usbhid-ups" >> "$config_file" >/dev/null 2>&1
  echo "port = auto" >> "$config_file" >/dev/null 2>&1
  echo "desc = \"Eaton 5E\"" >> "$config_file" >/dev/null 2>&1

  sudo upsdrvctl start >/dev/null 2>&1

  sed -i '/MODE/c\MODE=standalone' /etc/nut/nut.conf >/dev/null 2>&1
  sed -i '/#LISTEN 127.0.0.1 3493/c\LISTEN 127.0.0.1 3493' /etc/nut/nut.conf >/dev/null 2>&1

  sudo service nut-server restart >/dev/null 2>&1

  read -p "Please set the admin password: " admin_pass
  
  upsd_users_file="/etc/nut/upsd.users" >/dev/null 2>&1

  echo "[admin]" > $upsd_users_file >/dev/null 2>&1
  echo "password = $admin_pass" >> $upsd_users_file >/dev/null 2>&1
  echo "actions = SET" >> $upsd_users_file >/dev/null 2>&1
  echo "instcmds = ALL" >> $upsd_users_file >/dev/null 2>&1

  sudo upsd -c reload >/dev/null 2>&1

  echo "admin\n$admin_pass" | upscmd eaton beeper.disable >/dev/null 2>&1

  sonuc=$(upsc eaton ups.beeper.status >/dev/null 2>&1)

  if [ "$sonuc" == "disabled" ]; then
    echo "UPS beep disabled."
    exit 1
  fi

fi


# Check if the upsd.conf file exists
if [[ ! -f /etc/ups/upsd.conf ]]
then
    echo "Error: UPS daemon configuration file not found at /etc/ups/upsd.conf"
    exit 1
fi

# Comment out the BEEPCMD line in the upsd.conf file
sed -i 's/^BEEPCMD/#BEEPCMD/' /etc/ups/upsd.conf

# Restart the UPS daemon
systemctl restart upsd >/dev/null 2>&1

echo "UPS beep disabled."
