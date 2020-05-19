resource "null_resource" "metallb" {
  depends_on = [
    null_resource.kubeconfig
  ]
  
  triggers = {
    cluster_master_ids = "${join(",", hcloud_server.server.*.id)}"
    cluster_agent_ids = "${join(",", hcloud_server.agents.*.id)}"
  }  
  
  provisioner "local-exec" {
    environment = {
      KUBECONFIG = "./.kubeconfig/k3s.yaml"
    }
    command = "kubectl apply -f ./metallb.yaml && kubectl apply -f ./net-tools.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl delete -f ./metallb.yaml --kubeconfig=./.kubeconfig/k3s.yaml"
    when = destroy
    on_failure = continue
  }
}

resource "local_file" "metallb_config" {
  depends_on = [
    module.k3s,
  ]
  filename = "${path.module}/metallb_config.yaml"
  content = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:%{ if var.install_fip_controller }
    - name: floating_ip
      protocol: layer2
      avoid-buggy-ips: true      
      addresses:
      - ${hcloud_floating_ip.k3s[0].ip_address}/32
      auto-assign: true %{ endif }
    - name: default
      protocol: layer2
      avoid-buggy-ips: true
      addresses:
      - ${hcloud_server.server.ipv4_address}/32
      auto-assign: false
    - name: agents
      protocol: layer2
      avoid-buggy-ips: true      
      addresses:%{ for agent in hcloud_server.agents }
      - ${agent.ipv4_address}/32 %{ endfor }
      auto-assign: false
YAML
  }

resource "null_resource" "metallb_config" {
  depends_on = [
    module.k3s,
    null_resource.metallb
  ]
  triggers = {
    metallb_config = md5(local_file.metallb_config.content)
  }
  provisioner "local-exec" {
    environment = {
      KUBECONFIG = "./.kubeconfig/k3s.yaml"
    }
    command = "kubectl apply -f ${local_file.metallb_config.filename}"
  }
  provisioner "local-exec" {
    command = "kubectl delete -n metallb-system configmap config --kubeconfig=./.kubeconfig/k3s.yaml"
    when = destroy
    on_failure = continue
  }
}