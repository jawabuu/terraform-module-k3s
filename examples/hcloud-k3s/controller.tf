resource null_resource install_cloud_controller {
  depends_on = [ null_resource.kubeconfig ]
  count      = var.install_cloud_controller ? 1 : 0

  triggers = {
    cluster_instance_ids = "${join(",", hcloud_server.server.*.id)}"    
    always_run = var.install_cloud_controller ? "${timestamp()}" : 0
  }
  
  provisioner "local-exec" {
    interpreter = [ "bash", "-c" ]
    command = "export KUBECONFIG=./.kubeconfig/k3s.yaml"
  }
  
  # Create hcloud secret
  provisioner "local-exec" {
    command = "kubectl -n kube-system create secret generic hcloud --from-literal=network=${hcloud_network.k3s.id} --from-literal=token=${var.hcloud_token} --dry-run -o yaml | kubectl apply -f -"   
  }
  
  # Create hcloud-csi secret
  provisioner "local-exec" {
    command = "kubectl -n kube-system create secret generic hcloud-csi --from-literal=network=${hcloud_network.k3s.id} --from-literal=token=${var.hcloud_token} --dry-run -o yaml | kubectl apply -f -"   
  }
  
  # Install Hetzner Cloud Controller
  provisioner "local-exec" {
    command = "kubectl apply -f  https://raw.githubusercontent.com/hetznercloud/hcloud-cloud-controller-manager/master/deploy/v1.5.1.yaml"
  }
    
  # Install Flannel Plugin
  provisioner "local-exec" {
    command = "kubectl apply -f  https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
  }
   
  # Patch system critical pods
    provisioner "local-exec" {
    interpreter = [ "bash", "-c" ]
    command = <<EOT
      
    kubectl -n kube-system \
    patch daemonset kube-flannel-ds-amd64 \
    --type json -p '[{"op":"add","path":"/spec/template/spec/tolerations/-","value":{"key":"node.cloudprovider.kubernetes.io/uninitialized","value":"true","effect":"NoSchedule"}}]'
    
    kubectl -n kube-system \
    patch deployment coredns \
    --type json -p '[{"op":"add","path":"/spec/template/spec/tolerations/-","value":{"key":"node.cloudprovider.kubernetes.io/uninitialized","value":"true","effect":"NoSchedule"}}]'
      
EOT
  }
  
  # Install Hetzner CSI Controller
  provisioner "local-exec" {
    command = "kubectl apply -f  https://raw.githubusercontent.com/hetznercloud/csi-driver/master/deploy/kubernetes/hcloud-csi.yml"
  }
  
  
}

