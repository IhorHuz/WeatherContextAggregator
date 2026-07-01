#!/bin/bash
set -euxo pipefail

JENKINS_VERSION="2.570"
JENKINS_URL="https://get.jenkins.io/war/${JENKINS_VERSION}/jenkins.war"

sudo apt-get install -y fontconfig openjdk-21-jre-headless

sudo useradd -r -s /bin/false jenkins 2>/dev/null || true
sudo mkdir -p /var/lib/jenkins /var/log/jenkins /var/cache/jenkins /usr/share/jenkins
sudo chown -R jenkins:jenkins /var/lib/jenkins /var/log/jenkins /var/cache/jenkins

sudo curl -fL -o /usr/share/jenkins/jenkins.war "$JENKINS_URL"
sudo chown jenkins:jenkins /usr/share/jenkins/jenkins.war

sudo tee /etc/systemd/system/jenkins.service > /dev/null <<'SERVICEFILE'
[Unit]
Description=Jenkins CI Server
After=network.target

[Service]
Type=simple
User=jenkins
Group=jenkins
WorkingDirectory=/var/lib/jenkins
Environment="JENKINS_HOME=/var/lib/jenkins"
Environment="JENKINS_LOG=/var/log/jenkins/jenkins.log"
ExecStart=/usr/bin/java -jar /usr/share/jenkins/jenkins.war --httpPort=8080 --logfile=/var/log/jenkins/jenkins.log
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICEFILE

sudo systemctl daemon-reload
sudo systemctl enable --now jenkins

sudo ufw allow 8080/tcp 2>/dev/null || true
sudo usermod -aG docker jenkins 2>/dev/null || true

echo "Jenkins ${JENKINS_VERSION} installed. Unlock password:"
sleep 30
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
