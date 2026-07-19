terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  #token     = "auth_token_here"
  #cloud_id  = "cloud_id_here"
  #folder_id = "folder_id_here"
  zone = "ru-central1-b"
}

data "yandex_vpc_network" "network1" {
  name = "default"
}

resource "yandex_compute_instance" "vm" {
  count = 2

  name = "vm${count.index}"
  platform_id = "standard-v3"
  boot_disk {
    initialize_params {
      image_id = "fd81gsj7pb9oi8ks3cvo" # ubuntu 24.04
      size = 10
    }
  }
  
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat = true
  }

  resources {
    cores = 2
    memory = 2
  }

  metadata = { ssh-keys = "ubuntu:${file("~/.ssh/ssh-key-1775316766104/ssh-key-1775316766104.pub")}" }
}

#resource "yandex_vpc_network" "network1" {
#  name = "network1"
#}

resource "yandex_vpc_subnet" "subnet1" {
  name = "subnet1"
  v4_cidr_blocks = ["172.16.16.0/24"]
  network_id = data.yandex_vpc_network.network1.id
}

resource "yandex_lb_target_group" "group1" {
  name = "group1"
  
  dynamic "target" {
    for_each = yandex_compute_instance.vm
    content {
      subnet_id = yandex_vpc_subnet.subnet1.id
      address = target.value.network_interface.0.ip_address
    }
  }
}

resource "yandex_lb_network_load_balancer" "balancer1" {
  name = "balancer1"
  deletion_protection = "false"
  listener {
    name = "my-lb1"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.group1.id
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}
