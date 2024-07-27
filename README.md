# icarus-workstation
Install instructions for icarus-workstation

First off I should say the following is not necessary for a majority of people with any interest in GPU passthrough from a Linux host to a Windows guest. I've done all of this because of my very particular requirements for an ideal workstation/general purpose PC.

> * Wanting to stay in a Linux environment at all times
> * Wanting to avoid dual boot since I don't want to have to shutdown Linux to switch to a Windows environment for gaming/streaming/content creation, or vice versa
> * Wanting to avoid multi-monitor setup entirely. I like only using a single monitor
> * Wanting to be able to have full use of GPU power in a Windows virtual machine for gaming
> * Wanting to have Windows still have enough CPU power to chew through anything I throw at it
> * Being able to easily access Windows environment while still inside of Linux environment
> * Wanting to avoid building/running multiple physical machines
> * Wanting to have hear sound from both the Linux host and Windows 10 guest at the same time
> * Wanting to feed my headset microphone input to both Linux host and Windows 10 guest at the same time


If these things also generally interest you, then my particular setup may be something for you to adjust for your own needs. Just beware there is quite a bit of set up involved, and some high level degree of computer literacy involed, so this is not for the faint of heart.


Additional notes: If you are intending on playing Battlefield games or any games which use Punk Buster, make sure that once you've completed all of this you go to the Punk Buster website, download and install the Punk Buster service, and run the Punk Buster Setup for any games you intend on playing. If you do not do this you may end up getting kicked by multiplayer servers running Punk Buster.

### Configuring the BIOS

**PHYSICAL MACHINE:**

Preparing the motherboard
In Bios go to Advanced Mode
1. In **OC ->  Advanced CPU configuration -> AMD CBS  -> IMMOU Mode**, set this to **Enabled**
   
	This will allow passthrough of hardware to virtualize guest operating systems.

2. In **OC -> Advanced CPU configuration -> SVM Mode**, set this to **Enabled**
   
	This will allow passthrough of hardware to virtualize guest operating systems.

3. In **Settings -> Advanced -> Windows OS Configuration -> BIOS UEFI/CSM Mode**, set this to **UEFI**
   
	This will allow you to plug your display into the GPU that's in the second PCI-E slot of the motherboard and use it as your hosts primary GPU.
   
4. In **Settings -> Advanced -> Integrated Peripherals -> VGA Card Detection**, set this to **Ignore**
   
	This will allow you to use the secondary pci-e slotted GPU as the primary GPU for your host, rather than whatever is in the primary pcie-e slot.
   
5. Hit **F10** to bring up save menu, and select **yes**
   
	This will save your settings as you've configured them and reboot the machine.

### Configuring the Linux Host

**LINUX HOST:**

Choose your distro, get it installed and updated.

#### Install Common Applications

Let's get our applications and networked shares set up.

```bash
sudo apt-get install nala
sudo nala install nvtop
sudo nala install htop
sudo nala install iotop				
sudo nala install nfs-common
sudo nala install git
sudo nala install cmake
sudo nala install mediainfo
sudo nala install ffmpeg
sudo nala install python3.12 python3.12-venv python3.12-dev
sudo nala install python3-pip
```

#### Set Up Auto Mounting Network Shares

Create the folders that the network shares will be mapped to

```bash
sudo mkdir -p /home/owner/.mnt/media/.atlas.backup/
sudo mkdir -p /home/owner/.mnt/media/.atlas.media-server/_downloads
sudo mkdir -p /home/owner/.mnt/media/.atlas.media-server/_media
```

Now add the networked shares to fstab so that they'll be mounted when we boot up

```bash
sudo nano /etc/fstab
```

Then we paste the contents at the end of the file

```bash
10.10.10.200:/mnt/atlas-storage/atlas.backup/    /home/owner/.mnt/media/.atlas.backup/    nfs    auto,nofail,noatime,nolock,intr,proto=tcp,hard,actimeo=1800,port=2049    0    0
10.10.10.200:/mnt/atlas-storage/atlas.media-server/_downloads/    /home/owner/.mnt/media/.atlas.media-server/_downloads/ nfs    auto,nofail,noatime,nolock,intr,tcp,hard,actimeo=1800 0 0
10.10.10.200:/mnt/atlas-storage/atlas.media-server/_media/    /home/owner/.mnt/media/.atlas.media-server/_media/    nfs    auto,nofail,noatime,nolock,intr,tcp,hard,actimeo=1800 0 0
```

Restart the machine for the changes to take effect and the shares to be auto mounted

```bash
sudo reboot now
```

We need to make sure that we open **Driver Manager** and **install the latest Nvidia drivers**. At the time of this writing nvidia-driver-535 was the latest.

#### Installing Virt Manager

Let's get Virtual Machine Manager and QEMU related applications installed.

```bash
sudo nala install driverctl qemu-kvm qemu-utils libvirt-daemon-system libvirt-clients virt-manager ovmf
```

Now let's restart the system

```bash
sudo reboot now
```

#### Identifying IOMMU Groups and Bus IDS

Now let's just verify that our host OS ready for virtualization by confirming IMMOU support, and AMD-Vi features are enabled.

```bash
dmesg | grep AMD-Vi
```

*We should see something like the following returned:*

    [    1.202200] pci 0000:00:00.2: AMD-Vi: IOMMU performance counters supported
    [    1.207028] pci 0000:00:00.2: AMD-Vi: Found IOMMU cap 0x40
    [    1.207029] pci 0000:00:00.2: AMD-Vi: Extended features (0x58f77ef22294ade):
    [    1.207031] AMD-Vi: Interrupt remapping enabled
    [    1.207031] AMD-Vi: Virtual APIC enabled
    [    1.207031] AMD-Vi: X2APIC enabled
    [    1.207117] AMD-Vi: Lazy IO/TLB flushing enabled

Now we need to get the bus ids of our video cards. In my case I'm using two Nvidia GPUs so I'll run the following and copy the output to a text file for later reference.

```bash
lspci -nn | grep VGA
```

*The output for this will be something like:*

    24:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP104 [GeForce GTX 1070] [10de:1b81] (rev a1)
    2d:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP102 [GeForce GTX 1080 Ti] [10de:1b06] (rev a1)

Now run lspci -nn | grep with the bus of the GPU you want to pass to the guest so we can obtain buses for any other devices associated with the GPU.

```bash
lspci -nn | grep 2d:00
```

*This will output something like:*

    2d:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP102 [GeForce GTX 1080 Ti] [10de:1b06] (rev a1)
    2d:00.1 Audio device [0403]: NVIDIA Corporation GP102 HDMI Audio Controller [10de:10ef] (rev a1)

Now we need to get the bus id of the WI-FI device since we'd like to also passthrough the Bluetooth device and frequently the WI-FI and Bluetooth are a combo devices.

```bash
lspci -nn | grep -i WI-FI
```

*Which will output:*

    28:00.0 Audio device [0403]: Creative Labs Device [1102:0010] (rev 01)

I have a Sound Blaster AE-7 sound card that I purchased for the purpose of splitting my mic input so both my host and guest can receive the input from my headset. I'll pass that as well.

```bash
lspci -nn | grep -i Audio
```

*The output for which was:*

    26:00.0 Multimedia audio controller: C-Media Electronics Inc CMI8738/CMI8768 PCI Audio (rev 10)

```bash
dmesg |grep -i Bluetooth
```

*Should show us:*

    [    5.032245] Bluetooth: Core ver 2.22
    [    5.032267] Bluetooth: HCI device and connection manager initialized
    [    5.032272] Bluetooth: HCI socket layer initialized
    [    5.032273] Bluetooth: L2CAP socket layer initialized
    [    5.032274] Bluetooth: SCO socket layer initialized
    [    5.292802] Bluetooth: hci0: Firmware revision 0.0 build 128 week 11 2020
    [    5.687659] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
    [    5.687660] Bluetooth: BNEP filters: protocol multicast
    [    5.687663] Bluetooth: BNEP socket layer initialized
    [   11.338799] Bluetooth: RFCOMM TTY layer initialized
    [   11.338804] Bluetooth: RFCOMM socket layer initialized
    [   11.338807] Bluetooth: RFCOMM ver 1.11
    [17337.099124] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
    [17337.099128] Bluetooth: HIDP socket layer initialized
    [17337.251100] input: Wireless Controller Touchpad as /devices/pci0000:00/0000:00:01.2/0000:20:00.0/0000:21:08.0/0000:2a:00.1/usb1/1-4/1-4:1.0/bluetooth/hci0/hci0:256/0005:054C:09CC.0009/input/input51
    [17337.251225] input: Wireless Controller Motion Sensors as /devices/pci0000:00/0000:00:01.2/0000:20:00.0/0000:21:08.0/0000:2a:00.1/usb1/1-4/1-4:1.0/bluetooth/hci0/hci0:256/0005:054C:09CC.0009/input/input52
    [17337.251433] input: Wireless Controller as /devices/pci0000:00/0000:00:01.2/0000:20:00.0/0000:21:08.0/0000:2a:00.1/usb1/1-4/1-4:1.0/bluetooth/hci0/hci0:256/0005:054C:09CC.0009/input/input50
    [17337.251562] sony 0005:054C:09CC.0009: input,hidraw0: BLUETOOTH HID v81.00 Gamepad [Wireless Controller] on 8c:c6:81:9b:6f:5d
    [17516.248946] Bluetooth: Unexpected start frame (len 83)
    [17705.073144] Bluetooth: Unexpected start frame (len 83)

Now in terminal we need to determine the IOMMU groups for the GPU buses that we've isolated by running the following.

```bash
for a in /sys/kernel/iommu_groups/*; do find $a -type l; done | sort --version-sort
```

*We get the following output:*

    /sys/kernel/iommu_groups/0/devices/0000:00:01.0
    /sys/kernel/iommu_groups/1/devices/0000:00:01.1
    /sys/kernel/iommu_groups/2/devices/0000:00:01.2
    /sys/kernel/iommu_groups/3/devices/0000:00:02.0
    /sys/kernel/iommu_groups/4/devices/0000:00:03.0
    /sys/kernel/iommu_groups/5/devices/0000:00:03.1
    /sys/kernel/iommu_groups/6/devices/0000:00:04.0
    /sys/kernel/iommu_groups/7/devices/0000:00:05.0
    /sys/kernel/iommu_groups/8/devices/0000:00:07.0
    /sys/kernel/iommu_groups/9/devices/0000:00:07.1
    /sys/kernel/iommu_groups/10/devices/0000:00:08.0
    /sys/kernel/iommu_groups/11/devices/0000:00:08.1
    /sys/kernel/iommu_groups/12/devices/0000:00:14.0
    /sys/kernel/iommu_groups/12/devices/0000:00:14.3
    /sys/kernel/iommu_groups/13/devices/0000:00:18.0
    /sys/kernel/iommu_groups/13/devices/0000:00:18.1
    /sys/kernel/iommu_groups/13/devices/0000:00:18.2
    /sys/kernel/iommu_groups/13/devices/0000:00:18.3
    /sys/kernel/iommu_groups/13/devices/0000:00:18.4
    /sys/kernel/iommu_groups/13/devices/0000:00:18.5
    /sys/kernel/iommu_groups/13/devices/0000:00:18.6
    /sys/kernel/iommu_groups/13/devices/0000:00:18.7
    /sys/kernel/iommu_groups/14/devices/0000:01:00.0
    /sys/kernel/iommu_groups/15/devices/0000:20:00.0
    /sys/kernel/iommu_groups/16/devices/0000:21:01.0
    /sys/kernel/iommu_groups/17/devices/0000:21:02.0
    /sys/kernel/iommu_groups/18/devices/0000:21:04.0
    /sys/kernel/iommu_groups/19/devices/0000:21:06.0
    /sys/kernel/iommu_groups/20/devices/0000:2a:00.0
    /sys/kernel/iommu_groups/20/devices/0000:2a:00.1
    /sys/kernel/iommu_groups/20/devices/0000:2a:00.3
    /sys/kernel/iommu_groups/20/devices/0000:21:08.0
    /sys/kernel/iommu_groups/21/devices/0000:2b:00.0
    /sys/kernel/iommu_groups/21/devices/0000:21:09.0
    /sys/kernel/iommu_groups/22/devices/0000:2c:00.0
    /sys/kernel/iommu_groups/22/devices/0000:21:0a.0
    /sys/kernel/iommu_groups/23/devices/0000:23:00.0
    /sys/kernel/iommu_groups/24/devices/0000:24:00.0
    /sys/kernel/iommu_groups/24/devices/0000:24:00.1
    /sys/kernel/iommu_groups/25/devices/0000:26:00.0
    /sys/kernel/iommu_groups/26/devices/0000:28:00.0
    /sys/kernel/iommu_groups/27/devices/0000:2d:00.0
    /sys/kernel/iommu_groups/27/devices/0000:2d:00.1
    /sys/kernel/iommu_groups/28/devices/0000:2e:00.0
    /sys/kernel/iommu_groups/29/devices/0000:2f:00.0
    /sys/kernel/iommu_groups/30/devices/0000:2f:00.3
    /sys/kernel/iommu_groups/31/devices/0000:2f:00.4

*From the list we find the IMMOU group by searching for the buses of the GPU we want to pass through:*

    0000:2d:00.0
    0000:2d:00.1

    2d:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3090] [10de:2204] (rev a1)
    2d:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)


*Additional IMMOU group for bus of the WI-FI / Bluetooth we want to pass through which we should note:*

    0000:28:00.0


We're using the following command to get a list of nvidia devices.

```bash
lspci -nnk | grep -i nvidia
```

*The list of nvidia devices found is:*

    24:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP102 [GeForce GTX 1080 Ti] [10de:1b06] (rev a1)
	    Kernel modules: nvidiafb, nouveau, nvidia_drm, nvidia
    24:00.1 Audio device [0403]: NVIDIA Corporation GP102 HDMI Audio Controller [10de:10ef] (rev a1)
    2d:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3090] [10de:2204] (rev a1)
	    Kernel driver in use: nvidia
	    Kernel modules: nvidiafb, nouveau, nvidia_drm, nvidia
    2d:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)

And the following command to get a list of audio devices.

```bash
lspci -nn | grep -i Audio
```

*The list of audio devices returned is:*

    24:00.1 Audio device [0403]: NVIDIA Corporation GP102 HDMI Audio Controller [10de:10ef] (rev a1)
    28:00.0 Audio device [0403]: Creative Labs Device [1102:0010] (rev 01)
    2d:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
    2f:00.4 Audio device [0403]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse HD Audio Controller [1022:1487]

#### Assigning Devices to VFIO

Next we plug the bus ids ( xxxx:xxxx ) of the devices we want to pass to our virtual machine into vfio_pci.ids= as a comma delimited list

```bash
sudo nano /etc/default/grub
```

In this file we'll update the `GRUB_CMDLINE_LINUX_DEFAULT` line to the following. We use `amd_iommu=on` to enable AMD's IOMMU (Input/Output Memory Management Unit), `amd_iommu=pt' to enable IOMMU pass-through mode, `vfio_pci.ids` for the specified device bus ids to be bound to the VFIO-PCI driver at boot, and `kvm.ignore_msrs=1` to tell KVM (Kernel-based Virtual Machine) to ignore unhandled Model Specific Registers access.

    GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_iommu=on amd_iommu=pt vfio_pci.ids=10de:1b06,10de:10ef,1102:0010 kvm.ignore_msrs=1"

Now we must update the grub for our changes to take effect.

```bash
sudo update-grub
```

In order to load vfio and other related modules at boot, add the following to the end of the modules file.

```bash
sudo nano /etc/initramfs-tools/modules
```

Then paste the following contents

	vfio
	vfio_iommu_type1
	vfio_pci
	vfio_virqfd
	vhost-net

Now we plug the same bus ids ( xxxx:xxxx ) of the devices we want to pass to our virtual machine into vfio-pci ids= as a comma delimited list.

```bash
sudo nano /etc/modprobe.d/vfio.conf
```

Then paste the following contents

	options vfio-pci ids=10de:1b06,10de:10ef,1102:0010
	softdep nvidia pre: vfio-pci
	softdep nvidia* pre: vfio-pci

Now update the initramfs.

```bash
sudo update-initramfs -k all -u
```

Refresh the system so these changes take effect

```bash
sudo reboot now
```

After reboot we should be able to target the devices to switch drivers on the fly by using the following as examples

*This command is tells the system to use the NVIDIA driver for the targetted GPU without saving the change permanently. This will make the targetted GPU available to the Linux host with Nvidia drivers, and unavailable to  the virtual machine. It will not work if you're using Nouveau drivers, only if you're using the proprietary Nvidia drivers.*

```bash
sudo driverctl --nosave set-override 0000:24:00.0 nvidia
```

*This command is tells the system to use vfio-pci for the targetted GPU without saving the change permanently. This will make the targetted GPU available to the virtual machine, and unavailable to the Linux host to use.*

```bash
sudo driverctl --nosave set-override 0000:24:00.0 vfio-pci
```

*This command is tells the system to use the Nouveau driver for the targetted GPU without saving the change permanently. This will make the targetted GPU available to the Linux host with Nouveau drivers, and unavailable to  the virtual machine. It will not work if you're using Nvidia drivers, only if you're using the Nouveau drivers.*

```bash
sudo driverctl --nosave set-override 0000:24:00.0 nouveau
```

Now we need to get the names of our physical disks. In my case I have between 4 and 5 different SSDs. I'll run the following and copy the output to a text file for later reference
```bash
ls -l /dev/disk/by-id/
    lrwxrwxrwx 1 root root  9 Aug 27 08:47 ata-ASUS_DRW-24B1ST_i_E2D0CL027462 -> ../../sr0
    lrwxrwxrwx 1 root root  9 Aug 27 08:47 ata-SAMSUNG_SSD_830_Series_S0Z3NSACA01314 -> ../../sdb
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 ata-SAMSUNG_SSD_830_Series_S0Z3NSACA01314-part1 -> ../../sdb1
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 ata-SAMSUNG_SSD_830_Series_S0Z3NSACA01314-part2 -> ../../sdb2
    lrwxrwxrwx 1 root root  9 Aug 27 08:47 ata-Samsung_SSD_850_PRO_1TB_S3D2NX0HA09737Z -> ../../sdc
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 ata-Samsung_SSD_850_PRO_1TB_S3D2NX0HA09737Z-part1 -> ../../sdc1
    lrwxrwxrwx 1 root root  9 Aug 27 08:47 ata-Samsung_SSD_860_PRO_512GB_S5GBNA0M902117H -> ../../sda
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 ata-Samsung_SSD_860_PRO_512GB_S5GBNA0M902117H-part1 -> ../../sda1
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 ata-Samsung_SSD_860_PRO_512GB_S5GBNA0M902117H-part2 -> ../../sda2
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 ata-Samsung_SSD_860_PRO_512GB_S5GBNA0M902117H-part3 -> ../../sda3
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 dm-name-sda3_crypt -> ../../dm-0
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 dm-name-vgmint-root -> ../../dm-1
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 dm-name-vgmint-swap_1 -> ../../dm-2
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 dm-uuid-CRYPT-LUKS2-ddfc3b9e6e394404b695acc1f4ea8d5e-sda3_crypt -> ../../dm-0
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 dm-uuid-LVM-GbbPuB1DUtM5GADDvjzA1LsPSDhbwABS6NfSVWNthrgW0mX79Fex0MK4XwkCsUGp -> ../../dm-2
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 dm-uuid-LVM-GbbPuB1DUtM5GADDvjzA1LsPSDhbwABSYjXeGcVVQ2yed7nEwE86SyD7iskjOEo6 -> ../../dm-1
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 lvm-pv-uuid-Fc8jBd-QJAM-YOr2-buyT-r9Oo-LNlR-06xqQl -> ../../dm-0
    lrwxrwxrwx 1 root root 13 Aug 27 08:47 nvme-eui.002538570142a154 -> ../../nvme0n1
    lrwxrwxrwx 1 root root 15 Aug 27 08:47 nvme-eui.002538570142a154-part1 -> ../../nvme0n1p1
    lrwxrwxrwx 1 root root 15 Aug 27 08:47 nvme-eui.002538570142a154-part5 -> ../../nvme0n1p5
    lrwxrwxrwx 1 root root 13 Aug 27 08:47 nvme-Samsung_SSD_970_PRO_512GB_S5JYNS0N709889V -> ../../nvme0n1
    lrwxrwxrwx 1 root root 15 Aug 27 08:47 nvme-Samsung_SSD_970_PRO_512GB_S5JYNS0N709889V-part1 -> ../../nvme0n1p1
    lrwxrwxrwx 1 root root 15 Aug 27 08:47 nvme-Samsung_SSD_970_PRO_512GB_S5JYNS0N709889V-part5 -> ../../nvme0n1p5
    lrwxrwxrwx 1 root root  9 Aug 27 08:47 wwn-0x5002538043584d30 -> ../../sdb
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 wwn-0x5002538043584d30-part1 -> ../../sdb1
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 wwn-0x5002538043584d30-part2 -> ../../sdb2
    lrwxrwxrwx 1 root root  9 Aug 27 08:47 wwn-0x5002538c404401c3 -> ../../sdc
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 wwn-0x5002538c404401c3-part1 -> ../../sdc1
    lrwxrwxrwx 1 root root  9 Aug 27 08:47 wwn-0x5002538e19901b2f -> ../../sda
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 wwn-0x5002538e19901b2f-part1 -> ../../sda1
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 wwn-0x5002538e19901b2f-part2 -> ../../sda2
    lrwxrwxrwx 1 root root 10 Aug 27 08:47 wwn-0x5002538e19901b2f-part3 -> ../../sda3
```

From the list we find the physical disk that we want to passthrough to the guest OS. In my case I'm going to be installing Windows 10 directly to the Samsung SSD 970 Pro, using the Samsung SSD 850 Pro for my video games and general storage, and the Samsung SSD 830 for Acronis backups of the Windows guest os drive.
[cpde
    /dev/disk/by-id/nvme-Samsung_SSD_970_PRO_512GB_S5JYNS0N709889V
    /dev/disk/by-id/ata-Samsung_SSD_850_PRO_1TB_S3D2NX0HA09737Z
    /dev/disk/by-id/ata-SAMSUNG_SSD_830_Series_S0Z3NSACA01314

Now we create the actual Virtual Machine itself in Virtual Machine Manager. This is a whole process in itself but to summarize, create the virtual machine and specify our Windows 10 installation media, typically an ISO so when the machine first boots we can start the installation process.
vm name is theseus
Memory (RAM): 65536
Sound ich9: HDA (ICH9)
Overview -> Hypervisor Details
    Firmware: UEFI x86_64: /usr/share/OVMF/OVMF_CODE.fd
    Chipset: i440FX
Vritual Network Interface -> Network source
    Virtual network 'default' : NAT
Add Hardware -> Storage -> Select or Create Custom Storage
    Manage: /dev/disk/by-id/nvme-Samsung_SSD_970_PRO_512GB_S5JYNS0N709889V
    Device Type: Disk device
    Bus type: SATA
Add Hardware -> PCI Host Device
    0000:01:00:0 NVIDIA Corporation GP102 [GeForce GTX 1080 Ti]
Add Hardware -> PCI Host Device
    0000:01:01:1 NVIDIA Corporation GP102 HDMI Audio Controller
Add Hardware -> PCI Host Devices
    0000:28:00:0 Intel Corporation Wi-Fi 6 AX200
CPUs -> Configuration
    Current Allocation: 24
    Model: host-passthrough

WINDOWS GUEST:
Finish installation, and run updates. Now we need to download https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/upstream-virtio/virtio-win10-prewhql-0.1-161.zip and extract the contents, look in the Devices and Hardware for anything that's missing a driver, and install drivers from the location of the virtio-win10 folder that we extracted. Next in Devices and Hardware, look for PCI standard RAM Controller and update the drivers for this device with drivers from the virtio-win10 folder as well so that Windows will see IVSHMEM device.

LINUX HOST:
Make sure we install all of the various bits we'll need to build the Looking Glass client application.
sudo nala install -y qemu-kvm qemu-utils libvirt-daemon-system libvirt-clients virt-manager ovmf
