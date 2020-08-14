{ pkgs, lib, ... }:
let
  backendIp = "192.168.0.1";
  targetIp = "192.168.0.2";
  initiatorIp = "192.168.0.3";
  common = import ../common.nix { inherit pkgs; };
in
{
  name = "nvmf_against_replica_and_nexus_ports";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ tjoshum ];
  };

  nodes = {
    backend = common.defaultMayastorNode backendIp;
    target = common.defaultMayastorNode targetIp;
    initiator = common.defaultMayastorNode initiatorIp;
  };

  testScript = ''
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "nvmfUtils", "${../mayastorLib/NvmfUtils.py}"
    )
    nvmfUtils = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(nvmfUtils)

    start_all()
    target.wait_for_unit("multi-user.target")
    initiator.wait_for_unit("multi-user.target")

    replicaId = "5b5b04ea-c1e3-11ea-bd82-a7d5cb04b391"
    print(backend.succeed("mayastor-client pool create pool1 /dev/vdb"))
    print(
        backend.succeed(
            "mayastor-client replica create --protocol nvmf --size 64MiB pool1 " + replicaId
        )
    )

    with subtest("discover replica over replica port"):
        assert nvmfUtils.subsysIsDiscoverable(
            backend, "${backendIp}", nvmfUtils.DEFAULT_REPLICA_PORT, replicaId
        )

    with subtest("discover replica over nexus port"):
        assert nvmfUtils.subsysIsDiscoverable(
            backend, "${backendIp}", nvmfUtils.DEFAULT_NEXUS_PORT, replicaId
        )
  '';
}