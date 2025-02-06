# workstation-icarus
Install instructions for workstation-icarus

#### Resources

* https://forum.level1techs.com/t/dual-gpu-vfio-setup-documentation-amd-cpu-gpus-with-kvm-switching/207205
* https://www.heiko-sieger.info/blacklisting-graphics-driver/
* https://www.reddit.com/r/VFIO/comments/188cf9v/comment/kbli5zz/
* https://forum.level1techs.com/t/problem-cant-use-driverctl-overrides-on-nvidia-driver/176777/3
* https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF
* https://github.com/201853910/VMwareWorkstation

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


If these things also generally interest you, then my particular setup may be something for you to adjust for your own needs. Just beware there is quite a bit of set up involved, and some high level degree of computer literacy involved, so this is not for the faint of heart.


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
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y
sudo apt-get install nala -y

sudo nala install git cmake build-essential nfs-common mediainfo ffmpeg -y 
sudo nala install nvtop htop iotop -y

sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y
sudo apt update
sudo apt install fastfetch

cd $HOME/Downloads/
git clone https://github.com/wmutschl/timeshift-autosnap-apt.git $HOME/Downloads/timeshift-autosnap-apt
cd $HOME/Downloads/timeshift-autosnap-apt
sudo make Install

cd $HOME/Downloads/
git clone https://github.com/Antynea/grub-btrfs.git $HOME/Downloads/grub-btrfs
cd $HOME/Downloads/grub-btrfs
sudo make install
```

Run Timeshift and complete the Setup Wizard using the following:

1. **Selection Snapshot Type** set as **BTRFS**, click **Next**

2. **Select Snapshot Location** should already have the correct location selected, click **Next**

3. **Select Snapshot Levels** make your preferred selections, click **Next**

4. **User Home Directories** make your preferred selections, click **Next**

5. **Setup Complete** click **Finish**


Now whenever an application is installed, an update is applied, or the kernel is updated/changed a snapshot will automatically be created and snapshots can be selected from our grub boot menu.

#### Set Up Auto Mounting Network Shares

Create the folders that the network shares will be mapped to

```bash
mkdir -p $HOME/.mnt/media/.atlas.backup/
mkdir -p $HOME/.mnt/media/.atlas.media-server/
mkdir -p $HOME/.mnt/media/.atlas.sort/
```

Now add the networked shares to fstab so that they'll be mounted when we boot up

```bash
sudo nano /etc/fstab
```

Then we paste the contents at the end of the file

```bash
192.168.2.20:/mnt/atlas-storage/atlas.backup/    /home/owner/.mnt/media/.atlas.backup/    nfs    auto,nofail,noatime,nolock,intr,proto=tcp,hard,actimeo=1800,port=2049    0    0
192.168.2.20:/mnt/atlas-storage/atlas.media-server/    /home/owner/.mnt/media/.atlas.media-server/ nfs    auto,nofail,noatime,nolock,intr,tcp,hard,actimeo=1800 0 0
192.168.2.20:/mnt/atlas-storage/atlas.sort/    /home/owner/.mnt/media/.atlas.sort/    nfs    auto,nofail,noatime,nolock,intr,tcp,hard,actimeo=1800 0 0
```

Restart the machine for the changes to take effect and the shares to be auto mounted

```bash
sudo reboot now
```


#### Install Miniconda
Let's get Conda installed so that we can manage environments running different versions of python and python packages.

```bash
cd $HOME/Downloads/
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b
source ~/miniconda3/bin/activate
conda init bash
conda info
conda update --all
```

#### Install Docker and Docker Compose
Let's get Docker and Docker Compose installed so that we can manage isolated containers for various applications.

```bash
cd $HOME/Downloads/
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker
docker run hello-world
docker compose version
sudo systemctl status docker
```

#### Install Nvidia Container Toolkit
First we'll need to add the package respository

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
```

Then we will update our package repository and install Nvidia Container Toolkit

```bash
sudo nala update
sudo nala install nvidia-container-toolkit -y
```


#### Installing Brew
We need to install Brew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Next we need to configure Brew
``` bash
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.profile
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

Now verify our Brew installation was successful
```bash
brew doctor
```


#### Installing Nvidia Drivers

We need to make sure that we open **Driver Manager** and **install the latest Nvidia drivers**. At the time of this writing nvidia-driver-535 was the latest.

#### Installing Virt Manager

Let's get Virtual Machine Manager and QEMU related applications installed.

```bash
sudo nala install driverctl qemu-kvm qemu-utils libvirt-daemon-system libvirt-clients virt-manager ovmf -y

sudo nala install binutils-dev cmake fonts-freefont-ttf libsdl2-dev libsdl2-ttf-dev libspice-protocol-dev libfontconfig1-dev libx11-dev nettle-dev -y
sudo nala install gir1.2-spiceclientgtk-3.0 -y
sudo nala install wayland-protocols -y
sudo nala install libxkbcommon-dev -y
sudo nala install libxcursor-dev -y
sudo nala install libxpresent-dev -y
sudo nala install libgles-dev -y
sudo nala install libpipewire-0.3-dev -y
sudo nala install libsamplerate0-dev -y
sudo nala install numactl -y
```

Now let's restart the system

```bash
sudo reboot now
```

#### Additional Apps To Install
> * **Thunderbird**
> * **Firefox**
>   - Extensions:
>     - BitWarden: [Page](https://addons.mozilla.org/en-US/firefox/addon/bitwarden-password-manager/), [Download](https://addons.mozilla.org/firefox/downloads/file/4407804/bitwarden_password_manager-latest.xpi)
>     - uBlock Origin: [Page](https://addons.mozilla.org/en-US/firefox/addon/ublock-origin/), [Download](https://addons.mozilla.org/firefox/downloads/file/4391011/ublock_origin-latest.xpi)
>     - SponsorBlock: [Page](https://addons.mozilla.org/en-US/firefox/addon/sponsorblock/), [Download](https://addons.mozilla.org/firefox/downloads/file/4404647/sponsorblock-latest.xpi)
>     - Enhancer for YouTube: [Page](https://addons.mozilla.org/en-US/firefox/addon/enhancer-for-youtube/), [Download](https://addons.mozilla.org/firefox/downloads/file/4393561/enhancer_for_youtube-latest.xpi)
>     - BlockTube: [Page](https://addons.mozilla.org/en-US/firefox/addon/blocktube/), [Download](https://addons.mozilla.org/firefox/downloads/file/4401602/blocktube-latest.xpi)
>     - LocalCDN: [Page](https://addons.mozilla.org/en-US/firefox/addon/localcdn-fork-of-decentraleyes/), [Download](https://addons.mozilla.org/firefox/downloads/file/4401439/localcdn_fork_of_decentraleyes-latest.xpi)
>     - AutoTab Discord: [Page](https://addons.mozilla.org/en-US/firefox/addon/auto-tab-discard/), [Download](https://addons.mozilla.org/firefox/downloads/file/4045009/auto_tab_discard-latest.xpi)
>     - Video Download Helper: [Page](https://addons.mozilla.org/en-US/firefox/addon/video-downloadhelper/), [Download](https://addons.mozilla.org/firefox/downloads/file/4347883/video_downloadhelper-latest.xpi)
>     - Media Harvest Twitter Media Downloader: [Page](https://github.com/EltonChou/TwitterMediaHarvest), [Download](https://github.com/EltonChou/TwitterMediaHarvest/releases/download/v4.2.9/mediaharvest@mediaharvest.app-v4.2.9.xpi)
>     - PDF Mage: [Page](https://addons.mozilla.org/en-US/firefox/addon/pdf-mage/), [Download](https://addons.mozilla.org/firefox/downloads/file/3866641/pdf_mage-latest.xpi)
>     - Go To Playing Tab: [Page](https://addons.mozilla.org/en-US/firefox/addon/go-to-playing-tab-2/), [Download](https://addons.mozilla.org/firefox/downloads/file/3047196/go_to_playing_tab_2-latest.xpi)
>     - Return YouTube Dislikes: [Page](https://addons.mozilla.org/en-US/firefox/addon/return-youtube-dislikes/), [Download](https://addons.mozilla.org/firefox/downloads/file/4371820/return_youtube_dislikes-latest.xpi)
>     - 600% Sound Volume: [Page](https://addons.mozilla.org/en-US/firefox/addon/600-sound-volume/), [Download](https://addons.mozilla.org/firefox/downloads/file/4396669/600_sound_volume-latest.xpi)
>     - Augmented Steam: [Page](https://addons.mozilla.org/en-US/firefox/addon/augmented-steam/), [Download](https://addons.mozilla.org/firefox/downloads/file/4403715/augmented_steam-latest.xpi)
>     - CivitAI Downloader: [Page](https://addons.mozilla.org/en-US/firefox/addon/civit-model-downloader/), [Download](https://addons.mozilla.org/firefox/downloads/file/4324821/civit_model_downloader-latest.xpi)
> * **Brave**
  ```bash
	sudo nala install curl -y
	
	sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
	
	echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
	
	sudo nala update && sudo nala install brave-browser -y
  ```
>   - Extensions:
>     - [BitWarden](https://chromewebstore.google.com/detail/bitwarden-password-manage/nngceckbapebfimnlniiiahkandclblb)
>     - [uBlock Origin](https://chromewebstore.google.com/detail/ublock/epcnnfbjfcgphgdmggkamkmgojdagdnn)
>     - [SponsorBlock](https://chromewebstore.google.com/detail/sponsorblock-for-youtube/mnjggcdmjocbbbhaepdhchncahnbgone)
>     - [Enhancer For YouTube](https://chromewebstore.google.com/detail/enhancer-for-youtube/ponfpcnoihfmfllpaingbgckeeldkhle)
>     - [BlockTube](https://chromewebstore.google.com/detail/blocktube/bbeaicapbccfllodepmimpkgecanonai)
>     - [LocalCDN](https://chromewebstore.google.com/detail/localcdn/njdfdhgcmkocbgbhcioffdbicglldapd)
>     - [AutoTab Discard](https://chromewebstore.google.com/detail/auto-tab-discard-suspend/jhnleheckmknfcgijgkadoemagpecfol)
>     - [Video Download Helper](https://chromewebstore.google.com/detail/video-downloadhelper/lmjnegcaeklhafolokijcfjliaokphfk)
>     - [Media Harvest Twitter Media Downloader](https://chromewebstore.google.com/detail/media-harvest-twitter-med/hpcgabhdlnapolkkjpejieegfpehfdok)
>     - [PDF Mage](https://chromewebstore.google.com/detail/pdf-mage/gknphemhpcknkhegndlihchfonpdcben)
>     - [Go To Playing Tab](https://chromewebstore.google.com/detail/go-to-playing-tab/hmbhamadknmmkapmhbldodoajkcggcml)
>     - [Return YouTube Dislikes](https://chromewebstore.google.com/detail/return-youtube-dislike/gebbhagfogifgggkldgodflihgfeippi)
>     - [600% Sound Volume](https://chromewebstore.google.com/detail/sound-booster-increase-vo/nmigaijibiabddkkmjhlehchpmgbokfj)
>     - [Augmented Steam](https://chromewebstore.google.com/detail/augmented-steam/dnhpnfgdlenaccegplpojghhmaamnnfp)
>     - [CivitAI Downloader](https://chromewebstore.google.com/detail/civit-model-downloader/dndabdgaagbfhbfhjkocfafjjabgmhea)
> * **Chrome**
  ```bash
  wget -qO $HOME/Downloads/chrome.latest.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  chmod +x $HOME/Downloads/chrome.latest.deb
  sudo dpkg -i $HOME/Downloads/chrome.latest.deb
  ```
>   - Extensions:
>     - [BitWarden](https://chromewebstore.google.com/detail/bitwarden-password-manage/nngceckbapebfimnlniiiahkandclblb)
>     - [uBlock Origin](https://chromewebstore.google.com/detail/ublock/epcnnfbjfcgphgdmggkamkmgojdagdnn)
>     - [SponsorBlock](https://chromewebstore.google.com/detail/sponsorblock-for-youtube/mnjggcdmjocbbbhaepdhchncahnbgone)
>     - [Enhancer For YouTube](https://chromewebstore.google.com/detail/enhancer-for-youtube/ponfpcnoihfmfllpaingbgckeeldkhle)
>     - [BlockTube](https://chromewebstore.google.com/detail/blocktube/bbeaicapbccfllodepmimpkgecanonai)
>     - [LocalCDN](https://chromewebstore.google.com/detail/localcdn/njdfdhgcmkocbgbhcioffdbicglldapd)
>     - [AutoTab Discard](https://chromewebstore.google.com/detail/auto-tab-discard-suspend/jhnleheckmknfcgijgkadoemagpecfol)
>     - [Video Download Helper](https://chromewebstore.google.com/detail/video-downloadhelper/lmjnegcaeklhafolokijcfjliaokphfk)
>     - [Media Harvest Twitter Media Downloader](https://chromewebstore.google.com/detail/media-harvest-twitter-med/hpcgabhdlnapolkkjpejieegfpehfdok)
>     - [PDF Mage](https://chromewebstore.google.com/detail/pdf-mage/gknphemhpcknkhegndlihchfonpdcben)
>     - [Go To Playing Tab](https://chromewebstore.google.com/detail/go-to-playing-tab/hmbhamadknmmkapmhbldodoajkcggcml)
>     - [Return YouTube Dislikes](https://chromewebstore.google.com/detail/return-youtube-dislike/gebbhagfogifgggkldgodflihgfeippi)
>     - [600% Sound Volume](https://chromewebstore.google.com/detail/sound-booster-increase-vo/nmigaijibiabddkkmjhlehchpmgbokfj)
>     - [Augmented Steam](https://chromewebstore.google.com/detail/augmented-steam/dnhpnfgdlenaccegplpojghhmaamnnfp)
>     - [CivitAI Downloader](https://chromewebstore.google.com/detail/civit-model-downloader/dndabdgaagbfhbfhjkocfafjjabgmhea)
> * **Discord**
  ```bash
  wget -qO $HOME/Downloads/discord.latest.deb https://discord.com/api/download?platform=linux
  chmod +x $HOME/Downloads/discord.latest.deb
  sudo dpkg -i $HOME/Downloads/discord.latest.deb
  ```
> * **Spotify**
  Add the package repository
  
  ```bash
  curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
  echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
  ```
  
  Update our packages list and install Spotify
  
  ```bash
  sudo nala update && sudo nala install spotify-client -y
  ```
> * **VLC Player**
  ```bash
  sudo nala update && sudo nala install vlc -y
  ```
> * **OBS Studio**
  ```bash
  sudo nala update && sudo nala install obs-studio -y
  ```
> * **Bottles**
  ```bash
  flatpak install flathub com.usebottles.bottles
  ```
> * **OnlyOffice**
  ```bash
  flatpak install flathub org.onlyoffice.desktopeditors
  ```
> * **GIMP**
  ```bash
  sudo nala update && sudo nala install gimp -y
  ```
> * **Audacity**
  ```bash
  sudo nala update && sudo nala install audacity -y
  ```
> * **DBeaver**
  ```bash
  wget -qO $HOME/Downloads/dbeaver.latest.deb https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb
  chmod +x $HOME/Downloads/dbeaver.latest.deb
  sudo dpkg -i $HOME/Downloads/dbeaver.latest.deb
  ```  
> * **VMware Workstation Pro**
    - Use the License Key: **MC60H-DWHD5-H80U9-6V85M-8280D**
  ```bash
  cd $HOME/Downloads
  wget https://github.com/201853910/VMwareWorkstation/releases/download/17.0/VMware-Workstation-Full-17.5.0-22583795.x86_64.bundle
  chmod +x VMware-Workstation-Full-17.5.0-22583795.x86_64.bundle
  sudo ./VMware-Workstation-Full-17.5.0-22583795.x86_64.bundle
  mkdir -p $HOME/Downloads/vmware_workstation_pro_17.5/vmware-host-modules
  cd $HOME/Downloads/vmware_workstation_pro_17.5/vmware-host-modules
  wget https://github.com/mkubecek/vmware-host-modules/archive/workstation-17.5.0.tar.gz 
  tar -xzf workstation-17.5.0.tar.gz
  cd vmware-host-modules-workstation-17.5.0
  tar -cf vmmon.tar vmmon-only && tar -cf vmnet.tar vmnet-only 
  sudo cp -v vmmon.tar vmnet.tar /usr/lib/vmware/modules/source
  sudo vmware-modconfig --console --install-all history
  ```
> * **Visual Studio Code**
>   - Extensions:
>     - [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)
>     - [Roo Cline](https://marketplace.visualstudio.com/items?itemName=RooVeterinaryInc.roo-cline)
>     - [Cline](https://marketplace.visualstudio.com/items?itemName=saoudrizwan.claude-dev)
>     - [Continue](https://marketplace.visualstudio.com/items?itemName=Continue.continue)
>     - [Codeium](https://marketplace.visualstudio.com/items?itemName=Codeium.codeium)
>     - [Tabby](https://marketplace.visualstudio.com/items?itemName=TabbyML.vscode-tabby)
>     - [Docker](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-docker)
>     - [Python Environment Manager](https://marketplace.visualstudio.com/items?itemName=donjayamanne.python-environment-manager)
  ```bash
  wget -qO $HOME/Downloads/vscode.latest.deb https://go.microsoft.com/fwlink/?LinkID=760868
  chmod +x $HOME/Downloads/vscode.latest.deb
  sudo dpkg -i $HOME/Downloads/vscode.latest.deb
  ```
> * **Windsurf**
  ```bash
  curl -fsSL "https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/windsurf.gpg" | sudo gpg --dearmor -o /usr/share/keyrings/windsurf-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/windsurf-stable-archive-keyring.gpg arch=amd64] https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/apt stable main" | sudo tee /etc/apt/sources.list.d/windsurf.list > /dev/null
  sudo nala update && sudo nala install windsurf -y
  ```
> * **Tabby.sh**
  ```bash
  wget -qO $HOME/Downloads/tabby.sh.latest.deb https://github.com/Eugeny/tabby/releases/download/v1.0.216/tabby-1.0.216-linux-x64.deb
  chmod +x $HOME/Downloads/tabby.sh.latest.deb
  sudo dpkg -i $HOME/Downloads/tabby.sh.latest.deb
  ```

#### Install Video Download Helper Companion 
```bash
curl -sSLf https://github.com/aclap-dev/vdhcoapp/releases/latest/download/install.sh | bash
```

#### Add Missing Keys
Open **Software Sources** -> click **Maintenance** -> click **Add Missing Keys**. Once finished click Update apt cache.

#### Setting Preferred Date Format
Use **%A - %B %d,  %Y %I:%M:%S %p** as preferred date format.


#### Setting Up Online Accounts
When setting up **Online Accounts** keep in mind that you must be using the **Nouveou** video drivers because clicking Google in the providers list will not trigger the browser page to load if using Nvidia proprietary drivers. Use Nouveou drivers while getting online accounts set up and once finished switch back to using the **Nvidia** drivers via the **Driver Manager**


#### Identifying IOMMU Groups and PCI Device Bus IDS

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

#### Assigning PCI Devices to VFIO

Next we plug the bus ids ( xxxx:xxxx ) of the devices we want to pass to our virtual machine into vfio_pci.ids= as a comma delimited list

```bash
sudo nano /etc/default/grub
```

In this file we'll update the `GRUB_CMDLINE_LINUX_DEFAULT` line to the following. We use `amd_iommu=on` to enable AMD's IOMMU (Input/Output Memory Management Unit), `amd_iommu=pt` to enable IOMMU pass-through mode, `vfio_pci.ids` for the specified device bus ids to be bound to the VFIO-PCI driver at boot, and `kvm.ignore_msrs=1` to tell KVM (Kernel-based Virtual Machine) to ignore unhandled Model Specific Registers access.

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

#### Switching Drivers On the Fly Using DriverCTL

After reboot we should be able to target the devices to switch drivers on the fly by using the following as examples

*This command is tells the system to use the NVIDIA driver for the targetted GPU without saving the change permanently. This will make the targetted GPU available to the Linux host with Nvidia drivers, and unavailable to  the virtual machine. It will not work if you're using Nouveau drivers, only if you're using the proprietary Nvidia drivers.*

```bash
sudo driverctl --nosave set-override 0000:24:00.0 nvidia
```

*This command is tells the system to use vfio-pci for the targetted GPU without saving the change permanently. This will make the targetted GPU available to the virtual machine, and unavailable to the Linux host to use.*

```bash
sudo driverctl --nosave set-override 0000:24:00.0 vfio-pci
```

*This command is tells the system to use the Nouveau driver for the targetted GPU without saving the change permanently. This will make the targetted GPU available to the Linux host with Nouveau drivers, and unavailable to the virtual machine. It will not work if you're using Nvidia drivers, only if you're using the Nouveau drivers.*

```bash
sudo driverctl --nosave set-override 0000:24:00.0 nouveau
```

#### Identifying Physical Disks and Disk Partitions

Now we need to get the names of our physical disks. In my case I have between 4 and 5 different SSDs. I'll run the following and copy the output to a text file for later reference.

```bash
ls -l /dev/disk/by-id/
```

*We should see output like the following:*

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

From the list we find the physical disk that we want to passthrough to the guest OS. In my case I'm going to be installing Windows 10 directly to the Samsung SSD 970 Pro, using the Samsung SSD 850 Pro for my video games and general storage, and the Samsung SSD 830 for Acronis backups of the Windows guest os drive.

    /dev/disk/by-id/nvme-Samsung_SSD_970_PRO_512GB_S5JYNS0N709889V
    /dev/disk/by-id/ata-Samsung_SSD_850_PRO_1TB_S3D2NX0HA09737Z
    /dev/disk/by-id/ata-SAMSUNG_SSD_830_Series_S0Z3NSACA01314

Now we create the actual Virtual Machine itself in Virtual Machine Manager. This is a whole process in itself but to summarize, create the virtual machine and specify our Windows 10 installation media, typically an ISO so when the machine first boots we can start the installation process.

#### Configurating Virtual Machine

**LINUX HOST:**
Make sure we install all of the various bits we'll need to build the Looking Glass client application and audio working via Scream.

```bash
sudo nala install -y binutils-dev cmake fonts-freefont-ttf libsdl2-dev libsdl2-ttf-dev libspice-protocol-dev libfontconfig1-dev libx11-dev nettle-dev libxpresent-dev libpipewire-0.3
```

Let's build the Looking Glass ( https://looking-glass.io/downloads ) client application ( looking-glass-client ) that will listen for the Windows guest video memory buffer. Once we've built it, the path to the client will be `$HOME/.virtualmachine/LookingGlass/client/build/looking-glass-client`. I used the Version: B7-rc1 client available from https://looking-glass.io/artifact/rc/source by downloading it and extracting it's contents to my `$HOME/.virtualmachine/LookingGlass` directory however otherwise we'd use the git directly.

```bash
mkdir -p $HOME/.virtualmachine/LookingGlass
git clone --recursive https://github.com/gnif/LookingGlass.git $HOME/.virtualmachine/LookingGlass
cd $HOME/.virtualmachine/LookingGlass
mkdir -p client/build
cd client/build
cmake ../
sudo make install
```

Now we need to make an update to QEMU for SHM for capturing the Looking Glass host video memory buffer.

```bash
touch /dev/shm/looking-glass
sudo chown owner:kvm /dev/shm/looking-glass
sudo chmod 660 /dev/shm/looking-glass
```

Let's build the Scream client application that will listen for the Windows guest audio over the virtual network bridge. Once we've built it, the path to the client will be `$HOME/.virtualmachine/Scream/Receivers/unix/client/build/scream`

```bash
mkdir -p $HOME/.virtualmachine/Scream
git clone --recursive https://github.com/duncanthrax/scream.git $HOME/.virtualmachine/Scream
cd $HOME/.virtualmachine/Scream/Receivers/unix
mkdir -p client/build
cd client/build
cmake ../../
sudo make install
```

Add the following to the contents of the libvirt-qemu file and restart apparmor.

```bash
sudo nano /etc/apparmor.d/abstractions/libvirt-qemu
```

Then we'll paste the following contents at the end of the file, then save our changes.

    /{dev,run}/shm/ rw,
    /{dev,run}/shm/* rw,

Now we need to restart the apparmor service.

```bash
sudo systemctl restart apparmor
```

#### Virtual Machine Settings

**Linux Host:**

VM Name is theseus

* Memory (RAM): 65536
* Sound ich9: HDA (ICH9)
* Overview -> Hypervisor Details
    * Firmware: UEFI x86_64: /usr/share/OVMF/OVMF_CODE.fd
    * Chipset: i440FX
* Virtual Network Interface -> Network source
    * Virtual network 'default' : NAT
* Add Hardware -> Storage -> Select or Create Custom Storage
    * Manage: /dev/disk/by-id/nvme-Samsung_SSD_970_PRO_512GB_S5JYNS0N709889V
    * Device Type: Disk device
    * Bus type: SATA
* Add Hardware -> PCI Host Device
    * 0000:01:00:0 NVIDIA Corporation GP102 [GeForce GTX 1080 Ti]
* Add Hardware -> PCI Host Device
    * 0000:01:01:1 NVIDIA Corporation GP102 HDMI Audio Controller
* Add Hardware -> PCI Host Devices
    * 0000:28:00:0 Intel Corporation Wi-Fi 6 AX200
* CPUs -> Configuration
    * Current Allocation: 24
    * Model: host-passthrough


Open Virsh Manager
* Click **Edit** and select **Preferences**
* **Check** the box for **Enable XML editing**, click **Close**
* Click **Create a New Virtual Machine**
* Select **Manual Install**, click **Forward**
* Enter **Microsoft Windows 10**, click **Forward**
* For **Memory** enter **65536**, **CPUs** enter **24**, click **Forward**
* **Uncheck** the box to disable **Enable storage for this virtual machine**, click **Forward**
* **Name** enter **Theseus**, **check** the box to enable **Customize configuration before install**, click **Finish**
* For the Theseus virtual machine click the **XML** tab, and copy the value of the xml `domain` -> `uuid` element. For example mine was `7236d45b-72d5-41f5-b7b3-5a16cb2fc6eb`
* Replace the value for `domain` -> `uuid` element in the following with the value you copied
* Replace the value for `domain` -> `sysinfo` -> `system` -> `entry name="uuid"` element in the following with the value you copied

```
<domain type="kvm">
  <name>theseus</name>
  <uuid>7236d45b-72d5-41f5-b7b3-5a16cb2fc6eb</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://microsoft.com/win/10"/>
    </libosinfo:libosinfo>
  </metadata>
  <memory unit="KiB">67108864</memory>
  <currentMemory unit="KiB">67108864</currentMemory>
  <vcpu placement="static">24</vcpu>
  <cputune>
    <vcpupin vcpu="0" cpuset="4"/>
    <vcpupin vcpu="1" cpuset="20"/>
    <vcpupin vcpu="2" cpuset="5"/>
    <vcpupin vcpu="3" cpuset="21"/>
    <vcpupin vcpu="4" cpuset="6"/>
    <vcpupin vcpu="5" cpuset="22"/>
    <vcpupin vcpu="6" cpuset="7"/>
    <vcpupin vcpu="7" cpuset="23"/>
    <vcpupin vcpu="8" cpuset="8"/>
    <vcpupin vcpu="9" cpuset="24"/>
    <vcpupin vcpu="10" cpuset="9"/>
    <vcpupin vcpu="11" cpuset="25"/>
    <vcpupin vcpu="12" cpuset="10"/>
    <vcpupin vcpu="13" cpuset="26"/>
    <vcpupin vcpu="14" cpuset="11"/>
    <vcpupin vcpu="15" cpuset="27"/>
    <vcpupin vcpu="16" cpuset="12"/>
    <vcpupin vcpu="17" cpuset="28"/>
    <vcpupin vcpu="18" cpuset="13"/>
    <vcpupin vcpu="19" cpuset="29"/>
    <vcpupin vcpu="20" cpuset="14"/>
    <vcpupin vcpu="21" cpuset="30"/>
    <vcpupin vcpu="22" cpuset="15"/>
    <vcpupin vcpu="23" cpuset="31"/>
  </cputune>
  <sysinfo type="smbios">
    <bios>
      <entry name="vendor">American Megatrends Inc.</entry>
      <entry name="version">1.80</entry>
      <entry name="date">08/07/2020</entry>
    </bios>
    <system>
      <entry name="manufacturer">Micro-Star International Co., Ltd.</entry>
      <entry name="product">MPG X570 GAMING PRO CARBON WIFI (MS-7B93)</entry>
      <entry name="version">1.0</entry>
      <entry name="serial">K617200036</entry>
      <entry name="uuid">7236d45b-72d5-41f5-b7b3-5a16cb2fc6eb</entry>
      <entry name="sku">MPGX570GAMPROCA</entry>
      <entry name="family">X570 MB</entry>
    </system>
  </sysinfo>
  <os>
    <type arch="x86_64" machine="pc-q35-6.2">hvm</type>
    <loader readonly="yes" type="pflash">/usr/share/OVMF/OVMF_CODE_4M.fd</loader>
    <nvram>/var/lib/libvirt/qemu/nvram/theseus_VARS.fd</nvram>
    <bootmenu enable="yes"/>
    <smbios mode="sysinfo"/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <hyperv mode="custom">
      <relaxed state="on"/>
      <vapic state="on"/>
      <spinlocks state="on" retries="16384"/>
      <vpindex state="on"/>
      <runtime state="on"/>
      <synic state="on"/>
      <stimer state="on"/>
      <reset state="on"/>
      <vendor_id state="on" value="0123756792CD"/>
      <frequencies state="on"/>
    </hyperv>
    <kvm>
      <hidden state="on"/>
    </kvm>
    <vmport state="off"/>
    <smm state="on"/>
    <ioapic driver="kvm"/>
  </features>
  <cpu mode="host-model" check="partial">
    <topology sockets="1" dies="1" cores="12" threads="2"/>
    <feature policy="disable" name="amd-stibp"/>
    <feature policy="require" name="tsc-deadline"/>
    <feature policy="require" name="hypervisor"/>
    <feature policy="require" name="tsc_adjust"/>
    <feature policy="require" name="cmp_legacy"/>
    <feature policy="require" name="perfctr_core"/>
    <feature policy="require" name="virt-ssbd"/>
    <feature policy="disable" name="monitor"/>
    <feature policy="disable" name="x2apic"/>
    <feature policy="require" name="topoext"/>
    <feature policy="require" name="invtsc"/>
    <feature policy="disable" name="svm"/>
  </cpu>
  <clock offset="localtime">
    <timer name="hypervclock" present="yes"/>
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled="no"/>
    <suspend-to-disk enabled="no"/>
  </pm>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="$HOME/Downloads/Windows_10_Pro.iso"/>
      <target dev="sda" bus="sata"/>
      <readonly/>
      <boot order="1"/>
      <address type="drive" controller="0" bus="0" target="0" unit="0"/>
    </disk>
    <disk type="block" device="disk">
      <driver name="qemu" type="raw" cache="none" io="native" discard="unmap"/>
      <source dev="/dev/disk/by-id/nvme-Samsung_SSD_970_PRO_512GB_S5JYNS0N709889V"/>
      <target dev="sdb" bus="sata"/>
      <boot order="2"/>
      <address type="drive" controller="0" bus="0" target="0" unit="1"/>
    </disk>
    <disk type="block" device="disk">
      <driver name="qemu" type="raw" cache="none" io="native" discard="unmap"/>
      <source dev="/dev/disk/by-id/ata-Samsung_SSD_850_PRO_1TB_S3D2NX0HA09737Z"/>
      <target dev="sdc" bus="sata"/>
      <boot order="3"/>
      <address type="drive" controller="0" bus="0" target="0" unit="2"/>
    </disk>
    <disk type="block" device="disk">
      <driver name="qemu" type="raw" cache="none" io="native" discard="unmap"/>
      <source dev="/dev/disk/by-id/ata-SAMSUNG_SSD_830_Series_S0Z3NSACA01314"/>
      <target dev="sdd" bus="sata"/>
      <boot order="4"/>
      <address type="drive" controller="0" bus="0" target="0" unit="3"/>
    </disk>
    <controller type="usb" index="0" model="qemu-xhci" ports="15">
      <address type="pci" domain="0x0000" bus="0x03" slot="0x00" function="0x0"/>
    </controller>
    <controller type="pci" index="0" model="pcie-root"/>
    <controller type="pci" index="1" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="1" port="0x10"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x0" multifunction="on"/>
    </controller>
    <controller type="pci" index="2" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="2" port="0x11"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x1"/>
    </controller>
    <controller type="pci" index="3" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="3" port="0x12"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x2"/>
    </controller>
    <controller type="pci" index="4" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="4" port="0x13"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x3"/>
    </controller>
    <controller type="pci" index="5" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="5" port="0x14"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x4"/>
    </controller>
    <controller type="pci" index="6" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="6" port="0x15"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x5"/>
    </controller>
    <controller type="pci" index="7" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="7" port="0x16"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x6"/>
    </controller>
    <controller type="pci" index="8" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="8" port="0x17"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x7"/>
    </controller>
    <controller type="pci" index="9" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="9" port="0x18"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x0" multifunction="on"/>
    </controller>
    <controller type="pci" index="10" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="10" port="0x19"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x1"/>
    </controller>
    <controller type="pci" index="11" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="11" port="0x1a"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x2"/>
    </controller>
    <controller type="pci" index="12" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="12" port="0x1b"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x3"/>
    </controller>
    <controller type="pci" index="13" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="13" port="0x1c"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x4"/>
    </controller>
    <controller type="pci" index="14" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="14" port="0x1d"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x5"/>
    </controller>
    <controller type="pci" index="15" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="15" port="0x1e"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x6"/>
    </controller>
    <controller type="pci" index="16" model="pcie-to-pci-bridge">
      <model name="pcie-pci-bridge"/>
      <address type="pci" domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
    </controller>
    <controller type="sata" index="0">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x1f" function="0x2"/>
    </controller>
    <controller type="virtio-serial" index="0">
      <address type="pci" domain="0x0000" bus="0x04" slot="0x00" function="0x0"/>
    </controller>
    <interface type="network">
      <mac address="52:54:00:6f:35:a7"/>
      <source network="default"/>
      <model type="e1000e"/>
      <address type="pci" domain="0x0000" bus="0x02" slot="0x00" function="0x0"/>
    </interface>
    <serial type="pty">
      <target type="isa-serial" port="0">
        <model name="isa-serial"/>
      </target>
    </serial>
    <console type="pty">
      <target type="serial" port="0"/>
    </console>
    <channel type="spicevmc">
      <target type="virtio" name="com.redhat.spice.0"/>
      <address type="virtio-serial" controller="0" bus="0" port="1"/>
    </channel>
    <input type="mouse" bus="virtio">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x0d" function="0x0"/>
    </input>
    <input type="keyboard" bus="virtio">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x0c" function="0x0"/>
    </input>
    <input type="mouse" bus="ps2"/>
    <input type="keyboard" bus="ps2"/>
    <graphics type="spice" autoport="yes">
      <listen type="address"/>
      <image compression="off"/>
    </graphics>
    <sound model="ich9">
      <audio id="1"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x1b" function="0x0"/>
    </sound>
    <audio id="1" type="spice"/>
    <video>
      <model type="vga" vram="16384" heads="1" primary="yes"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x01" function="0x0"/>
    </video>
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x0000" bus="0x24" slot="0x00" function="0x0"/>
      </source>
      <address type="pci" domain="0x0000" bus="0x05" slot="0x00" function="0x0"/>
    </hostdev>
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x0000" bus="0x24" slot="0x00" function="0x1"/>
      </source>
      <address type="pci" domain="0x0000" bus="0x06" slot="0x00" function="0x0"/>
    </hostdev>
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x0000" bus="0x28" slot="0x00" function="0x0"/>
      </source>
      <address type="pci" domain="0x0000" bus="0x10" slot="0x01" function="0x0"/>
    </hostdev>
    <redirdev bus="usb" type="spicevmc">
      <address type="usb" bus="0" port="1"/>
    </redirdev>
    <redirdev bus="usb" type="spicevmc">
      <address type="usb" bus="0" port="2"/>
    </redirdev>
    <memballoon model="virtio">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x0a" function="0x0"/>
    </memballoon>
    <shmem name="looking-glass">
      <model type="ivshmem-plain"/>
      <size unit="M">128</size>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x0b" function="0x0"/>
    </shmem>
  </devices>
</domain>
```
* **Paste the full XML content with the replacements you've made** into the XML tab clearing any content that was originally in the tab. Click **Apply**


To launch LookingGlass
```bash
    $HOME/.virtualmachine/LookingGlass/client/build/looking-glass-client
```
To launch Scream
```bash
    $HOME/.virtualmachine/Scream/Receivers/unix/client/build/scream -i virbr0
```

Creating a bash script called theseus.sh to tie it all together, When ran in a console or made executable, it will perform all the necessary tasks to start the virtual machine, initiate Looking Glass and connect Scream
```bash
nano $HOME/.virtualmachine/thesus.sh
```
	#!/bin/bash
	
	tmp=$(virsh list --all | grep " theseus " | awk '{ print $3}')
	if ([ "x$tmp" == "shut" ] || [ "x$tmp" != "xrunning" ])
	then
	    sudo rm -f /dev/shm/looking-glass
	    touch /dev/shm/looking-glass
	    sudo chown owner:kvm /dev/shm/looking-glass
	    sudo chmod 660 /dev/shm/looking-glass
	    virsh start theseus
	    sleep 25
	fi
	$HOME/.virtualmachine/LookingGlass/client/build/looking-glass-client app:shmFile=/dev/shm/looking-glass win:showFPS=yes win:keepAspect=yes win:maximize=yes win:size=4096x2160 win:borderless=yes win:title=Theseus >/dev/null 2>&1 &
	$HOME/.virtualmachine/Scream/Receivers/unix/client/build/scream -v -i virbr0 >/dev/null 2>&1 &
	wait -n
	pkill -P $$


Update permissions of the theseus.sh bash script to allow executing it.

```bash
chmod +x $HOME/.virtualmachine/thesus.sh
```

To launch our Theseus windows virtual machine
```bash
$HOME/.virtualmachine/thesus.sh
```
 
### Configuring Windows Guest

**WINDOWS GUEST:**

Finish installation, and run updates. Now we need to download https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/upstream-virtio/virtio-win10-prewhql-0.1-161.zip and extract the contents, look in the **Devices and Hardware** for anything that's missing a driver, and install drivers from the location of the virtio-win10 folder that we extracted. Next in **Devices and Hardware**, look for **PCI standard RAM Controller** and update the drivers for this device with drivers from the virtio-win10 folder as well so that Windows will see IVSHMEM device. Update any drivers that are missing under **System Devices** or **Human Interface Devices** from the virtio-win10 folder as well.

#### Installing Looking Glass Host

We now need to get the Looking Glass host set up in the Windows guest. In the Windows guest go to https://looking-glass.hostfission.com/downloads and download the looking glass host **4d45b380**, extract and run the setup file, specify location for install as `C:\Users\owner\.virtualmachine\LookingGlass` and make sure the the checkbox is toggled on for service installation option. I used version Version: B7-rc1 available at https://looking-glass.io/artifact/rc/host.

#### Installing Scream Host

Let's download the latest non-source zip of Scream from https://github.com/duncanthrax/scream/releases/latest and extract the folder called `Install` from it to the `C:` drive. Before installing, we need to change our Windows date to 2022 or prior in otherwise we will encounter an error during install due to a certificate being expired, see - https://github.com/duncanthrax/scream/issues/218.

Run cmd as administrator

```bash
C:\Install\Install-x64.bat
```

Install official GPU drivers for the GPU that was passed through, in my case Nvidia's GeForce experience and then the Nvidia drivers. Reboot the Windows guest and double check to make sure to set the audio output to Scream.

Plug in hdmi dummy plug into the GPU that the Windows guest will be using so that the passed through GPU will recognize that a display is connected. I used a 4k capable hdmi dummy plug.

Disable Basic Display Adapter in devices and restart the virtual machine. This step is imperative because if we do not disable the Basic Display Adaptor, the passed through GPU will not activate and it needs to activate in order for the Looking Glass host application  to run


#### Additional Notes
If you have issues with any audio ports not showing up in Linux
alsamixer
F6 to select the audio device you want to configure
Press LEFT and RIGHT arrow keys to navigate between inputs and options
Press M to unmute any inputs which have an MM
If Auto Mute option is enabled, navigate to it an hit the DOWN arrow key to diable it
sudo alsactl store
pulseaudio -k && sudo alsa force-reload
Unplug the previous affected inputs and plug them back in

Getting system information for Linux host
* lshw
* lscpu
* lspci
* lsscsi
* lsusb
* lsblk
* df -h
* fdisk -l
* dmesg


#### Monitor Nvidia GPU temps for host
```bash
watch -n 2 nvidia-smi
```

#### Monitor CPU temps for host
```bash
watch -n 2 sensors
```

