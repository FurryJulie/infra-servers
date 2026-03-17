{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "/dev/sda" ];
}
