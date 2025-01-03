# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# Co-Author: MickLesk
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

variables() {
  NSAPP=$(echo ${APP,,} | tr -d ' ') # This function sets the NSAPP variable by converting the value of the APP variable to lowercase and removing any spaces.
  var_install="${NSAPP}-install"     # sets the var_install variable by appending "-install" to the value of NSAPP.
  INTEGER='^[0-9]+([.][0-9]+)?$'     # it defines the INTEGER regular expression pattern.
  PVEHOST_NAME=$(hostname) # gets the Proxmox Hostname and sets it to Uppercase
}

# This function sets various color variables using ANSI escape codes for formatting text in the terminal.
color() {
  # Colors
  YW=$(echo "\033[33m")
  YWB=$(echo "\033[93m")
  BL=$(echo "\033[36m")
  RD=$(echo "\033[01;31m")
  BGN=$(echo "\033[4;92m")
  GN=$(echo "\033[1;92m")
  DGN=$(echo "\033[32m")

  # Formatting
  CL=$(echo "\033[m")
  UL=$(echo "\033[4m")
  BOLD=$(echo "\033[1m")
  BFR="\\r\\033[K"
  HOLD=" "
  TAB="  "

  # Icons
  CM="${TAB}✔️${TAB}${CL}"
  CROSS="${TAB}✖️${TAB}${CL}"
  INFO="${TAB}💡${TAB}${CL}"
  OS="${TAB}🖥️${TAB}${CL}"
  OSVERSION="${TAB}🌟${TAB}${CL}"
  CONTAINERTYPE="${TAB}📦${TAB}${CL}" 
  DISKSIZE="${TAB}💾${TAB}${CL}"
  CPUCORE="${TAB}🧠${TAB}${CL}"
  RAMSIZE="${TAB}🛠️${TAB}${CL}"
  SEARCH="${TAB}🔍${TAB}${CL}"
  VERIFYPW="${TAB}🔐${TAB}${CL}"
  CONTAINERID="${TAB}🆔${TAB}${CL}"
  HOSTNAME="${TAB}🏠${TAB}${CL}"
  BRIDGE="${TAB}🌉${TAB}${CL}"
  NETWORK="${TAB}📡${TAB}${CL}"
  GATEWAY="${TAB}🌐${TAB}${CL}"
  DISABLEIPV6="${TAB}🚫${TAB}${CL}"
  DEFAULT="${TAB}⚙️${TAB}${CL}"
  MACADDRESS="${TAB}🔗${TAB}${CL}"
  VLANTAG="${TAB}🏷️${TAB}${CL}"
  ROOTSSH="${TAB}🔑${TAB}${CL}"
  CREATING="${TAB}🚀${TAB}${CL}"
  ADVANCED="${TAB}🧩${TAB}${CL}"
}

# This function enables error handling in the script by setting options and defining a trap for the ERR signal.
catch_errors() {
  set -Eeuo pipefail
  trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
}

# This function is called when an error occurs. It receives the exit code, line number, and command that caused the error, and displays an error message.
error_handler() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
  printf "\e[?25h"
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
}

# This function displays a spinner.
spinner() {
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local spin_i=0
  local interval=0.1
  printf "\e[?25l"

  local color="${YWB}"

  while true; do
    printf "\r ${color}%s${CL}" "${frames[spin_i]}"
    spin_i=$(( (spin_i + 1) % ${#frames[@]} ))
    sleep "$interval"
  done
}

# This function displays an informational message with a yellow color.
msg_info() {
  local msg="$1"
  echo -ne "${TAB}${YW}${HOLD}${msg}${HOLD}"
  spinner &
  SPINNER_PID=$!
}

# This function displays a success message with a green color.
msg_ok() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
  printf "\e[?25h"
  local msg="$1"
  echo -e "${BFR}${CM}${GN}${msg}${CL}"
}

# This function displays a error message with a red color.
msg_error() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
  printf "\e[?25h"
  local msg="$1"
  echo -e "${BFR}${CROSS}${RD}${msg}${CL}"
}

# Check if the shell is using bash
shell_check() {
  if [[ "$(basename "$SHELL")" != "bash" ]]; then
    clear
    msg_error "Your default shell is currently not set to Bash. To use these scripts, please switch to the Bash shell."
    echo -e "\nExiting..."
    sleep 2
    exit
  fi
}

# Run as root only
root_check() {
  if [[ "$(id -u)" -ne 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
    clear
    msg_error "Please run this script as root."
    echo -e "\nExiting..."
    sleep 2
    exit
  fi
}

# This function checks the version of Proxmox Virtual Environment (PVE) and exits if the version is not supported.
pve_check() {
  if ! pveversion | grep -Eq "pve-manager/8.[1-3]"; then
    msg_error "${CROSS}${RD}This version of Proxmox Virtual Environment is not supported"
    echo -e "Requires Proxmox Virtual Environment Version 8.1 or later."
    echo -e "Exiting..."
    sleep 2
    exit
fi
}

# This function checks the system architecture and exits if it's not "amd64".
arch_check() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    echo -e "\n ${INFO}${YWB}This script will not work with PiMox! \n"
    echo -e "\n ${YWB}Visit https://github.com/asylumexp/Proxmox for ARM64 support. \n"
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}

# Function to get the current IP address based on the distribution
get_current_ip() {
  if [ -f /etc/os-release ]; then
    # Check for Debian/Ubuntu (uses hostname -I)
    if grep -qE 'ID=debian|ID=ubuntu' /etc/os-release; then
      CURRENT_IP=$(hostname -I | awk '{print $1}')
    # Check for Alpine (uses ip command)
    elif grep -q 'ID=alpine' /etc/os-release; then
      CURRENT_IP=$(ip -4 addr show eth0 | awk '/inet / {print $2}' | cut -d/ -f1 | head -n 1)
    else
      CURRENT_IP="Unknown"
    fi
  fi
  echo "$CURRENT_IP"
}

# Function to update the IP address in the MOTD file
update_motd_ip() {
  MOTD_FILE="/etc/motd"
  
  if [ -f "$MOTD_FILE" ]; then
    # Remove existing IP Address lines to prevent duplication
    sed -i '/IP Address:/d' "$MOTD_FILE"
    
    IP=$(get_current_ip)
    # Add the new IP address
    echo -e "${TAB}${NETWORK}${YW} IP Address: ${GN}${IP}${CL}" >> "$MOTD_FILE"
  fi
}

# This function sets the APP-Name into an ASCII Header in Slant, figlet needed on proxmox main node.
header_info() {
  # Helper function: Install FIGlet and download fonts
  install_figlet() {
    echo -e "${INFO}${BOLD}${DGN}Installing FIGlet...${CL}"

    temp_dir=$(mktemp -d)
    curl -sL https://github.com/community-scripts/ProxmoxVE/raw/refs/heads/main/misc/figlet.tar.xz -o "$temp_dir/figlet.tar.xz"
    mkdir -p /tmp/figlet
    tar -xf "$temp_dir/figlet.tar.xz" -C /tmp/figlet --strip-components=1
    cd /tmp/figlet
    make >/dev/null

    if [ -f "figlet" ]; then
      chmod +x figlet
      mv figlet /usr/local/bin/
      mkdir -p /usr/local/share/figlet
      cp -r /tmp/figlet/fonts/*.flf /usr/local/share/figlet/
      echo -e "${CM}${BOLD}${DGN}FIGlet successfully installed.${CL}"
    else
      echo -e "${ERR}${BOLD}${RED}Failed to install FIGlet.${CL}"
      return 1
    fi
    rm -rf "$temp_dir"
  }

  # Check if figlet and the slant font are available
  if ! figlet -f slant "Test" &>/dev/null; then
    echo -e "${INFO}${BOLD}${DGN}FIGlet or the slant font is missing. Installing...${CL}"

    if [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
      # Debian/Ubuntu-based systems
      apt-get update -y &>/dev/null
      apt-get install -y wget build-essential &>/dev/null
      install_figlet

    elif [ -f /etc/alpine-release ]; then
      # Alpine-based systems
      apk add --no-cache tar xz build-base wget &>/dev/null
      export TERM=xterm
      install_figlet

    else
      echo -e "${ERR}${BOLD}${RED}Unsupported operating system.${CL}"
      return 1
    fi

    # Ensure the slant font is available
    if [ ! -f "/usr/share/figlet/slant.flf" ]; then
      echo -e "${INFO}${BOLD}${DGN}Downloading slant font...${CL}"
      wget -qO /usr/share/figlet/slant.flf "http://www.figlet.org/fonts/slant.flf"
    fi
  fi

  # Display ASCII header
  term_width=$(tput cols 2>/dev/null || echo 120)
  ascii_art=$(figlet -f slant -w "$term_width" "$APP")
  clear
  echo "$ascii_art"
}

# This function checks if the script is running through SSH and prompts the user to confirm if they want to proceed or exit.
ssh_check() {
  if [ -n "${SSH_CLIENT:+x}" ]; then
    if whiptail --backtitle "Proxmox VE Helper Scripts" --defaultno --title "SSH DETECTED" --yesno "It's advisable to utilize the Proxmox shell rather than SSH, as there may be potential complications with variable retrieval. Proceed using SSH?" 10 72; then
      whiptail --backtitle "Proxmox VE Helper Scripts" --msgbox --title "Proceed using SSH" "You've chosen to proceed using SSH. If any issues arise, please run the script in the Proxmox shell before creating a repository issue." 10 72
    else
      clear
      echo "Exiting due to SSH usage. Please consider using the Proxmox shell."
      exit
    fi
  fi
}

base_settings() {
  # Default Settings
  CT_TYPE="1"
  DISK_SIZE="4"
  CORE_COUNT="1"
  RAM_SIZE="1024"
  VERBOSE="${1:-no}"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  TAGS="community-script;"
  
  # Override default settings with variables from ct script
  CT_TYPE=${var_unprivileged:-$CT_TYPE}
  DISK_SIZE=${var_disk:-$DISK_SIZE}
  CORE_COUNT=${var_cpu:-$CORE_COUNT}
  RAM_SIZE=${var_ram:-$RAM_SIZE}
  VERB=${var_verbose:-$VERBOSE}
  TAGS="${TAGS}${var_tags:-}"
  
  # Since these 2 are only defined outside of default_settings function, we add a temporary fallback. TODO: To align everything, we should add these as constant variables (e.g. OSTYPE and OSVERSION), but that would currently require updating the default_settings function for all existing scripts
  if [ -z "$var_os" ]; then
    var_os="debian"
  fi
  if [ -z "$var_version" ]; then
    var_version="12"
  fi
}

# This function displays the default values for various settings.
echo_default() {
  # Convert CT_TYPE to description
  CT_TYPE_DESC="Unprivileged"
  if [ "$CT_TYPE" -eq 0 ]; then
    CT_TYPE_DESC="Privileged"
  fi

  # Output the selected values with icons
  echo -e "${OS}${BOLD}${DGN}Operating System: ${BGN}$var_os${CL}"
  echo -e "${OSVERSION}${BOLD}${DGN}Version: ${BGN}$var_version${CL}"
  echo -e "${CONTAINERTYPE}${BOLD}${DGN}Container Type: ${BGN}$CT_TYPE_DESC${CL}"
  echo -e "${DISKSIZE}${BOLD}${DGN}Disk Size: ${BGN}${DISK_SIZE}GB${CL}"
  echo -e "${CPUCORE}${BOLD}${DGN}CPU Cores: ${BGN}${CORE_COUNT}${CL}"
  echo -e "${RAMSIZE}${BOLD}${DGN}RAM Size: ${BGN}${RAM_SIZE}MB${CL}"
  echo -e "${CONTAINERID}${BOLD}${DGN}Container ID: ${BGN}${CT_ID}${CL}"
  if [ "$VERB" == "yes" ]; then
    echo -e "${SEARCH}${BOLD}${DGN}Verbose Mode: ${BGN}Enabled${CL}"
  fi
  echo -e "${CREATING}${BOLD}${BL}Creating a ${APP} LXC using the above default settings${CL}"
  echo -e "  "
}

# This function is called when the user decides to exit the script. It clears the screen and displays an exit message.
exit_script() {
  clear
  echo -e "\n${CROSS}${RD}User exited script${CL}\n"
  exit
}

# This function allows the user to configure advanced settings for the script.
advanced_settings() {
  whiptail --backtitle "Proxmox VE Helper Scripts" --msgbox --title "Here is an instructional tip:" "To make a selection, use the Spacebar." 8 58
  whiptail --backtitle "Proxmox VE Helper Scripts" --msgbox --title "Default distribution for $APP" "${var_os} ${var_version} \n \nIf the default Linux distribution is not adhered to, script support will be discontinued. \n" 10 58
  if [ "$var_os" != "alpine" ]; then
    var_os=""
    while [ -z "$var_os" ]; do
      if var_os=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "DISTRIBUTION" --radiolist "Choose Distribution:" 10 58 2 \
        "debian" "" OFF \
        "ubuntu" "" OFF \
        3>&1 1>&2 2>&3); then
        if [ -n "$var_os" ]; then
          echo -e "${OS}${BOLD}${DGN}Operating System: ${BGN}$var_os${CL}"
        fi
      else
        exit_script
      fi
    done
  fi

  if [ "$var_os" == "debian" ]; then
    var_version=""
    while [ -z "$var_version" ]; do
      if var_version=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "DEBIAN VERSION" --radiolist "Choose Version" 10 58 2 \
        "11" "Bullseye" OFF \
        "12" "Bookworm" OFF \
        3>&1 1>&2 2>&3); then
        if [ -n "$var_version" ]; then
          echo -e "${OSVERSION}${BOLD}${DGN}Version: ${BGN}$var_version${CL}"
        fi
      else
        exit_script
      fi
    done
  fi

  if [ "$var_os" == "ubuntu" ]; then
    var_version=""
    while [ -z "$var_version" ]; do
      if var_version=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "UBUNTU VERSION" --radiolist "Choose Version" 10 58 4 \
        "20.04" "Focal" OFF \
        "22.04" "Jammy" OFF \
        "24.04" "Noble" OFF \
        "24.10" "Oracular" OFF \
      3>&1 1>&2 2>&3); then
        if [ -n "$var_version" ]; then
          echo -e "${OSVERSION}${BOLD}${DGN}Version: ${BGN}$var_version${CL}"
        fi
      else
        exit_script
      fi
    done
  fi
  # Setting Default Tag for Advanced Settings
  TAGS="community-script;${var_tags:-}"

  CT_TYPE=""
  while [ -z "$CT_TYPE" ]; do
    if CT_TYPE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "CONTAINER TYPE" --radiolist "Choose Type" 10 58 2 \
      "1" "Unprivileged" OFF \
      "0" "Privileged" OFF \
      3>&1 1>&2 2>&3); then
      if [ -n "$CT_TYPE" ]; then
        CT_TYPE_DESC="Unprivileged"
        if [ "$CT_TYPE" -eq 0 ]; then
          CT_TYPE_DESC="Privileged"
        fi
        echo -e "${CONTAINERTYPE}${BOLD}${DGN}Container Type: ${BGN}$CT_TYPE_DESC${CL}"
      fi
    else
      exit_script
    fi
  done

  while true; do
    if PW1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --passwordbox "\nSet Root Password (needed for root ssh access)" 9 58 --title "PASSWORD (leave blank for automatic login)" 3>&1 1>&2 2>&3); then
      if [[ ! -z "$PW1" ]]; then
        if [[ "$PW1" == *" "* ]]; then
          whiptail --msgbox "Password cannot contain spaces. Please try again." 8 58
        elif [ ${#PW1} -lt 5 ]; then
          whiptail --msgbox "Password must be at least 5 characters long. Please try again." 8 58
        else
          if PW2=$(whiptail --backtitle "Proxmox VE Helper Scripts" --passwordbox "\nVerify Root Password" 9 58 --title "PASSWORD VERIFICATION" 3>&1 1>&2 2>&3); then
            if [[ "$PW1" == "$PW2" ]]; then
              PW="-password $PW1"
              echo -e "${VERIFYPW}${BOLD}${DGN}Root Password: ${BGN}********${CL}"
              break
            else
              whiptail --msgbox "Passwords do not match. Please try again." 8 58
            fi
          else
            exit_script
          fi
        fi
      else
        PW1="Automatic Login"
        PW=""
        echo -e "${VERIFYPW}${BOLD}${DGN}Root Password: ${BGN}$PW1${CL}"
        break
      fi
    else
      exit_script
    fi
  done


  if CT_ID=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Container ID" 8 58 $NEXTID --title "CONTAINER ID" 3>&1 1>&2 2>&3); then
    if [ -z "$CT_ID" ]; then
      CT_ID="$NEXTID"
      echo -e "${CONTAINERID}${BOLD}${DGN}Container ID: ${BGN}$CT_ID${CL}"
    else
      echo -e "${CONTAINERID}${BOLD}${DGN}Container ID: ${BGN}$CT_ID${CL}"
    fi
  else
    exit
  fi

  if CT_NAME=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Hostname" 8 58 $NSAPP --title "HOSTNAME" 3>&1 1>&2 2>&3); then
    if [ -z "$CT_NAME" ]; then
      HN="$NSAPP"
    else
      HN=$(echo ${CT_NAME,,} | tr -d ' ')
    fi
    echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}$HN${CL}"
  else
    exit_script
  fi

  if DISK_SIZE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Disk Size in GB" 8 58 $var_disk --title "DISK SIZE" 3>&1 1>&2 2>&3); then
    if [ -z "$DISK_SIZE" ]; then
      DISK_SIZE="$var_disk"
      echo -e "${DISKSIZE}${DGN}Disk Size: ${BGN}$DISK_SIZE${CL}"
    else
      if ! [[ $DISK_SIZE =~ $INTEGER ]]; then
        echo -e "{INFO}${HOLD}${RD} DISK SIZE MUST BE AN INTEGER NUMBER!${CL}"
        advanced_settings
      fi
      echo -e "${DISKSIZE}${BOLD}${DGN}Disk Size: ${BGN}$DISK_SIZE${CL}"
    fi
  else
    exit_script
  fi

  if CORE_COUNT=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Allocate CPU Cores" 8 58 $var_cpu --title "CORE COUNT" 3>&1 1>&2 2>&3); then
    if [ -z "$CORE_COUNT" ]; then
      CORE_COUNT="$var_cpu"
      echo -e "${CPUCORE}${BOLD}${DGN}CPU Cores: ${BGN}$CORE_COUNT${CL}"
    else
      echo -e "${CPUCORE}${BOLD}${DGN}CPU Cores: ${BGN}$CORE_COUNT${CL}"
    fi
  else
    exit_script
  fi

  if RAM_SIZE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Allocate RAM in MiB" 8 58 $var_ram --title "RAM" 3>&1 1>&2 2>&3); then
    if [ -z "$RAM_SIZE" ]; then
      RAM_SIZE="$var_ram"
      echo -e "${RAMSIZE}${BOLD}${DGN}RAM Size: ${BGN}$RAM_SIZE${CL}"
    else
      echo -e "${RAMSIZE}${BOLD}${DGN}RAM Size: ${BGN}$RAM_SIZE${CL}"
    fi
  else
    exit_script
  fi

  if BRG=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a Bridge" 8 58 vmbr0 --title "BRIDGE" 3>&1 1>&2 2>&3); then
    if [ -z "$BRG" ]; then
      BRG="vmbr0"
      echo -e "${BRIDGE}${BOLD}${DGN}Bridge: ${BGN}$BRG${CL}"
    else
      echo -e "${BRIDGE}${BOLD}${DGN}Bridge: ${BGN}$BRG${CL}"
    fi
  else
    exit_script
  fi

  while true; do
    NET=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a Static IPv4 CIDR Address (/24)" 8 58 dhcp --title "IP ADDRESS" 3>&1 1>&2 2>&3)
    exit_status=$?
    if [ $exit_status -eq 0 ]; then
      if [ "$NET" = "dhcp" ]; then
        echo -e "${NETWORK}${BOLD}${DGN}IP Address: ${BGN}$NET${CL}"
        break
      else
        if [[ "$NET" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]]; then
          echo -e "${NETWORK}${BOLD}${DGN}IP Address: ${BGN}$NET${CL}"
          break
        else
          whiptail --backtitle "Proxmox VE Helper Scripts" --msgbox "$NET is an invalid IPv4 CIDR address. Please enter a valid IPv4 CIDR address or 'dhcp'" 8 58
        fi
      fi
    else
      exit_script
    fi
  done

  if [ "$NET" != "dhcp" ]; then
    while true; do
      GATE1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Enter gateway IP address" 8 58 --title "Gateway IP" 3>&1 1>&2 2>&3)
      if [ -z "$GATE1" ]; then
        whiptail --backtitle "Proxmox VE Helper Scripts" --msgbox "Gateway IP address cannot be empty" 8 58
      elif [[ ! "$GATE1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        whiptail --backtitle "Proxmox VE Helper Scripts" --msgbox "Invalid IP address format" 8 58
      else
        GATE=",gw=$GATE1"
        echo -e "${GATEWAY}${BOLD}${DGN}Gateway IP Address: ${BGN}$GATE1${CL}"
        break
      fi
    done
  else
    GATE=""
    echo -e "${GATEWAY}${BOLD}${DGN}Gateway IP Address: ${BGN}Default${CL}"
  fi

  if [ "$var_os" == "alpine" ]; then
    APT_CACHER=""
    APT_CACHER_IP=""
  else
    if APT_CACHER_IP=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set APT-Cacher IP (leave blank for default)" 8 58 --title "APT-Cacher IP" 3>&1 1>&2 2>&3); then
      APT_CACHER="${APT_CACHER_IP:+yes}"
      echo -e "${NETWORK}${BOLD}${DGN}APT-Cacher IP Address: ${BGN}${APT_CACHER_IP:-Default}${CL}"
    else
      exit_script
    fi
  fi

  if (whiptail --backtitle "Proxmox VE Helper Scripts" --defaultno --title "IPv6" --yesno "Disable IPv6?" 10 58); then
    DISABLEIP6="yes"
  else
    DISABLEIP6="no"
  fi
  echo -e "${DISABLEIPV6}${BOLD}${DGN}Disable IPv6: ${BGN}$DISABLEIP6${CL}"

  if MTU1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Interface MTU Size (leave blank for default)" 8 58 --title "MTU SIZE" 3>&1 1>&2 2>&3); then
    if [ -z $MTU1 ]; then
      MTU1="Default"
      MTU=""
    else
      MTU=",mtu=$MTU1"
    fi
    echo -e "${DEFAULT}${BOLD}${DGN}Interface MTU Size: ${BGN}$MTU1${CL}"
  else
    exit_script
  fi

  if SD=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a DNS Search Domain (leave blank for HOST)" 8 58 --title "DNS Search Domain" 3>&1 1>&2 2>&3); then
    if [ -z $SD ]; then
      SX=Host
      SD=""
    else
      SX=$SD
      SD="-searchdomain=$SD"
    fi
    echo -e "${SEARCH}${BOLD}${DGN}DNS Search Domain: ${BGN}$SX${CL}"
  else
    exit_script
  fi

  if NX=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a DNS Server IP (leave blank for HOST)" 8 58 --title "DNS SERVER IP" 3>&1 1>&2 2>&3); then
    if [ -z $NX ]; then
      NX=Host
      NS=""
    else
      NS="-nameserver=$NX"
    fi
    echo -e "${NETWORK}${BOLD}${DGN}DNS Server IP Address: ${BGN}$NX${CL}"
  else
    exit_script
  fi

  if MAC1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a MAC Address(leave blank for default)" 8 58 --title "MAC ADDRESS" 3>&1 1>&2 2>&3); then
    if [ -z $MAC1 ]; then
      MAC1="Default"
      MAC=""
    else
      MAC=",hwaddr=$MAC1"
      echo -e "${MACADDRESS}${BOLD}${DGN}MAC Address: ${BGN}$MAC1${CL}"
    fi
  else
    exit_script
  fi

  if VLAN1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a Vlan(leave blank for default)" 8 58 --title "VLAN" 3>&1 1>&2 2>&3); then
    if [ -z $VLAN1 ]; then
      VLAN1="Default"
      VLAN=""
    else
      VLAN=",tag=$VLAN1"
    fi
    echo -e "${VLANTAG}${BOLD}${DGN}Vlan: ${BGN}$VLAN1${CL}"
  else
    exit_script
  fi

  if [[ "$PW" == -password* ]]; then
    if (whiptail --backtitle "Proxmox VE Helper Scripts" --defaultno --title "SSH ACCESS" --yesno "Enable Root SSH Access?" 10 58); then
      SSH="yes"
    else
      SSH="no"
    fi
    echo -e "${ROOTSSH}${BOLD}${DGN}Root SSH Access: ${BGN}$SSH${CL}"
  else
    SSH="no"
    echo -e "${ROOTSSH}${BOLD}${DGN}Root SSH Access: ${BGN}$SSH${CL}"
  fi

  if (whiptail --backtitle "Proxmox VE Helper Scripts" --defaultno --title "VERBOSE MODE" --yesno "Enable Verbose Mode?" 10 58); then
    VERB="yes"
  else
    VERB="no"
  fi
  echo -e "${SEARCH}${BOLD}${DGN}Verbose Mode: ${BGN}$VERB${CL}"

  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "ADVANCED SETTINGS COMPLETE" --yesno "Ready to create ${APP} LXC?" 10 58); then
    echo -e "${CREATING}${BOLD}${RD}Creating a ${APP} LXC using the above advanced settings${CL}"
  else
    clear
    header_info
    echo -e "${ADVANCED}${BOLD}${RD}Using Advanced Settings on node $PVEHOST_NAME${CL}"
    advanced_settings
  fi
}

install_script() {
  pve_check
  shell_check
  root_check
  arch_check
  ssh_check

  if systemctl is-active -q ping-instances.service; then
    systemctl -q stop ping-instances.service
  fi
  NEXTID=$(pvesh get /cluster/nextid)
  timezone=$(cat /etc/timezone)
  header_info
  while true; do
    CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "SETTINGS" --menu "Choose an option:" \
      12 50 4 \
      "1" "Default Settings" \
      "2" "Default Settings (with verbose)" \
      "3" "Advanced Settings" \
      "4" "Exit" --nocancel --default-item "1" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
      echo -e "${CROSS}${RD} Menu canceled. Exiting.${CL}"
      exit 0
    fi

    case $CHOICE in
      1)
        header_info
        echo -e "${DEFAULT}${BOLD}${BL}Using Default Settings on node $PVEHOST_NAME${CL}"
        VERB="no"
        base_settings "$VERB"  
        echo_default
        break
        ;;
      2)
        header_info
        echo -e "${DEFAULT}${BOLD}${BL}Using Default Settings on node $PVEHOST_NAME (${SEARCH}${BL}Verbose)${CL}"
        VERB="yes"
        base_settings "$VERB"  
        echo_default
        break
        ;;
      3)
        header_info
        echo -e "${ADVANCED}${BOLD}${RD}Using Advanced Settings on node $PVEHOST_NAME${CL}"
        advanced_settings
        break
        ;;
      4)
        echo -e "${CROSS}${RD}Exiting.${CL}"
        exit 0
        ;;
      *)
        echo -e "${CROSS}${RD}Invalid option, please try again.${CL}"
        ;;
    esac
  done
}

check_container_resources() {
  # Check actual RAM & Cores
  current_ram=$(free -m | awk 'NR==2{print $2}')
  current_cpu=$(nproc) 

  # Check whether the current RAM is less than the required RAM or the CPU cores are less than required
  if [[ "$current_ram" -lt "$var_ram" ]] || [[ "$current_cpu" -lt "$var_cpu" ]]; then
    echo -e "\n${INFO}${HOLD} ${GN}Required: ${var_cpu} CPU, ${var_ram}MB RAM ${CL}| ${RD}Current: ${current_cpu} CPU, ${current_ram}MB RAM${CL}"
    echo -e "${YWB}Please ensure that the ${APP} LXC is configured with at least ${var_cpu} vCPU and ${var_ram} MB RAM for the build process.${CL}\n"
    read -r -p "${INFO}${HOLD} May cause data loss! ${INFO} Continue update with under-provisioned LXC? <yes/No>  " prompt  
    # Check if the input is 'yes', otherwise exit with status 1
    if [[ ! ${prompt,,} =~ ^(yes)$ ]]; then
      echo -e "${CROSS}${HOLD} ${YWB}Exiting based on user input.${CL}"
      exit 1
    fi
  else
    echo -e ""
  fi
}

check_container_storage() {
  # Check if the /boot partition is more than 80% full
  total_size=$(df /boot --output=size | tail -n 1)
  local used_size=$(df /boot --output=used | tail -n 1)
  usage=$(( 100 * used_size / total_size ))
  if (( usage > 80 )); then
    # Prompt the user for confirmation to continue
    echo -e "${INFO}${HOLD} ${YWB}Warning: Storage is dangerously low (${usage}%).${CL}"
    read -r -p "Continue anyway? <y/N>  " prompt  
    # Check if the input is 'y' or 'yes', otherwise exit with status 1
    if [[ ! ${prompt,,} =~ ^(y|yes)$ ]]; then
      echo -e "${CROSS}${HOLD}${YWB}Exiting based on user input.${CL}"
      exit 1
    fi
  fi
}

start() {
  if command -v pveversion >/dev/null 2>&1; then
    if ! (whiptail --backtitle "Proxmox VE Helper Scripts" --title "${APP} LXC" --yesno "This will create a New ${APP} LXC. Proceed?" 10 58); then
      clear
      exit_script
      exit
    fi
    SPINNER_PID=""
    install_script
  fi

  if ! command -v pveversion >/dev/null 2>&1; then
    if ! (whiptail --backtitle "Proxmox VE Helper Scripts" --title "${APP} LXC UPDATE" --yesno "Support/Update functions for ${APP} LXC.  Proceed?" 10 58); then
      clear
      exit_script
      exit
    fi
    SPINNER_PID=""
    update_script
  fi
}

# This function collects user settings and integrates all the collected information.
build_container() {
#  if [ "$VERB" == "yes" ]; then set -x; fi

  if [ "$CT_TYPE" == "1" ]; then
    FEATURES="keyctl=1,nesting=1"
  else
    FEATURES="nesting=1"
  fi


  TEMP_DIR=$(mktemp -d)
  pushd $TEMP_DIR >/dev/null
  if [ "$var_os" == "alpine" ]; then
    export FUNCTIONS_FILE_PATH="$(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/alpine-install.func)"
  else
    export FUNCTIONS_FILE_PATH="$(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/install.func)"
  fi
  export CACHER="$APT_CACHER"
  export CACHER_IP="$APT_CACHER_IP"
  export tz="$timezone"
  export DISABLEIPV6="$DISABLEIP6"
  export APPLICATION="$APP"
  export app="$NSAPP"
  export PASSWORD="$PW"
  export VERBOSE="$VERB"
  export SSH_ROOT="${SSH}"
  export CTID="$CT_ID"
  export CTTYPE="$CT_TYPE"
  export PCT_OSTYPE="$var_os"
  export PCT_OSVERSION="$var_version"
  export PCT_DISK_SIZE="$DISK_SIZE"
  export PCT_OPTIONS="
    -features $FEATURES
    -hostname $HN
    -tags $TAGS
    $SD
    $NS
    -net0 name=eth0,bridge=$BRG$MAC,ip=$NET$GATE$VLAN$MTU
    -onboot 1
    -cores $CORE_COUNT
    -memory $RAM_SIZE
    -unprivileged $CT_TYPE
    $PW
  "
  # This executes create_lxc.sh and creates the container and .conf file
  bash -c "$(wget -qLO - https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/create_lxc.sh)" || exit

  LXC_CONFIG=/etc/pve/lxc/${CTID}.conf
  if [ "$CT_TYPE" == "0" ]; then
    cat <<EOF >>$LXC_CONFIG
# USB passthrough
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
lxc.cgroup2.devices.allow: c 188:* rwm
lxc.cgroup2.devices.allow: c 189:* rwm
lxc.mount.entry: /dev/serial/by-id  dev/serial/by-id  none bind,optional,create=dir
lxc.mount.entry: /dev/ttyUSB0       dev/ttyUSB0       none bind,optional,create=file
lxc.mount.entry: /dev/ttyUSB1       dev/ttyUSB1       none bind,optional,create=file
lxc.mount.entry: /dev/ttyACM0       dev/ttyACM0       none bind,optional,create=file
lxc.mount.entry: /dev/ttyACM1       dev/ttyACM1       none bind,optional,create=file
EOF
  fi

  if [ "$CT_TYPE" == "0" ]; then
    if [[ "$APP" == "Channels" || "$APP" == "Emby" || "$APP" == "ErsatzTV" || "$APP" == "Frigate" || "$APP" == "Jellyfin" || "$APP" == "Plex" || "$APP" == "Scrypted" || "$APP" == "Tdarr" || "$APP" == "Unmanic" || "$APP" == "Ollama" ]]; then
      cat <<EOF >>$LXC_CONFIG
# VAAPI hardware transcoding
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.cgroup2.devices.allow: c 29:0 rwm
lxc.mount.entry: /dev/fb0 dev/fb0 none bind,optional,create=file
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
EOF
    fi
  else
    if [[ "$APP" == "Channels" || "$APP" == "Emby" || "$APP" == "ErsatzTV" || "$APP" == "Frigate" || "$APP" == "Jellyfin" || "$APP" == "Plex" || "$APP" == "Scrypted" || "$APP" == "Tdarr" || "$APP" == "Unmanic" || "$APP" == "Ollama" ]]; then
      if [[ -e "/dev/dri/renderD128" ]]; then
        if [[ -e "/dev/dri/card0" ]]; then
          cat <<EOF >>$LXC_CONFIG
# VAAPI hardware transcoding
dev0: /dev/dri/card0,gid=44
dev1: /dev/dri/renderD128,gid=104
EOF
        else
          cat <<EOF >>$LXC_CONFIG
# VAAPI hardware transcoding
dev0: /dev/dri/card1,gid=44
dev1: /dev/dri/renderD128,gid=104
EOF
        fi
      fi
    fi
  fi

  # This starts the container and executes <app>-install.sh
  msg_info "Starting LXC Container"
  pct start "$CTID"
  msg_ok "Started LXC Container"
  if [ "$var_os" == "alpine" ]; then
    sleep 3
        pct exec "$CTID" -- /bin/sh -c 'cat <<EOF >/etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/latest-stable/main
http://dl-cdn.alpinelinux.org/alpine/latest-stable/community
EOF'
    pct exec "$CTID" -- ash -c "apk add bash >/dev/null"
  fi
  lxc-attach -n "$CTID" -- bash -c "$(wget -qLO - https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/$var_install.sh)" || exit

}

# This function sets the description of the container.
description() {
  IP=$(pct exec "$CTID" ip a s dev eth0 | awk '/inet / {print $2}' | cut -d/ -f1)

  # Generate LXC Description
  DESCRIPTION=$(cat <<EOF
<div align='center'>
  <a href='https://Helper-Scripts.com' target='_blank' rel='noopener noreferrer'>
    <img src='https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/images/logo-81x112.png' alt='Logo' style='width:81px;height:112px;'/>
  </a>

  <h2 style='font-size: 24px; margin: 20px 0;'>${APP} LXC</h2>

  <p style='margin: 16px 0;'>
    <a href='https://ko-fi.com/community_scripts' target='_blank' rel='noopener noreferrer'>
      <img src='https://img.shields.io/badge/&#x2615;-Buy us a coffee-blue' alt='spend Coffee' />
    </a>
  </p>
  
  <span style='margin: 0 10px;'>
    <i class="fa fa-github fa-fw" style="color: #f5f5f5;"></i>
    <a href='https://github.com/community-scripts/ProxmoxVE' target='_blank' rel='noopener noreferrer' style='text-decoration: none; color: #00617f;'>GitHub</a>
  </span>
  <span style='margin: 0 10px;'>
    <i class="fa fa-comments fa-fw" style="color: #f5f5f5;"></i>
    <a href='https://github.com/community-scripts/ProxmoxVE/discussions' target='_blank' rel='noopener noreferrer' style='text-decoration: none; color: #00617f;'>Discussions</a>
  </span>
  <span style='margin: 0 10px;'>
    <i class="fa fa-exclamation-circle fa-fw" style="color: #f5f5f5;"></i>
    <a href='https://github.com/community-scripts/ProxmoxVE/issues' target='_blank' rel='noopener noreferrer' style='text-decoration: none; color: #00617f;'>Issues</a>
  </span>
</div>
EOF
)

  # Set Description in LXC
  pct set "$CTID" -description "$DESCRIPTION"

  if [[ -f /etc/systemd/system/ping-instances.service ]]; then
    systemctl start ping-instances.service
  fi
}