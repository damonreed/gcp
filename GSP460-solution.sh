##
## GSP460-solution.sh
##

## Task 1 - Set up Terraform

mkdir tfnet
cd tfnet
cat > provider.tf << EOF
provider "google" {}
EOF
terraform init

## Task 2 - Create managementnet and its resources

cat > managementnet.tf << EOF
# Create the managementnet network
resource google_compute_network "managementnet" {
  name = "managementnet"
  auto_create_subnetworks = "false"
}

# Create managementsubnet-us subnetwork
resource "google_compute_subnetwork" "managementsubnet-us" {
  name          = "managementsubnet-us"
  region        = "us-east4"
  network       = google_compute_network.managementnet.self_link
  ip_cidr_range = "10.130.0.0/20"
}

# Add a firewall rule to allow HTTP, SSH, RDP and ICMP traffic on managementnet
resource google_compute_firewall "managementnet-allow-http-ssh-rdp-icmp" {
  name = "managementnet-allow-http-ssh-rdp-icmp"
  source_ranges = [
    "0.0.0.0/0"
  ]
  network = google_compute_network.managementnet.self_link
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "3389"]
  }
  allow {
    protocol = "icmp"
  }
}

# Add the managementnet-us-vm instance
module "managementnet-us-vm" {
  source              = "./instance"
  instance_name       = "managementnet-us-vm"
  instance_zone       = "us-east4-c"
  instance_subnetwork = google_compute_subnetwork.managementsubnet-us.self_link
}

EOF

mkdir instance
cat > instance/main.tf << EOF
variable "instance_name" {}
variable "instance_zone" {}
variable "instance_type" {
  default = "e2-standard-2"
}
variable "instance_subnetwork" {}

resource "google_compute_instance" "vm_instance" {
  name         = var.instance_name
  zone         = var.instance_zone
  machine_type = var.instance_type

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork = var.instance_subnetwork

    access_config {
      # Allocate a one-to-one NAT IP to the instance
    }
  }
}
EOF

terraform fmt -recursive
terraform init
# terraform plan
terraform apply

gcloud compute networks list
gcloud compute networks subnets list
gcloud compute firewall-rules list
gcloud compute instances list

# Task 3. Create privatenet and its resources

cat > privatenet.tf << EOF
# Create privatenet network
resource "google_compute_network" "privatenet" {
  name                    = "privatenet"
  auto_create_subnetworks = false
}

# Create privatesubnet-us subnetwork
resource "google_compute_subnetwork" "privatesubnet-us" {
  name          = "privatesubnet-us"
  region        = "us-east4"
  network       = google_compute_network.privatenet.self_link
  ip_cidr_range = "172.16.0.0/24"
}

# Create privatesubnet-second-subnet subnetwork
resource "google_compute_subnetwork" "privatesubnet-second-subnet" {
  name          = "privatesubnet-second-subnet"
  region        = "us-west1"
  network       = google_compute_network.privatenet.self_link
  ip_cidr_range = "172.20.0.0/24"
}

# Create a firewall rule to allow HTTP, SSH, RDP and ICMP traffic on privatenet
resource "google_compute_firewall" "privatenet-allow-http-ssh-rdp-icmp" {
  name    = "privatenet-allow-http-ssh-rdp-icmp"
  source_ranges = [
    "0.0.0.0/0"
  ]
  network = google_compute_network.privatenet.self_link

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "3389"]
  }

  allow {
    protocol = "icmp"
  }
}

# Add the privatenet-us-vm instance
module "privatenet-us-vm" {
  source              = "./instance"
  instance_name       = "privatenet-us-vm"
  instance_zone       = "us-east4-c"
  instance_subnetwork = google_compute_subnetwork.privatesubnet-us.self_link
}
EOF

terraform fmt -recursive
terraform init
terraform plan
terraform apply

gcloud compute networks list
gcloud compute networks subnets list
gcloud compute firewall-rules list
gcloud compute instances list


cat > mynetwork.tf << EOF
# Create the mynetwork network
resource "google_compute_network" "mynetwork" {
name                    = "mynetwork"
auto_create_subnetworks = "true"
}

# Create a firewall rule to allow HTTP, SSH, RDP and ICMP traffic on mynetwork
resource "google_compute_firewall" "mynetwork-allow-http-ssh-rdp-icmp" {
  name    = "mynetwork-allow-http-ssh-rdp-icmp"
  source_ranges = [
    "0.0.0.0/0"
  ]
  network = google_compute_network.mynetwork.self_link

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "3389"]
  }

  allow {
    protocol = "icmp"
  }
}

# Create the mynet-us-vm instance
module "mynet-us-vm" {
  source              = "./instance"
  instance_name       = "mynet-us-vm"
  instance_zone       = "us-east4-c"
  instance_subnetwork = google_compute_network.mynetwork.self_link
}

# Create the mynet-second-vm" instance
module "mynet-second-vm" {
  source              = "./instance"
  instance_name       = "mynet-second-vm"
  instance_zone       = "us-west1-c"
  instance_subnetwork = google_compute_network.mynetwork.self_link
}

EOF

terraform fmt -recursive
terraform init
terraform plan -out=mynetwork.tfplan
terraform apply mynetwork.tfplan
rm mynetwork.tfplan
