DEFAULT_NEXUS_PORT = "8420"
DEFAULT_REPLICA_PORT = "8430"

def subsysIsDiscoverable(host, ip, port, subsys):
    discoveryResponse = host.succeed("nvme discover -a " + ip + " -t tcp -s " + port)
    return subsys in discoveryResponse
