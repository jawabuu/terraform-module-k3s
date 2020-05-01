provider hcloud {
  token = var.hcloud_token
}

module k3s {
  source = "./../.."

  k3s_version = "latest"
  cluster_cidr = {
    pods     = "10.42.0.0/16"
    services = "10.43.0.0/16"
  }
  drain_timeout = "30s"

  additional_flags = {
    server = [
      #"--disable-cloud-controller",
      "--disable traefik",
      #"--disable servicelb",
      #"--flannel-iface ens10",
      "--flannel-backend=none",
      #"--kubelet-arg cloud-provider=external" # required to use https://github.com/hetznercloud/hcloud-cloud-controller-manager
    ]
    agent = [
      #"--flannel-iface ens10",
    ]
  }

  server_node = {
    name   = "server"
    #name     = hcloud_server_network.server_network.ip 
    ip     = hcloud_server_network.server_network.ip    
    external_ip = hcloud_server.server.ipv4_address
    labels = {}
    taints = {}
    connection = {
      host = hcloud_server.server.ipv4_address
    }
  }

  agent_nodes = {
    for i in range(length(hcloud_server.agents)) :
    "${hcloud_server.agents[i].name}_node" => {
      name = "${hcloud_server.agents[i].name}"
      #name   = hcloud_server_network.agents_network[i].ip
      ip   = hcloud_server_network.agents_network[i].ip
      external_ip = hcloud_server.agents[i].ipv4_address
      labels = {
        "node.kubernetes.io/pool" = hcloud_server.agents[i].labels.nodepool
      }
      taints = {
      #  "dedicated" : hcloud_server.agents[i].labels.nodepool == "gpu" ? "gpu:NoSchedule" : null
      }

      connection = {
        host = hcloud_server.agents[i].ipv4_address
      }
    }
  }
}