resource null_resource kubeconfig {

  depends_on       = ["null_resource.key_wait"]

  triggers = {
    cluster_master_ids = "${join(",", hcloud_server.server.*.id)}"
    cluster_agent_ids = "${join(",", hcloud_server.agents.*.id)}"
  }  
  
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${element(hcloud_server.server.*.ipv4_address, 0)}:/etc/rancher/k3s/k3s.yaml ./.kubeconfig"
  }
  provisioner "local-exec" {
    command = "sed -i 's/127.0.0.1/${element(hcloud_server.server.*.ipv4_address, 0)}/g' ./.kubeconfig/k3s.yaml"
  }
}