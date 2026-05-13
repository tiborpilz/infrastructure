variable "kubernetes_host" {
  description = "Kubernetes API server URL."
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Cluster CA certificate (PEM)."
  type        = string
  sensitive   = true
}

variable "client_certificate" {
  description = "Kubernetes client certificate (PEM)."
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "Kubernetes client key."
  type        = string
  sensitive   = true
}

variable "kubeconfig_path" {
  description = "Path to a kubeconfig file. Used by readiness wait local-exec calls."
  type        = string
}

variable "platform_data_ready" {
  description = "Sentinel from platform-data. Forces this layer to wait until controllers + StorageClass are present."
  type        = bool
}

variable "operator_revision" {
  description = "Git tag of tektoncd/operator pulled by ArgoCD from `config/base`. Pin to a tested release; bumps require checking CRD compatibility."
  type        = string
  default     = "v0.79.1"
}

variable "components_namespace" {
  description = "Namespace where TektonConfig installs Pipelines/Triggers/Chains/Dashboard."
  type        = string
  default     = "tekton-pipelines"
}

variable "pruner_keep" {
  description = "Number of recent PipelineRuns/TaskRuns to keep before the daily pruner deletes older ones. Defaults to 100; bump if you need longer history."
  type        = number
  default     = 100
}

variable "pruner_schedule" {
  description = "Cron schedule for the Tekton pruner. Default is 08:00 UTC daily."
  type        = string
  default     = "0 8 * * *"
}
