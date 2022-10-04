#!/bin/bash

jenkins_version="${1}"
now=$(date +'%y%m%d%H%M%S')
jenkins_home="/root/.jenkins"
jenkins_war_path="/usr/lib"

# Check for jenkins version in the argument
if [ "$#" -ne 1 ]; then
    echo "Jenkins version required"
    echo "Example: ${0} 2.361.1"
    exit 1
fi

echo "Create directories"
mkdir -p /tmp/jenkins/${now}/backup
mkdir -p /tmp/jenkins/${now}/war

echo "Downloading Jenkins War file"
curl -L https://get.jenkins.io/war-stable/${jenkins_version}/jenkins.war -o /tmp/jenkins/jenkins.war

# Backup jenkins and replace war file
echo "Taking the backup of jenkins plugins, conf etc.."
sudo tar -zcf /tmp/jenkins/${now}/backup/jenkins.tgz -P ${jenkins_home}

echo "Taking the backup of jenkins war file"
cp ${jenkins_war_path}/jenkins.war /tmp/jenkins/${now}/war

echo "Replacing the old war file with latest"
sudo cp /tmp/jenkins/jenkins.war ${jenkins_war_path}/jenkins.war

echo "Restarting Jenkins"
sudo systemctl restart jenkins