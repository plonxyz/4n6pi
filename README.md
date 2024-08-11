# 4n6pi

<p align="center">
  <img src="https://github.com/plonxyz/4n6pi/blob/main/4n6pi_logo.jpg" alt="4n6pi Logo">
</p>

4n6pi is a forensic imager for disks, designed to run on a Raspberry Pi powered by [libewf](https://github.com/libyal/libewf). It provides a simple and portable solution for creating disk images in forensic investigations.

## Features

- Easy setup using a configuration stick
- Automated imaging process
- Visual status indication via Raspberry Pi's ACT LED / optional LCD display
- Automatic VPN connection through wireguard, just drop the wg0.conf onto the config stick
- LAN connection via Ethernet or Wifi
- Console access via UART
- @geerlingguy 's modified version of [rpi-clone](https://github.com/geerlingguy/rpi-clone) for cloning to PCIe connected SSD 
- Acquire modes:
   - Disk Mode (creating .E01 image on external hard disk)
   - S3 Mode (creating .E01 image on internal SSD/SDcard and pushing to S3 bucket)
   - NFS Mode (creating .E01 image directly on NFS share)

## Requirements

- Raspberry Pi 5
- USB storage device for configuration file
- Power supply for Raspberry Pi
- (Recommended for S3 mode) PCIe SSD Base / Hat
- (Recommended for Disk Mode; providing dedicated USB power) [USB 3.2 Gen1 HUB HAT from Waveshare](https://www.waveshare.com/product/usb-3.2-gen1-hub-hat.htm) 

## Setup and Usage

1. Create a configuration stick:
   - Download and run `create-configstick.sh` from this repository
   - Modify `Imager_config.yaml` as needed

2. Burn the image to an SD card:
   - Use Raspberry Pi Imager to set hostname and console password (default hostname: 4n6pi / username: pi , password: 4n6pi)

3. Prepare the Raspberry Pi:
   - Insert the configuration USB stick into a USB2.0 port
   - Power on the Pi and wait for the green ACT LED to turn off

4. Connect the target disk:
   - Connect the target disk to the top USB3.0 port
   - For Disk Mode, use bottom USB3.0 for destination disk
   - When using Waveshare USB header, refer to the image below:

<p align="left">
  <img src="https://github.com/plonxyz/4n6pi/blob/main/weaveshare-HAT.jpg" alt="Waveshare USB header">
</p>

5. Start imaging:
   - Process starts automatically
   - ACT LED blinks during imaging

6. Monitor progress:
   - Wait for ACT LED to stop blinking

## Status Indicators

- Solid green ACT LED: System booting
- LED off: System ready or imaging complete
- Blinking green ACT LED: Imaging in progress

LCD display (if connected) will show current state.

## Troubleshooting

If issues occur:
- Check all connections
- Verify configuration stick creation
- Login via ssh (ssh-key needed) or via console to check system logs at `/var/log/acquire.log` and `/var/log/handler.log`

## Contributing

Contributions welcome! Submit pull requests or open issues for improvements or bug reports.

## Acknowledgements

Thanks to all contributors, especially:
- [@andrewkempster](https://x.com/@andrewkempster) for testing and verifying forensic soundness
- Nufi for valuable ideas and suggestions

## Disclaimer and License

4n6pi is provided as-is, without any warranty. Its methodology has been vetted by forensic experts to be forensically sound, but always verify the integrity of your images using appropriate forensic tools and procedures.

4n6pi is free software, distributed under the GNU General Public License v3 or later. You can redistribute and/or modify it under the terms of this license. While I hope it's useful, it comes with no warranty or guarantee of fitness for any purpose. For full license details, see <https://www.gnu.org/licenses/>.

## Support the Project

If you find this project useful, consider buying me a coffee. Thank you!

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/plonxyz)
