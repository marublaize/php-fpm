provider "kubernetes" {}

variable "load_balancer_allowed_ranges" {
  default = ["0.0.0.0/0"]
  type    = list(string)
}

resource "kubernetes_config_map" "nginx-config" {
  metadata {
    name = "nginx-config"
  }

  data = {
    "default.conf" = "${file("nginx/conf.d/default.conf")}"
  }
}

resource "kubernetes_config_map" "phpinfo" {
  metadata {
    name = "phpinfo"
  }

  data = {
    "index.php" = "${file("app/index.php")}"
  }
}

resource "kubernetes_deployment" "php-fpm" {
  metadata {
    name = "my-cheese-cake"
    labels = {
      App = "my-cheese-cake"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        App = "my-cheese-cake"
      }
    }
    template {
      metadata {
        labels = {
          App = "my-cheese-cake"
        }
      }
      spec {

        volume {
          name = "nginx-config"
          config_map {
            name = "nginx-config"
            items {
              key   = "default.conf"
              path  = "default.conf"
            } 
          }
        }

        volume {
          name = "phpinfo"
          config_map {
            name = "phpinfo"
            items {
              key   = "index.php"
              path  = "index.php"
            } 
          }
        }

        container {
          image = "nginx:alpine"
          name  = "nginx"

          port {
            container_port = 80
          }

          volume_mount {
            name       = "phpinfo"
            mount_path = "/app/index.php"
            sub_path   = "index.php"
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/conf.d/default.conf"
            sub_path   = "default.conf"
          }

          resources {
            limits {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }

        container {
          image = "php:7-fpm-alpine"
          name  = "php"

          port {
            container_port = 9000
          }

          volume_mount {
            name       = "phpinfo"
            mount_path = "/app/index.php"
            sub_path   = "index.php"
          }

          resources {
            limits {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "php-fpm" {
  metadata {
    name = "php-fpm"
  }
  spec {
    selector = {
      App = kubernetes_deployment.php-fpm.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
    load_balancer_source_ranges = var.load_balancer_allowed_ranges
  }
}

output "lb_ip" {
  value = kubernetes_service.php-fpm.load_balancer_ingress[0].hostname
}