# OSX-KVM-Installer

This repository contains a script that automates the installation of macOS on KVM (Kernel-based Virtual Machine), with due credit to the resources provided by the [OSX-KVM](https://github.com/kholia/OSX-KVM) repository and its contributors.

## Prerequisites

- A Linux system with `apt` package manager (like Ubuntu)
- Virtualization enabled in BIOS

## Installation

Before running the script, ensure you have `git` and `sudo` privileges on your system. Then, clone this repository:

```bash
git clone https://github.com/notarisj/OSX-KVM-Installer.git
cd OSX-KVM-Installer
```

Make the script executable:

```bash
chmod +x setup-macos-kvm.sh
```

Run the script with root privileges:

```bash
sudo ./setup-macos-kvm.sh
```

Follow the on-screen instructions to complete the installation.

## Features

The script includes:

- **Package Installation**: Installs the required packages to run KVM and manage macOS virtual machines, such as QEMU, virt-manager, and other dependencies.
- **OSX-KVM Repository Management**: Handles the cloning and updating of the OSX-KVM repository.
- **KVM Configuration**: Configures KVM to work with either Intel or AMD CPUs by adjusting the `/etc/modprobe.d/kvm.conf` file accordingly.
- **User Group Configuration**: Adds the current user to all necessary groups (`kvm`, `libvirt`, `input`) to manage KVM and virtual machines without needing root access at all times.
- **macOS Base System Download**: Utilizes the `fetch-macOS.py` script from the OSX-KVM project to download the latest macOS base system for installation.
- **DMG to IMG Conversion**: Converts the downloaded macOS `.dmg` file to an `.img` format.
- **Disk Image Creation**: Creates a new disk image file with a size defined by the user.
- **VM Resource Customization**: Allows the customization of virtual machine resources, including allocated RAM, number of CPU sockets, cores, and threads. Be careful when changing these values!
- **macOS VM Launch**: Initiates the macOS VM using the OpenCore boot method provided by the OSX-KVM project.

## Credits

This script is created with reference to the excellent work done by the OSX-KVM project. The OSX-KVM project can be found [here](https://github.com/kholia/OSX-KVM). All credit for the ability to run macOS on KVM goes to the maintainers and contributors of OSX-KVM.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

