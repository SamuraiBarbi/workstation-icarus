These are images detailing the BTRFS setup process

Create partition as Primary Partition, set file system to linux-swap, file size 35747
Create partition as Primary Partition, set file system to btrfs, size using the remainder of disk.

Begin setup process
```bash
sudo --preserve-env=DBUS_SESSION_BUS_ADDRESS,XDG_DATA_DIRS,XDG_RUNTIME_DIR,GTK_THEME sh -c 'WEBKIT_DISABLE_COMPOSITING_MODE=1 ubiquity gtk_ui'
```
Welcome Screen, select language and hit Continue
Keyboard Layout Screen, select languages and hit Continue
Multimedia Codecs Screen, check the "Install multimedia codecs" box, and "Configure Secure Boot" box, provide a password, and hit Continue
Installation Type Screen, choose Something Else, and hit Continue
