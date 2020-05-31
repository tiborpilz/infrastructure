local num_worker_nodes = 2;
local num_control_nodes = 1;

local indices_control_nodes = std.range(0, num_control_nodes - 1);
local indices_worker_nodes = std.range(num_control_nodes, num_control_nodes + num_worker_nodes - 1);

local ssh_key = importstr './ssh_key';
local ssh_key_pub = importstr './ssh_key.pub';
local credentials = import './secrets/credentials.libsonnet';

local Node(i=0) = {
  name: 'node' + i,
  hostname: 'node' + i + '.kube.tibor.host',
  user: 'debian',
  ip_external: '5.9.178.' + std.toString(192 + i),
  gw_external: '136.243.40.226',
  role: ['worker'],
  memory: 32768,
  cores: 4,
  worker: 1,
  storage0: '64G',
  storage1: '64G',
  ssh_key: ssh_key,
};

local ControlNode(i=0) = Node(i) + {
  role: ['worker', 'controlplane', 'etcd'],
};

local control_nodes = [
  ControlNode(i)
  for i in indices_control_nodes
];

local worker_nodes = [
  Node(i)
  for i in indices_worker_nodes
];

local nodes = control_nodes + worker_nodes;

local proxmox_node = 'dc12';

local proxmox = {
  pm_api_url: 'https://dc12.tibor.host:8006/api2/json',
  pm_user: 'root@pam',
  pm_password: std.extVar('PM_PASSWORD'),
  pm_parallel: 1,
  pm_tls_insecure: true,
};

local cloudflare = {
  email: 'tibor@pilz.berlin',
  api_token: std.extVar('CLOUDFLARE_API_KEY'),
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
  'main.tf.json': {
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
  },
  'cluster.yml': {
    nodes: [
      {
        address: node.ip_external,
        port: '22',
        role: node.role,
        user: node.user,
        ssh_key: ssh_key,
      }
      for node in nodes
    ],
    addons_include: [
      'https://github.com/jetstack/cert-manager/releases/download/v0.13.0/cert-manager-no-webhook.yaml',
      './addons/letsencrypt-clusterissuer.yaml',
      './addons/ingress-nginx/configmap.yaml',
      'https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.28.0/deploy/static/mandatory.yaml',
      './addons/ingress-nginx/service.yaml',
      'https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml',
      './addons/metallb-config.yaml',
      'https://raw.githubusercontent.com/rook/rook/release-1.3/cluster/examples/kubernetes/ceph/common.yaml',
      'https://raw.githubusercontent.com/rook/rook/release-1.3/cluster/examples/kubernetes/ceph/operator.yaml',
      './addons/rook-ceph/ceph-cluster.yaml',
      './addons/rook-ceph/ingress.yaml',
      './addons/rook-ceph/storageclass-cephfs.yaml',
      'https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.12.1/release.yaml',
      'https://github.com/tektoncd/dashboard/releases/download/v0.6.1.5/tekton-dashboard-release.yaml',
      './addons/tekton/config-artifact-pvc.yaml',
      './addons/external-dns.yaml',
      'https://raw.githubusercontent.com/kubernetes-sigs/application/release-v0.8/deploy/kube-app-manager-aio.yaml',
      './addons/basic-auth.yaml',
    ],
    kubernetes_version: '',
    network: {
      plugin: 'weave',
    },
    authorization: {
      mode: 'rbac',
    },
    ingress: {
      provide: 'none',
    },
  },
}
