resource "null_resource" "key_wait" {
  depends_on       = [module.k3s]
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${element(hcloud_server.server.*.ipv4_address, 0)} 'while true; do if [ ! -f /etc/rancher/k3s/k3s.yaml ]; then sleep 20; else break; fi; done; sleep 20'"    
  }
}