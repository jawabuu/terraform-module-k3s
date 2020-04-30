output "k3s_cluster" {
  value = {
      server = {
          ip       = hcloud_server.server.ipv4_address
          hostname = hcloud_server.server.name
          user     = "root"
      }

      workers = [
          for host in concat(hcloud_server.agents)  : {
              ip       = host.ipv4_address
              hostname = host.name
              user     = "root"
          }
      ]
      
      k3s_ip = hcloud_floating_ip.k3s.*.ip_address
  }
}
