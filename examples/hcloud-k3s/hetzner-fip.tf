resource "null_resource" "fip" {
  depends_on = [
    null_resource.kubeconfig
  ]
  
  count      = var.install_fip_controller ? 1 : 0
  
  triggers = {
    cluster_master_ids = "${join(",", hcloud_server.server.*.id)}"
    k3s_ip = "${join(",", hcloud_floating_ip.k3s.*.id)}"
    always_run = var.install_fip_controller ? "${timestamp()}" : 0
  }  
  
  provisioner "local-exec" {
    environment = {
      KUBECONFIG = "./.kubeconfig/k3s.yaml"
    }
    command = "kubectl apply -f ./fip.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl delete -f ./fip.yaml --kubeconfig=./.kubeconfig/k3s.yaml"
    when = destroy
    on_failure = continue
  }
}

resource "local_file" "fip_config" {
  depends_on = [
    module.k3s,
  ]
  filename = "${path.module}/fip_config.yaml"
  content = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: fip-controller-config
  namespace: fip-controller
data:
  config.json: |
    {
      "hcloud_floating_ips": [ "${join(",", hcloud_floating_ip.k3s.*.ip_address)}" ],
      "node_address_type": "external",
      "hcloud_api_token": "${var.hcloud_token}"
    }
---
apiVersion: v1
kind: Secret
metadata:
  name: fip-controller-secrets
  namespace: fip-controller
stringData:
  HCLOUD_API_TOKEN: ${var.hcloud_token}
YAML
  }

resource "null_resource" "fip_config" {
  depends_on = [
    null_resource.fip
  ]
  count  = var.install_fip_controller ? 1 : 0
  triggers = {
    metallb_config = md5(local_file.fip_config.content)
  }
  provisioner "local-exec" {
    environment = {
      KUBECONFIG = "./.kubeconfig/k3s.yaml"
    }
    command = "kubectl apply -f ${local_file.fip_config.filename}"
  }
  provisioner "local-exec" {
    command = "kubectl delete -n fip-controller configmap config --kubeconfig=./.kubeconfig/k3s.yaml"
    when = destroy
    on_failure = continue
  }
}


resource "local_file" "floating_ip_cfg" {
  depends_on = [
    null_resource.fip
  ]
  count  = var.install_fip_controller ? 1 : 0
  
  filename = "${path.module}/60-floating-ip.cfg"
  content = <<TXT
%{ for key, fip in tolist(hcloud_floating_ip.k3s) }
auto eth0:${key + 1}
iface eth0:${key + 1} inet static
  address ${fip.ip_address}
  netmask 32 %{ endfor }
TXT
  }


resource "null_resource" "install_ip_cfg_master" {
  depends_on = [
    null_resource.fip,
    hcloud_server.server
  ]
  count  = var.install_fip_controller ? 1 : 0  
  
  triggers = {
    floating_ip_config = md5(join(",",local_file.floating_ip_cfg.*.content))
  }

  connection {
    host     = hcloud_server.server.ipv4_address
  }
    
  
  provisioner "file" {
    source      = "./60-floating-ip.cfg"
    destination = "/etc/network/interfaces.d/60-floating-ip.cfg"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo systemctl restart networking.service",
    ]
  }
}

resource "null_resource" "install_ip_cfg_agents" {
  depends_on = [
    null_resource.fip,
    hcloud_server.agents
  ]
  
  for_each    = var.install_fip_controller ? {for agent in hcloud_server.agents: agent.name => agent} : {}
  
  triggers = {
    floating_ip_config = md5(join(",",local_file.floating_ip_cfg.*.content))
  }

  connection {
    host     =  each.value.ipv4_address
  }
    
  
  provisioner "file" {
    source      = "./60-floating-ip.cfg"
    destination = "/etc/network/interfaces.d/60-floating-ip.cfg"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo systemctl restart networking.service",
    ]
  }
}