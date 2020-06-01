local nodes = import './nodes.jsonnet';
local ssh_key = importstr './secrets/ssh_key';

{
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
}
