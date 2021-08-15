variable "gitea_admin_user" {}
variable "gitea_admin_password" {}
variable "gitea_admin_email" {}

/* resource "kubectl_manifest" "gitea-application" { */
/*   yaml_body = <<YAML */
/*     apiVersion: argoproj.io/v1alpha1 */
/*     kind: Application */
/*     metadata: */
/*       name: gitea */
/*       namespace: ${helm_release.argocd.namespace} */
/*       finalizers: */
/*         - resources-finalizer.argocd.argoproj.io */
/*     spec: */
/*       destination: */
/*         name: in-cluster */
/*         namespace: gitea */
/*         server: '' */
/*       source: */
/*         path: '' */
/*         repoURL: 'https://dl.gitea.io/charts/' */
/*         targetRevision: 4.0.2 */
/*         chart: gitea */
/*         helm: */
/*           values: | */
/*             ingress: */
/*               enabled: true */
/*               certManager: true */
/*               annotations: */
/*                 cert-manager.io/cluster-issuer: letsencrypt-clusterissuer */
/*               hosts: */
/*               - gitea.${var.domain} */
/*               tls: */
/*               - hosts: */
/*                 - gitea.${var.domain} */
/*                 secretName: gitea.tls */
/*       project: default */
/*       syncPolicy: */
/*         automated: */
/*           prune: true */
/*           selfHeal: true */
/*         syncOptions: */
/*           - CreateNamespace=true */
/*     YAML */
/* } */
/* resource "helm_release" "gitea" { */
/*   name             = "gitea" */
/*   repository       = "https://dl.gitea.io/charts/" */
/*   chart            = "gitea" */
/*   version          = "4.0.2" */
/*   namespace        = "gitea" */
/*   create_namespace = true */
/*   wait             = true */
/*   timeout          = 600 */

/*   set { */
/*     name  = "createCRD" */
/*     value = false */
/*   } */

/*   set { */
/*     name = "helm.versions" */
/*     value = "v3" */
/*   } */

/*   values = [<<EOF */
/*     ingress: */
/*       enabled: true */
/*       certManager: true */
/*       annotations: */
/*         cert-manager.io/cluster-issuer: letsencrypt-clusterissuer */
/*       hosts: */
/*       - host: gitea.${var.domain} */
/*         paths: */
/*         - path: / */
/*           pathType: Prefix */
/*       tls: */
/*       - hosts: */
/*         - gitea.${var.domain} */
/*         secretName: gitea.tls */
/*     EOF */
/*   ] */
/* } */
