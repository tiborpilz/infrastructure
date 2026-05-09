output "url" {
  description = "Public HTTPS URL for the smoke app. Should return nginx's default page."
  value       = "https://${local.hostname}"
}

output "hostname" {
  description = "Fully-qualified hostname."
  value       = local.hostname
}
