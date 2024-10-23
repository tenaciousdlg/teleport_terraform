provider "google" {
  project = "weighty-planet-305123"
  region  = "us-central1"
}

resource "google_compute_instance" "first_instance" {
  name         = "dlg-ssh-jump"
  machine_type = "n1-standard-1"
  zone         = "us-central1-a"
  boot_disk {
    initialize_params {
      image = "ubuntu-minimal-2204-lts"
    }
  }
  network_interface {
    network = "default"
  }
  metadata_startup_script = file("teleport_install.sh")
}

resource "google_compute_instance" "second_instance" {
  name         = "dlg-ssh-only-from-jump"
  machine_type = "n1-standard-1"
  zone         = "us-central1-a"
  boot_disk {
    initialize_params {
      image = "ubuntu-minimal-2204-lts"
    }
  }
  network_interface {
    network = "default"
  }
  
  network_interface {
    network = "default"
    access_config {
      // Allow SSH access only from the first instance
      nat_ip = self.self_link
    }
  }
}
