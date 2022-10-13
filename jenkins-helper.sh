#!/bin/bash

backup_path="/tmp/jenkins"
jenkins_home="/root/.jenkins"
jenkins_plugin_manager_version="2.12.9"
jenkins_war_path="/usr/lib"
now=$(date +'%y%m%d%H%M%S')

backup_jenkins() {
    echo "Creating tmp directories"
    mkdir -p ${backup_path}/${now}/backup
    mkdir -p ${backup_path}/${now}/war
    
    echo "Backing up Jenkins home: ID = ${now}"
    cd "${jenkins_home}"
    tar -zcf ${backup_path}/${now}/backup/jenkins.tgz .

    echo "Backing up Jenkins war file"
    cp ${jenkins_war_path}/jenkins.war ${backup_path}/${now}/war
}

download_plugin_manager() {
    echo "Downloading jenkins-plugin-manager-${jenkins_plugin_manager_version}.jar"
    curl -L https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/${jenkins_plugin_manager_version}/jenkins-plugin-manager-${jenkins_plugin_manager_version}.jar -o jenkins-plugin-manager-${jenkins_plugin_manager_version}.jar
}

install_jenkins_plugins() {
    plugins_list=$(cat plugins_installed.txt | tr '\n' ' ')
    java -jar jenkins-plugin-manager-${jenkins_plugin_manager_version}.jar --war ${jenkins_war_path}/jenkins.war -d ${jenkins_home}/plugins -p ${plugins_list}
}

restart_jenkins() {
    echo "Restarting Jenkins"
    systemctl restart jenkins
}

stop_jenkins() {
    echo "Stopping Jenkins"
    systemctl stop jenkins
}

restore_jenkins() {
    echo "Reverting Jenkins"
    rm -rf ${jenkins_home}/*
    tar -zxf ${backup_path}/${1}/backup/jenkins.tgz --directory="${jenkins_home}"
    cp ${backup_path}/${1}/war/jenkins.war ${jenkins_war_path}/jenkins.war
}

upgrade_jenkins() {
    jenkins_core_version="${1}"
    echo "${jenkins_core_version}"
    echo "Downloading Jenkins war file"
    curl -L https://get.jenkins.io/war-stable/${jenkins_core_version}/jenkins.war -o ${backup_path}/jenkins.war

    echo "Replacing the old war file with latest"
    cp ${backup_path}/jenkins.war ${jenkins_war_path}/jenkins.war
}

update_jenkins_plugins() {
    echo "Updating plugins"
    java -jar jenkins-plugin-manager-${jenkins_plugin_manager_version}.jar --war ${jenkins_war_path}/jenkins.war -d ${jenkins_home}/plugins -l > plugins_list.txt 2>&1
    awk '/Bundled plugins:/{found=0} {if(found) print} /Installed plugins:/{found=1}' plugins_list.txt | cut -d " " -f 1 > plugins_installed.txt
    plugins_list=$(cat plugins_installed.txt | tr '\n' ' ')
    java -jar jenkins-plugin-manager-${jenkins_plugin_manager_version}.jar --war ${jenkins_war_path}/jenkins.war -d ${jenkins_home}/plugins -p ${plugins_list}
}

usage() {
    echo "${0} [all|backup|install_plugins|restore BACKUP_ID|upgrade JENKINS_VERSION]"
}

check_params() {
    # Check for Jenkins version in the argument
    if [ "$#" -ne 1 ]; then
        echo "Wrong no of parameters provided"
        usage
        exit 1
    fi
}

case ${1} in
    all)
        check_params ${2}
        stop_jenkins
        backup_jenkins
        upgrade_jenkins ${2}
        restart_jenkins
        echo "Waiting for Jenkins to come up (60 seconds)"
        sleep 1m
        download_plugin_manager
        update_jenkins_plugins
        restart_jenkins
    ;;
    
    backup)
        stop_jenkins
        backup_jenkins
        restart_jenkins
    ;;

    install_plugins)
        download_plugin_manager
        install_jenkins_plugins
        restart_jenkins
    ;;

    restore)
        stop_jenkins
        backup_jenkins
        restore_jenkins ${2}
        restart_jenkins
    ;;

    upgrade)
        check_params ${2}
        stop_jenkins
        upgrade_jenkins ${2}
        restart_jenkins
        echo "Waiting for Jenkins to come up (60 seconds)"
        sleep 1m
        download_plugin_manager
        update_jenkins_plugins
        restart_jenkins
    ;;

    *)
        usage
    ;;
esac
