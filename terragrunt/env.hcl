locals {
  secrets = yamldecode(sops_decrypt_file("${get_repo_root()}/terragrunt/secrets.enc.yaml"))
  env_name     = "hetzernetes"
  cluster_name = local.env_name
  location     = "fsn1"
  network_cidr = "10.0.0.0/16"
  subnet_cidr  = "10.0.0.0/24"

  # Talos version + arch. Single source of truth across machines, cluster,
  # and the upload script.
  # Bump in lockstep with setup/upload-talos-image.sh.
  # If CX43 in hel1 turns out to be ARM, change arch to "arm64" and re-run the upload script.
  talos_version = "1.13.0"
  arch          = "amd64"

  talos_image_labels = {
    os      = "talos"
    version = local.talos_version
    arch    = local.arch
  }

  # Empty list = no firewall created; Talos API (50000) and k8s API (6443)
  # are exposed publicly. Both are mTLS-protected so this is safe-but-noisy.
  # Tighten via VPN/bastion later, then list the gateway CIDR(s) here.
  admin_ip_cidrs = []

  # Networking / DNS / TLS
  domain     = "tibor.sh"
  acme_email = "tibor@pilz.berlin"

  # Shared "no-real-mailbox" address for chart-managed bootstrap admin users
  # (Forgejo's `forgejo_admin`, etc.). Must NOT collide with any managed-user
  # email — Forgejo's ACCOUNT_LINKING=auto and equivalents link OIDC identities
  # to the existing local user with a matching email.
  bootstrap_admin_email = "admin@${local.domain}"

  # Declarative Authentik users. Passwords can be supplied from SOPS
  # later via managed_user_passwords; omitted users receive stable
  # Terraform-generated random passwords.
  platform_admin_groups = [
    "platform-admins",
    "kubernetes-admins",
    "forgejo-admins",
  ]

  # Keep Authentik superuser separate from platform admin rights. Add
  # "platform-admins" here if bootstrap admins should administer Authentik
  # itself, not just downstream apps such as Argo CD and Kubernetes.
  authentik_superuser_groups = [
    "authentik-superusers",
  ]

  managed_users = {
    tibor = {
      name   = "Tibor"
      email  = "tibor@pilz.berlin"
      admin  = true
      groups = ["platform-admins"]
    }

    example = {
      name   = "Tine"
      email  = "tine@olynet.de"
      admin  = true
      groups = []
    }

    # example = {
    #   name   = "Example Admin"
    #   email  = "admin@example.com"
    #   admin  = true
    #   groups = ["forgejo-users"]
    # }
  }

  managed_user_passwords = {
    tibor = local.secrets.authentik_tibor_password
  }

  # Valid dummy PEM material for Terragrunt dependency mocks. Providers parse
  # Kubernetes TLS fields during plan, so plain strings like "mock-ca" fail
  # before the upstream cluster layer has been applied.
  mock_kubernetes_certificate_pem = <<-EOT
    -----BEGIN CERTIFICATE-----
    MIICvjCCAaYCCQC2jQw5Wk6IwDANBgkqhkiG9w0BAQsFADAhMR8wHQYDVQQDDBZ0
    ZXJyYWdydW50LW1vY2stY2xpZW50MB4XDTI2MDUxMDEzNTA0MVoXDTM2MDUwNzEz
    NTA0MVowITEfMB0GA1UEAwwWdGVycmFncnVudC1tb2NrLWNsaWVudDCCASIwDQYJ
    KoZIhvcNAQEBBQADggEPADCCAQoCggEBAOynBXDIjFv6eS7UdOuVQR/6A4HkE30D
    L35fUYL4lcJbG6IK7kpICv3GqA3/FJjhy4D6kKzyJAY0lEOunfM68G+OyLtyyCg/
    q/zMkIjM+weGu2K6Msrt2IsgZFow/xjU76Jb2+EkIx8l5gu4gjca1iopLmEtOXdy
    /S02idjKDH5ST4ZHy5ikYelFfm5cMBjzRYGSPq/nFU2lYUBOVOaKV0KUaTFTw0Bj
    tRfdD04/xQRwAMkWp5YziXI/FWHy0j0onqvhFuBmqeEmhl0ssx2go0VpdILZw0sq
    iTZLvEhTsFuKaX/iErsDxYK+NryTvApjXZ0A8UNRC7QvywrEKvd4IhECAwEAATAN
    BgkqhkiG9w0BAQsFAAOCAQEAEce+U/37yXGZYEDiC0yBi28G/S/M36wiuvt/yGpS
    Yjjj6K31Yzwf2TsgMWw74VxZuXAFo/Ch2kteRgyyK5dPFbxSHZcLmdykIgtZELNA
    1p2TQV/Ja2Ev+/t+TA1F+MijdUCjQbdAmpHCYtGL5GH9JOl9ePBPn85jm81W55iK
    tUJTn1CKYcq0EMF3DLYuXTy2/Wo34g6UWhf8JRIXRUdMkblWd7hmWshUDLUePcLI
    XLxdTGuD1+v4QWlSGhKCPhVWTj1aLSLgJC1GSM6E3ci+7tg8UoUB/LuwEeRHQT08
    8UdIWMQX3XhKhq7x0GJTjKgjPrZNCkiu88zHpx71KmT4hA==
    -----END CERTIFICATE-----
  EOT

  mock_kubernetes_key_pem = <<-EOT
    -----BEGIN PRIVATE KEY-----
    MIIEwAIBADANBgkqhkiG9w0BAQEFAASCBKowggSmAgEAAoIBAQDspwVwyIxb+nku
    1HTrlUEf+gOB5BN9Ay9+X1GC+JXCWxuiCu5KSAr9xqgN/xSY4cuA+pCs8iQGNJRD
    rp3zOvBvjsi7csgoP6v8zJCIzPsHhrtiujLK7diLIGRaMP8Y1O+iW9vhJCMfJeYL
    uII3GtYqKS5hLTl3cv0tNonYygx+Uk+GR8uYpGHpRX5uXDAY80WBkj6v5xVNpWFA
    TlTmildClGkxU8NAY7UX3Q9OP8UEcADJFqeWM4lyPxVh8tI9KJ6r4RbgZqnhJoZd
    LLMdoKNFaXSC2cNLKok2S7xIU7Bbiml/4hK7A8WCvja8k7wKY12dAPFDUQu0L8sK
    xCr3eCIRAgMBAAECggEBAK7SW8SLgpTYHfmoXY9DPU8ABONJt9PcLJOwmqikNw3S
    /EDizlH1kpkSzkc4ruCZvRpU/9ejMVWcNgMh1fE/Eyt2UXeYPaDuGIGyJPvKYY+X
    yooOf0NGHXf5v+iY1Xpko3pPXcmeRovWFXGHJjrLCncu4OJM5G0Hd1yVM5QA/uW5
    QPgFNPBlqtgQn17fYD7+6wr1LVEVxTjBcEQHd3mIAKLWkD5KBx7sqpDdHPCLIDMQ
    XG4BwXnLtcPchYFTHabpzaizw+Jnd3ChhqB+zUp/2ccPKJBJoro4KAVuXMb25kVv
    YR9QT1TynzO72guLwAwjDB+6IdgWP22oUVE+rQ7uurkCgYEA90nwGvt5O0B5Zl/m
    U0RmJrBo6y9srHyU1sb623d+j3w6cZ5VfsIVZhUEH1sF0tv5YZQuya1A6aj/sGsL
    rqmFvEK1wwUANLDT0I7Z81pmDDHbc3qM2iWZ9nmd1kwq8Cq3Rw1eEiRDd/nJ4pO9
    6T9FaUW1+Jg85IEklbLu4C4JVocCgYEA9P0p8ixbY8FTFQC6wXrtv4L/QW1R/QoY
    M+U//zqocbp9cSfaFNtD57O2hpwdselC8T0O9Nm5MPJytbgtNO5NcTrJ0ZvdyAwD
    L8svcwfjpdsmntI0uCQO8CGLwnycP9L4LWvFgNSrs3r/88yWLrdC1xs5EcM+Pvk3
    8q2BRMAV0KcCgYEA3Kc+9fSaEkLPkIfVz0rjE3apx+GDSM3JSXQ3dwlDBulEhQlR
    JFAuI+5wxUHFCod6GJXOweo0V8qSjGqX+/wL9xZXdXLK4jk+Z4Rv+fMZx5vdQ0eA
    005l+UY/jm5cifyzmVTWMb3l7fIXMHPAK5Znay3m17GP9B0/9cu51pN9hZUCgYEA
    uwVgth0ijx6QPCJYb0dWo7JvBhVcV50TKNrDZiXzXQ6OoIlZtD5GsmTA3DXlfWGi
    1uJTvptPAoyzAQJekF+zAtNsKfWg8wwoip3D1T6ajIymCOxTjpcISExzkr7p0NdO
    2e3B0j2H7fXh2s29gGAqSGfhwyuXIx/BlCLb4g35GVUCgYEA8qFNJNJZFELfkwo9
    N2LsK7Bx14cSQ3M5r6bSLt04uKEWXHAZyG7SCa0UG0h4Fys4fReGg7EE12piMh4p
    WJXqF9/CaYU9jWKWOPIJTEquLQA3j6kVB2sXLQwQVQZaFTAnf8QYsuVOatKScOKH
    3FYgTNAnnwu/Oz6z4g+MQMgRujc=
    -----END PRIVATE KEY-----
  EOT
}
