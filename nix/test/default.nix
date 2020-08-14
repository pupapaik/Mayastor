#
# TODO: not sure if we need to import the sources
#
let
  sources = import ./../../nix/sources.nix;
  pkgs = import sources.nixpkgs {
    overlays = [
      (_: _: { inherit sources; })
      (import ./../../nix/mayastor-overlay.nix)
    ];
  };
in
{
  fio_nvme_basic = pkgs.nixosTest ./basic/fio_nvme_basic.nix;
  nvmf_ports = pkgs.nixosTest ./nvmf/nvmf_ports.nix;
  nvmf_distributed = pkgs.nixosTest ./nvmf/nvmf_distributed.nix;
}
