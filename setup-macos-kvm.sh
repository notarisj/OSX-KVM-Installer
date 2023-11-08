#!/bin/bash

###########################################################
# macOS KVM Installation Script
# This script automates the process of installing macOS on 
# KVM (Kernel-based Virtual Machine) using the OSX-KVM 
# repository and associated resources.
###########################################################

# ----------------------------
# Title: Root Privilege Check
# ----------------------------
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# ----------------------------
# Title: Package Installation
# ----------------------------
echo "-------------------------------------------------------"
echo "Step 1: Install Packages"
echo "-------------------------------------------------------"
# Define the list of required packages
required_packages=(
  qemu
  uml-utilities
  virt-manager
  git
  wget
  libguestfs-tools
  p7zip-full
  make
  dmg2img
  tesseract-ocr
  tesseract-ocr-eng
  genisoimage
)

# Flag to track if all packages are installed
all_packages_installed=true

# Loop through the list of required packages to check if they are installed
for package in "${required_packages[@]}"; do
  if ! dpkg -l "$package" &> /dev/null; then
    echo "Package $package is not installed."
    all_packages_installed=false
  fi
done

# If not all packages are installed, update and install the missing ones
if [ "$all_packages_installed" = false ]; then
  sudo apt-get update
  sudo apt-get install -y "${required_packages[@]}"
else
  echo "All required packages are already installed."
fi

# --------------------------------
# Title: Clone OSX-KVM Repository
# --------------------------------
echo "-------------------------------------------------------"
echo "Step 2: Clone the OSX-KVM repository"
echo "-------------------------------------------------------"
cd /home/$SUDO_USER || { echo "Failed to change directory. Exiting."; exit 1; }
OSX_KVM_DIR="/home/$SUDO_USER/OSX-KVM"

# Check if the OSX-KVM directory exists and verify its contents against the git repository
if [ -d "$OSX_KVM_DIR/.git" ]; then
    echo "OSX-KVM directory exists. Checking for updates..."
    cd "$OSX_KVM_DIR"
    # Fetch changes from the remote repository without merging them
    git fetch origin master
    # Check if the local repository is behind the remote repository
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        echo "Your local OSX-KVM repository is not up to date with the remote repository."
        echo "Updating local repository..."
        git pull --recurse-submodules
    else
        echo "OSX-KVM directory is up to date with the remote repository."
    fi
else
    echo "Cloning the OSX-KVM repository..."
    git clone --depth 1 --recursive https://github.com/kholia/OSX-KVM.git
fi

cd "$OSX_KVM_DIR" || { echo "Failed to change to OSX-KVM directory. Exiting."; exit 1; }

# --------------------------
# Title: KVM Configuration
# --------------------------
echo "-------------------------------------------------------"
echo "Step 3: Configure KVM for CPU type"
echo "-------------------------------------------------------"
# Check if the content of /etc/modprobe.d/kvm.conf contains Intel or AMD options
if grep -q 'options kvm_intel' /etc/modprobe.d/kvm.conf; then
    echo "Intel CPU configuration detected."
elif grep -q 'options kvm_amd' /etc/modprobe.d/kvm.conf; then
    echo "AMD CPU configuration detected."
else
    # If neither Intel nor AMD options are found, prompt the user to choose
    echo "No CPU configuration found in /etc/modprobe.d/kvm.conf."
    read -p "Do you have an Intel or AMD CPU? [Intel/AMD] " cpu_type
    case $cpu_type in
        [Ii]ntel)
            sudo cp kvm.conf /etc/modprobe.d/kvm.conf
            ;;
        [Aa][Mm][Dd])
            sudo cp kvm_amd.conf /etc/modprobe.d/kvm.conf
            ;;
        *)
            echo "Invalid CPU type selected. Exiting."
            exit 2
            ;;
    esac
fi

# -------------------------
# Title: User Group Update
# -------------------------
echo "-------------------------------------------------------"
echo "Step 4: Add the current user to KVM groups"
echo "-------------------------------------------------------"
# Check if the user is already in the required groups
if groups | grep -qw "kvm" && groups | grep -qw "libvirt" && groups | grep -qw "input"; then
    echo "User is already in the required groups."
else
    sudo usermod -aG kvm $(whoami)
    sudo usermod -aG libvirt $(whoami)
    sudo usermod -aG input $(whoami)
    echo "User added in the required groups."
fi

# ---------------------------------
# Title: Fetch macOS Installation
# ---------------------------------
echo "-------------------------------------------------------"
echo "Step 5: Execute the fetch-macOS script"
echo "-------------------------------------------------------"
if [ ! -f "BaseSystem.dmg" ]; then
    ./fetch-macOS-v2.py
else
    echo "BaseSystem.dmg already exists. Skipping download."
fi

# ------------------------------
# Title: Convert dmg to img
# ------------------------------
echo "-------------------------------------------------------"
echo "Step 6: Convert the downloaded dmg to img"
echo "-------------------------------------------------------"
if [ ! -f "BaseSystem.dmg" ]; then
    dmg2img -i BaseSystem.dmg -o BaseSystem.img
else
    echo "BaseSystem.img already exists. Skipping conversion."
fi

# -------------------------------------------
# Title: Create macOS Disk Image
# -------------------------------------------
echo "-------------------------------------------------------"
echo "Step 7: Ask for disk size and create disk image"
echo "-------------------------------------------------------"
if [ ! -f "mac_hdd_ng.img" ]; then
    read -p "Enter the desired size for the macOS disk image (e.g., 64G): " disk_size
    qemu-img create -f qcow2 mac_hdd_ng.img $disk_size
else
    echo "Disk image already exists. Skipping creation."
fi


# ------------------------------------
# Title: Customize VM's Resources
# ------------------------------------
echo "-------------------------------------------------------"
echo "Step 8: Customize the VM's resources"
echo "-------------------------------------------------------"
default_ram="4096"
default_sockets="1"
default_cores="2"
default_threads="4"

files_to_update=(
    OpenCore-Boot.sh
    boot-linux-for-debugging.sh
    boot-macOS-headless.sh
    boot-passthrough-windows.sh
    boot-windows.sh
    OpenCore-Boot-macOS.sh
)

user_changes=()

# Fetch RAM and CPU info for each file
echo "Fetching current VM resources for each file:"
for file in "${files_to_update[@]}"; do
    if [ -f "$file" ]; then
        ram_setting=$(grep '^ALLOCATED_RAM=' "$file" | sed 's/ALLOCATED_RAM=//')
        cpu_sockets_setting=$(grep '^CPU_SOCKETS=' "$file" | sed 's/CPU_SOCKETS=//')
        cpu_cores_setting=$(grep '^CPU_CORES=' "$file" | sed 's/CPU_CORES=//')
        cpu_threads_setting=$(grep '^CPU_THREADS=' "$file" | sed 's/CPU_THREADS=//')

        echo "File: $file"
        echo "RAM: $ram_setting MiB"
        echo "CPU Sockets: $cpu_sockets_setting"
        echo "CPU Cores: $cpu_cores_setting"
        echo "CPU Threads: $cpu_threads_setting"
        echo ""
    fi
done

read -p "Do you want to make changes to any of the files? (yes/no, default: no): " make_changes

while [ "$make_changes" = "yes" ]; do
    read -p "Enter the name of the file you want to change (e.g., OpenCore-Boot.sh): " selected_file

    # Check if the selected file is in the list of files to update
    if [[ " ${files_to_update[@]} " =~ " ${selected_file} " ]]; then
        read -p "Enter the new amount of RAM for this VM in MiB (e.g., $default_ram): " allocated_ram
        allocated_ram=${allocated_ram:-$default_ram}

        read -p "Enter the new number of CPU sockets for this VM (e.g., $default_sockets): " cpu_sockets
        cpu_sockets=${cpu_sockets:-$default_sockets}

        read -p "Enter the new number of CPU cores for this VM (e.g., $default_cores): " cpu_cores
        cpu_cores=${cpu_cores:-$default_cores}

        read -p "Enter the new number of CPU threads for this VM (e.g., $default_threads): " cpu_threads
        cpu_threads=${cpu_threads:-$default_threads}

        # Add the user's changes to the array
        user_changes+=("$selected_file")
        user_changes+=("$allocated_ram")
        user_changes+=("$cpu_sockets")
        user_changes+=("$cpu_cores")
        user_changes+=("$cpu_threads")

        echo "Settings for $selected_file updated."
    else
        echo "Invalid file name. Please enter a valid file name from the list."
    fi

    read -p "Do you want to make changes to any other files? (yes/no, default: no): " make_changes
done

# Apply the user's changes to the selected files. Increment by 5 for each file.
for ((i = 0; i < ${#user_changes[@]}; i += 5)); do
    file="${user_changes[i]}"
    allocated_ram="${user_changes[i + 1]}"
    cpu_sockets="${user_changes[i + 2]}"
    cpu_cores="${user_changes[i + 3]}"
    cpu_threads="${user_changes[i + 4]}"
    sed -i "/^ALLOCATED_RAM=/s/=\"[^\"]*\"/=\"$allocated_ram\"/" "$file"
    sed -i "/^CPU_SOCKETS=/s/=\"[^\"]*\"/=\"$cpu_sockets\"/" "$file"
    sed -i "/^CPU_CORES=/s/=\"[^\"]*\"/=\"$cpu_cores\"/" "$file"
    sed -i "/^CPU_THREADS=/s/=\"[^\"]*\"/=\"$cpu_threads\"/" "$file"
done

# -------------------------
# Title: Launch macOS VM
# -------------------------
echo "-------------------------------------------------------"
echo "Step 9: Run OpenCore-Boot.sh to start macOS"
echo "-------------------------------------------------------"

echo "Available scripts:"
for i in "${!files_to_update[@]}"; do
    echo "$((i+1)). ${files_to_update[i]}"
done

read -p "Enter the number of the script you want to run (default: 1): " script_number
script_number=${script_number:-1}

# Ensure the selected number is within a valid range
if ((script_number < 1 || script_number > ${#files_to_update[@]})); then
    echo "Invalid script number. Using the default (OpenCore-Boot.sh)."
    script_number=1
fi

chosen_script="${files_to_update[script_number-1]}"

chmod +x "$chosen_script"
"./$chosen_script"
