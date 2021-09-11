# resource "kubernetes_manifest" "app-of-apps-application" {
#   manifest = {
#     apiVersion = "argoproj.io/v1alpha1"
#     kind = "Application"
#     metadata = {
#       finalizers = [
#         "resources-finalizer.argocd.argoproj.io",
#       ]
#       name = "app-of-apps"
#       namespace = "argocd"
#     }
#     spec = {
#       destination = {
#         name = "in-cluster"
#         namespace = "applications"
#         server = ""
#       }
#       project = "default"
#       source = {
#         path = "applications/manifests"
#         repoURL = "git@github.com:tiborpilz/infrastructure.git"
#         targetRevision = "HEAD"
#       }
#       syncPolicy = {
#         automated = {
#           prune = true
#           selfHeal = true
#         }
#         syncOptions = [
#           "CreateNamespace=true",
#         ]
#       }
#     }
#   }
#   wait_for = {
#     fields = {
#       "status.health.status" = "Healthy"
#     }
#   }
# }
