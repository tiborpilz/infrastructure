{ modulesPath, pkgs, tangled, ... }:

{
  imports = [ "${modulesPath}/virtualisation/kubevirt.nix" ];

  services.tangled.spindle = {
    enable = true;
    server = {
      hostname = "spindle.tibor.sh";
      owner = "did:plc:uxci5w626xlqmmbkzis5ksww";
    };
    pipelines.microvm = {
      imageDir = toString (pkgs.linkFarm "spindle-microvm-images" {
        nixos = tangled.packages.${pkgs.stdenv.hostPlatform.system}.spindle-nixos-image;
      });
      defaultImage = "nixos";
      overlayDir = "/var/lib/scratch/microvm";
      # Sized to the VirtualMachine's resources: two jobs of the stock image
      # (2 vCPUs, 4 GiB each).
      limits.total = {
        vcpus = 4;
        memoryMiB = 8192;
      };
    };
  };

  virtualisation.docker.daemon.settings.data-root = "/var/lib/scratch/docker";

  systemd.tmpfiles.rules = [ "d /var/lib/scratch/microvm 0755 root root -" ];

  # Disk serials are set on the KubeVirt VirtualMachine.
  fileSystems."/var/lib/spindle" = {
    device = "/dev/disk/by-id/virtio-spindle-state";
    fsType = "ext4";
    autoFormat = true;
  };

  fileSystems."/var/lib/scratch" = {
    device = "/dev/disk/by-id/virtio-scratch";
    fsType = "ext4";
    autoFormat = true;
  };

  networking.hostName = "spindle";

  networking.firewall.allowedTCPPorts = [ 6555 ];

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 7d";
  };

  system.stateVersion = "26.05";
}
