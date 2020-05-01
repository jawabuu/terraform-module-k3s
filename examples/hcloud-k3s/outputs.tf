output "k3s_cluster" {
  value = {
      server = {
          ip       = hcloud_server.server.ipv4_address
          hostname = hcloud_server.server.name
          user     = "root"
          server   = hcloud_server.server
      }

      workers = [
          for host in concat(hcloud_server.agents)  : {
              ip       = host.ipv4_address
              hostname = host.name
              user     = "root"
              agent    = host
          }
      ]
      
      k3s_ip = hcloud_floating_ip.k3s.*.ip_address
  }
}
