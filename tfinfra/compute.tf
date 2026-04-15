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
    apt-get install -y nodejs npm
    mkdir -p /home/app
    cat <<'JSEOF' > /home/app/server.js
const http = require('http');
const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify({ status: 'ok', message: 'Hello from backend!' }));
});
server.listen(3000, () => console.log('Backend running on port 3000'));
JSEOF
    node /home/app/server.js &
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
    apt-get install -y nginx
    BACKEND_IP="${google_compute_instance.vm_backend.network_interface[0].network_ip}"
    cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html>
<head><title>Frontend</title></head>
<body>
  <h1>Frontend VM</h1>
  <p>Calling backend at: $BACKEND_IP:3000</p>
  <div id="result">Loading...</div>
  <script>
    fetch('http://$BACKEND_IP:3000')
      .then(r => r.json())
      .then(d => document.getElementById('result').innerText = JSON.stringify(d))
      .catch(e => document.getElementById('result').innerText = 'Error: ' + e);
  </script>
</body>
</html>
HTML
    systemctl restart nginx
  EOF

  tags = ["frontend"]
  depends_on = [google_compute_instance.vm_backend]
}