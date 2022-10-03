#!/bin/bash

jenkins_version="${1}"
now=$(date +'%y%m%d%H%M%S')

# Check for jenkins version in the argument
if [ "$#" -ne 1 ]; then
    echo "Jenkins version required"
    echo "Example: ${0} 2.361.1"
    exit 1
fi

# Create directories
mkdir -p /tmp/jenkins/${now}/{backup,war}

# Download latest jenkins war file
curl https://get.jenkins.io/war-stable/${jenkins_version}/jenkins.war -o /tmp/jenkins/jenkins.war

# Backup jenkins and replace war file
tar -zcf /tmp/jenkins/${now}/backup/jenkins.tgz /var/lib/jenkins
cp /usr/lib/jenkins/jenkins.war /tmp/jenkins/backup/${now}/war
cp /tmp/jenkins/jenkins.war /usr/lib/jenkins/

# Restart Jenkins
systemctl restart jenkins