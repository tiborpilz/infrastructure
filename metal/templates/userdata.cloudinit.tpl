#cloud-config

package_update: false
package_upgrade: false
package_reboot_if_required: false

manage-resolv-conf: true
resolv_conf:
  nameservers:
    - '8.8.8.8'
    - '8.8.4.4'
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
  # - apt-get install -y docker-ce=5:19.03.15~3-0~ubuntu-bionic docker-ce-cli=5:19.03.15~3-0~ubuntu-bionic containerd.io
  - apt-get install -y docker-ce docker-ce-cli containerd.io
  - systemctl start docker
  - systemctl enable docker
  %{ if docker_login }
  - docker login -u ${docker_user} -p ${docker_password}
  %{ endif }

final_message: "The system is finally up, after $UPTIME seconds"