#!/bin/bash

jenkins_home="/root/.jenkins"
jenkins_plugin_mngr_version="2.12.9"
jenkins_war_path="/usr/lib"
now=$(date +'%y%m%d%H%M%S')

backup_jenkins() {
    echo "Creating tmp directories"
    mkdir -p /tmp/jenkins/${now}/backup
    mkdir -p /tmp/jenkins/${now}/war

    echo "Backing up Jenkins home"
    sudo tar -zcf /tmp/jenkins/${now}/backup/jenkins.tgz -P ${jenkins_home}

    echo "Backing up Jenkins war file"
    cp ${jenkins_war_path}/jenkins.war /tmp/jenkins/${now}/war
}

restart_jenkins() {
    echo "Restarting Jenkins"
    systemctl restart jenkins
}

upgrade_jenkins() {
    jenkins_core_version="${1}"
    echo "${jenkins_core_version}"
    echo "Downloading Jenkins war file"
    curl -L https://get.jenkins.io/war-stable/${jenkins_core_version}/jenkins.war -o /tmp/jenkins/jenkins.war

    echo "Replacing the old war file with latest"
    sudo cp /tmp/jenkins/jenkins.war ${jenkins_war_path}/jenkins.war

    restart_jenkins
    
    echo "Waiting for Jenkins to come up (60 seconds)"
    sleep 1m
}

update_jenkins_plugins() {
    echo "Downloading jenkins-plugin-manager.jar"
    curl -L https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/${jenkins_plugin_mngr_version}/jenkins-plugin-manager-${jenkins_plugin_mngr_version}.jar -o jenkins-plugin-manager.jar

    echo "Updating plugins"
    java -jar jenkins-plugin-manager.jar --war ${jenkins_war_path}/jenkins.war -d ${jenkins_home}/plugins -l > plugins_list.txt 2>&1
    plugins_list=$(cat plugins_list.txt | tail -n +2 | awk '{print $1}' | tr '\n' ' ')
    java -jar jenkins-plugin-manager.jar --war ${jenkins_war_path}/jenkins.war -d ${jenkins_home}/plugins -p ${plugins_list}
    restart_jenkins
}

usage() {
    echo "${0} [all|backup|upgrade] JENKINS_VERSION"
}

check_jenkins_version() {
    # Check for Jenkins version in the argument
    if [ "$#" -ne 1 ]; then
        echo "Jenkins version required"
        usage
        exit 1
    fi
}

case ${1} in
    all)
    check_jenkins_version ${2}
    backup_jenkins
    upgrade_jenkins ${2}
    update_jenkins_plugins
    ;;
    
    backup)
    backup_jenkins
    ;;

    upgrade)
    check_jenkins_version ${2}
    upgrade_jenkins ${2}
    update_jenkins_plugins
    ;;

    *)
    usage
    ;;
esac