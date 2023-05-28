#cloud-config

package_update: false
package_upgrade: false
package_reboot_if_required: false

manage-resolv-conf: true
resolv_conf:
  nameservers:
    - '1.1.1.1'
    - '8.8.8.8'
packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg-agent
  - software-properties-common

runcmd:
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  - add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  - apt-get update -y
  - apt-get install -y docker-ce docker-ce-cli containerd.io
  - systemctl start docker
  - systemctl enable docker

final_message: "The system is finally up, after $UPTIME seconds"
