resource "google_compute_instance" "vm_backend" {
  name         = "vm-backend"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet_backend.id
    access_config {}
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nodejs npm git

    # 1. Clone your repo
    mkdir -p /home/app
    git clone https://github.com/shaimadotcom/terraform-gcp-network-automation.git /home/app/repo

    # 2. Navigate to backend folder and run
    cd /home/app/repo/backend
    npm install
    # Using nohup to keep the process running after the script finishes
    nohup node server.js > /var/log/backend.log 2>&1 &
  EOF

  tags = ["backend"]
}

resource "google_compute_instance" "vm_frontend" {
  name         = "vm-frontend"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet_frontend.id
    access_config {}
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx git

    #  Get the Backend Internal IP from Terraform
    BACKEND_IP="${google_compute_instance.vm_backend.network_interface[0].network_ip}"


    git clone https://github.com/shaimadotcom/terraform-gcp-network-automation.git /tmp/repo

    # 3. Inject the Backend IP into your frontend code 
    # replaces the text 'BACKEND_IP_PLACEHOLDER' 
    sed -i "s/BACKEND_IP_PLACEHOLDER/$BACKEND_IP/g" /tmp/repo/frontend/index.html
    


    cp -r /tmp/repo/frontend/* /var/www/html/


    rm -rf /tmp/repo
    systemctl restart nginx
  EOF

  tags = ["frontend"]
  depends_on = [google_compute_instance.vm_backend]
}
