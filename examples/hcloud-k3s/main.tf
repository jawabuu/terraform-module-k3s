provider hcloud {
  token = var.hcloud_token
}

module k3s {
  #source = "./../.."
  source = "./modules/k3s"

  k3s_version = "v1.17.5+k3s1"
  install_calico = true
  cluster_cidr = {
    pods     = "10.42.0.0/16"
    services = "10.43.0.0/16"
  }
  drain_timeout = "30s"

  additional_flags = {
    server = [
      "--disable traefik",
      var.install_calico ? "--disable servicelb" : "--flannel-iface ens10",
      var.install_calico ? "--flannel-backend=none" : "--flannel-iface ens10",
      var.install_cloud_controller ? "--disable-cloud-controller" : "",
      var.install_cloud_controller ? "--kubelet-arg=cloud-provider=external" : ""
      #"--kubelet-arg=cloud-provider=external" # required to use https://github.com/hetznercloud/hcloud-cloud-controller-manager
    ]
    agent = [
      var.install_calico ? "" : "--flannel-iface ens10",
      var.install_cloud_controller ? "--kubelet-arg=cloud-provider=external" : ""
    ]
  }

  server_node = {
    name   = hcloud_server.server.name
    id     = hcloud_server.server.id 
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
      id   = hcloud_server.agents[i].id
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