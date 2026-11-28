{ config, lib, pkgs, ... }:

{
  # NixOS system configuration for the Hostinger KVM template.
  # Built into a qcow2 by image.nix via nixpkgs' make-disk-image (no nixos-infect).
  imports = [ ./hardware-configuration.nix ];

  # BIOS/SeaBIOS GRUB on the single legacy (MBR) disk. `device` is the VPS disk (scsi0),
  # used when the customer runs nixos-rebuild; image.nix overrides it for the build VM.
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    efiSupport = false;
    timeout = 1;
  };

  # Root is the single labelled partition make-disk-image creates; grow it to the
  # provisioned disk size on first boot (Hostinger plans resize the disk).
  boot.growPartition = true;

  # Serial console for Proxmox serial0 + memory hotplug, mirroring GRUB_CMDLINE_LINUX
  # in the other templates.
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200"
    "earlyprintk=ttyS0,115200"
    "consoleblank=0"
    "memhp_default_state=online"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };

  networking.hostName = "gestirn";
  # cloud-init owns IP assignment, so DHCP must be off (otherwise it races cloud-init).
  networking.useDHCP = lib.mkForce false;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  time.timeZone = "Europe/Warsaw";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.nettzsu = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = builtins.filter (key: key != "")
      (lib.splitString "\n" (builtins.readFile ./authorized_keys));
  };
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = lib.mkDefault "yes";
  };

  # QEMU guest agent: how Proxmox/hVPS talk to the VM (udev-started qemu-guest-agent.service).
  services.qemuGuest.enable = true;

  # Provisioning via the Proxmox cloud-init drive (ide2), same as every other template.
  # Proxmox exposes config through the NoCloud datasource; pin it (NixOS ships no default).
  services.cloud-init = {
    enable = true;
    network.enable = true;
    settings = {
      datasource_list = [ "NoCloud" "ConfigDrive" ];
      preserve_hostname = true;
      # The keys-to-console module's helper (write-ssh-key-fingerprints) isn't shipped in NixOS's
      # cloud-init package, so it errors and downgrades cloud-init to "degraded done" (exit 2).
      # It only prints host-key fingerprints to the console — disable it for a clean exit 0.
      ssh.emit_keys_to_console = false;
    };
  };

  # hVPS drives provisioning by running bare-name commands (sh, cloud-init, chpasswd, ...)
  # through the guest agent, which resolves them on the *agent's* PATH. NixOS gives services a
  # minimal PATH and keeps `sh` only in /bin, so point the agent at the full system environment
  # (setuid wrappers + system path + /bin for sh). Without this, provisioning fails with e.g.
  # "cloud-init: No such file or directory" or "sh: No such file or directory".
  # cloud-init (provisioning CLI) plus the common tools the Debian/Ubuntu templates ship and
  # that hVPS verification invokes by bare name (e.g. `dig` for a DNS check).
  environment.systemPackages = with pkgs; [
    cloud-init
    dnsutils
    nettools
    curl
    wget
    nano
    vim
    git
    fastfetch
    htop
  ];
  systemd.services.qemu-guest-agent.environment.PATH =
    lib.mkForce "/run/wrappers/bin:/run/current-system/sw/bin:/bin";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.stateVersion = "26.05";
}
