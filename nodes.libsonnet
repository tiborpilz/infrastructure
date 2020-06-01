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

control_nodes + worker_nodes
