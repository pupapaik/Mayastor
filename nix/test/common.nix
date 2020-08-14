{ pkgs, ... }:
{
    defaultMayastorNode = myIp: { config, lib, ... }: {

      virtualisation = {
        memorySize = 4096;
        emptyDiskImages = [ 512 ];
        vlans = [ 1 ];
      };

      boot = {
        kernel.sysctl = {
          "vm.nr_hugepages" = 512;
        };
        kernelModules = [
          "nvme-tcp"
        ];
      };

      networking.firewall.enable = false;
      networking.interfaces.eth1.ipv4.addresses = pkgs.lib.mkOverride 0 [
        { address = myIp; prefixLength = 24; }
      ];

      environment = {
        systemPackages = with pkgs; [
          images.mayastor-develop
          nvme-cli
          fio
        ];

        etc."mayastor-config.yaml" = {
          mode = "0664";
          source = ./default-mayastor-config.yaml;
        };
      };

      systemd.services.mayastor = {
        enable = true;
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        description = "Mayastor";
        environment = {
          MY_POD_IP = myIp;
        };

        serviceConfig = {
          ExecStart = "${pkgs.images.mayastor-develop}/bin/mayastor -g 0.0.0.0:10124 -y /etc/mayastor-config.yaml";
        };
      };
    };
}
