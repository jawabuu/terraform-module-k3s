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
      "hcloud_floating_ips": [ "${join(",", hcloud_floating_ip.k3s.*.id)}" ],
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