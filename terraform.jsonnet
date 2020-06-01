local nodes = import './nodes.jsonnet';
local credentials = import './secrets/credentials.libsonnet';
local ssh_key = importstr './secrets/ssh_key';
local ssh_key_pub = importstr './secrets/ssh_key.pub';

local proxmox_node = 'dc12';

local proxmox = {
  pm_api_url: 'https://dc12.tibor.host:8006/api2/json',
  pm_user: 'root@pam',
  pm_password: credentials.pm_password,
  pm_parallel: 1,
  pm_tls_insecure: true,
};

local cloudflare = {
  email: 'tibor@pilz.berlin',
  api_token: credentials.cloudflare_api_token,
};

local proxmox_vms = {
  [node.name]: {
    agent: 1,
    name: node.hostname,
    desc: 'Kubernetes Node ' + node.name,
    target_node: proxmox_node,
    full_clone: true,
    clone: 'debian-template',
    pool: 'Kubernetes',
    cores: node.cores,
    sockets: 1,
    memory: node.memory,
    balloon: 0,
    network: [
      {
        id: 0,
        model: 'virtio',
        bridge: 'vmbr0',
      },
    ],
    disk: [
      {
        id: 0,
        type: 'scsi',
        storage: 'vmstore',
        storage_type: 'lvm-thin',
        format: 'raw',
        size: node.storage0,
      },
      {
        id: 1,
        type: 'scsi',
        storage: 'vmstore',
        storage_type: 'lvm-thin',
        format: 'raw',
        size: node.storage1,
      },
    ],
    scsihw: 'virtio-scsi-pci',
    bootdisk: 'scsi0',
    nameserver: '1.1.1.1',
    ciuser: node.user,
    sshkeys: ssh_key_pub,
    os_type: 'cloud-init',
    ipconfig0: 'ip=' + node.ip_external + '/32,gw=' + node.gw_external,
    searchdomain: '.local',

    lifecycle: {
      ignore_changes: ['network'],
    },

    connection: {
      host: node.hostname,
      user: node.user,
      private_key: ssh_key,
    },

    provisioner: [
      {
        'remote-exec': {
          inline: ["sleep 30 && echo 'Connected to ${self.name}'"],
        },
      },
    ],
  }
  for node in nodes
};

{
  terraform: {
    backend: {
      remote: {
        hostname: 'app.terraform.io',
        organization: 'tiborpilz',
        workspaces: {
          name: 'tibor_host',
        },
      },
    },
  },
  provider: {
    proxmox: proxmox,
    cloudflare: {
      email: cloudflare.email,
      api_token: cloudflare.api_token,
    },
  },
  data: {
    cloudflare_zones: {
      tibor_host: {
        filter: {
          name: 'tibor.host*',
        },
      },
    },
  },
  resource: {
    cloudflare_record: {
      [node.name]: {
        zone_id: '${lookup(data.cloudflare_zones.tibor_host.zones[0], "id")}',
        name: node.hostname,
        type: 'A',
        value: node.ip_external,
      }
      for node in nodes
    },
    proxmox_vm_qemu: proxmox_vms,
  },
}
