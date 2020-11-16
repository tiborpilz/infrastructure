# Infrastructure scaffolding using Jsonnet

At the heart, this uses a single jsonnet file to create a terraform config as well as a rke cluster.yml to scaffold a kubernetes cluster. Once set up, the manifests in `k8s` can be used to improve the cluster infrastructure with automatic load-balancing services (using the metallb layer 2 load balancer), certificate retrieval via Let's Encrypt, Persistent Volumes and a storage driver using Ceph distributed storage, automated DNS entries and ArgoCD for single-source-of-truth cluster deployments.

Even though the configuration is currently set to deploy Hetzner Cloud VMs, this will work on (almost) any combination of infrastructure, from a single Bare Metal server spawning it's own VMs with solutions like Proxmox to Cloud solutions.

Oh and also, this is a personal learning project, you should not touch this with a ten foot pole if it should have anything to do with production services as I barely know what I'm doing.
