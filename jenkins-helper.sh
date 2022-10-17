#!/bin/bash -e

backup_path="/tmp/jenkins"
jenkins_home="/root/.jenkins"
jenkins_core_version="${2}"
jenkins_plugin_manager_version="2.12.9"
jenkins_plugin_manager_url="https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/${jenkins_plugin_manager_version}/jenkins-plugin-manager-${jenkins_plugin_manager_version}.jar"
jenkins_rpm_url="https://archives.jenkins-ci.org/redhat-stable/jenkins-${jenkins_core_version}-1.1.noarch.rpm"
jenkins_restart_delay="30"
jenkins_war_path="/usr/lib"
nexus_protocol="http"
nexus_host="18.130.149.95"
nexus_port="8081"
nexus_proxy="${nexus_protocol}://${nexus_host}:${nexus_port}/repository/jenkins-proxy"
nginx_protocol="http"
nginx_host="3.8.172.204"
nginx_port="80"
nginx_proxy="${nginx_protocol}://${nginx_host}"
jenkins_war_url="${nexus_proxy}/war-stable/${jenkins_core_version}/jenkins.war"
nginx_path="/usr/share/nginx/html/updates"
now=$(date +'%y%m%d%H%M%S')

jenkins_plugin_manager_command="java -jar jenkins-plugin-manager-${jenkins_plugin_manager_version}.jar --war ${jenkins_war_path}/jenkins.war -d ${jenkins_home}/plugins \
--jenkins-update-center ${nginx_proxy}/updates/dynamic-stable-${jenkins_core_version}/update-center.json \
--jenkins-experimental-update-center ${nginx_proxy}/updates/experimental/update-center.actual.json \
--jenkins-plugin-info ${nginx_proxy}/updates/current/plugin-versions.json"

backup_jenkins() {
    echo -e "\e[1;34mStarting backup with ID: ${now}\e[0m"
    echo -e "Creating tmp directories"
    mkdir -p ${backup_path}/${now}/backup
    mkdir -p ${backup_path}/${now}/war
    
    echo -e "Backing up Jenkins home"
    cd "${jenkins_home}"
    tar -zcf ${backup_path}/${now}/backup/jenkins.tgz .

    echo -e "Backing up Jenkins war file"
    cp ${jenkins_war_path}/jenkins.war ${backup_path}/${now}/war
}

download_plugin_manager() {
    if [ ! -f "jenkins-plugin-manager-${jenkins_plugin_manager_version}.jar" ]; then
        echo -e "Downloading jenkins-plugin-manager-${jenkins_plugin_manager_version}.jar"
        curl -sL ${jenkins_plugin_manager_url} -o jenkins-plugin-manager-${jenkins_plugin_manager_version}.jar
    fi
}

check_hosts() {
    if ! nc -z ${nexus_host} ${nexus_port} -w 5 ; then
        echo -e "Nexus host (${nexus_host}) is not reachable"
        exit 1
    fi

    if ! nc -z ${nginx_host} ${nginx_port} -w 5; then
        echo -e "Nginx host (${nginx_host}) is not reachable"
        exit 1
    fi
}

get_installed_plugins() {
    echo -e "\e[33mGetting list of installed plugins\e[0m"
    ${jenkins_plugin_manager_command} -l > plugins_list.txt 2>&1
    awk '/Bundled plugins:/{found=0} {if(found) print} /Installed plugins:/{found=1}' plugins_list.txt | cut -d " " -f 1 > plugins_installed.txt
    
    if  grep -q "-none-" plugins_installed.txt ; then 
        rm plugins_installed.txt
    fi

    if [ ! -f plugins_installed.txt ]; then
        touch plugins_installed.txt
        echo "Warning: plugins_installed.txt file is empty"
    fi
}

install_jenkins_plugins() {
    echo -e "Updating jenkins plugins"
    plugins_list=$(cat plugins_installed.txt | tr '\n' ' ')
    rm -rf ${jenkins_home}/plugins/*
    ${jenkins_plugin_manager_command} -p ${plugins_list}
}

modify_json() {
    mkdir -p ${nginx_path}/dynamic-stable-${jenkins_core_version}
    mkdir -p ${nginx_path}/experimental
    mkdir -p ${nginx_path}/current

    echo -e "Downloading jenkins-update-center.json"
    curl -s ${nexus_proxy}/updates/dynamic-stable-${jenkins_core_version}/update-center.json -o ${nginx_path}/dynamic-stable-${jenkins_core_version}/update-center.json

    echo -e "Downloading update-center.actual.json"
    curl -s ${nexus_proxy}/updates/dynamic-stable-${jenkins_core_version}/update-center.json -o ${nginx_path}/experimental/update-center.actual.json

    echo -e "Downloading plugin-versions.json"
    curl -s ${nexus_proxy}/updates/dynamic-stable-${jenkins_core_version}/update-center.json -o ${nginx_path}/current/plugin-versions.json

    echo -e "Replacing values into json files"
    sed "s~https://updates.jenkins.io/download~${nexus_proxy}~g" -i ${nginx_path}/dynamic-stable-${jenkins_core_version}/update-center.json
    sed "s~https://updates.jenkins.io/download~${nexus_proxy}~g" -i ${nginx_path}/experimental/update-center.actual.json
    sed "s~https://updates.jenkins.io/download~${nexus_proxy}~g" -i ${nginx_path}/current/plugin-versions.json
}

restart_jenkins() {
    echo -e "\e[32mRestarting Jenkins\e[0m"
    systemctl restart jenkins
}

stop_jenkins() {
    echo -e "\e[31mStopping Jenkins\e[0m"
    systemctl stop jenkins
}

restore_jenkins() {
    echo -e "Reverting Jenkins"
    rm -rf ${jenkins_home}/*
    tar -zxf ${backup_path}/${1}/backup/jenkins.tgz --directory="${jenkins_home}"
    cp ${backup_path}/${1}/war/jenkins.war ${jenkins_war_path}/jenkins.war
}

upgarde_jenkins() {
    upgrade_jenkins_from_war
}

upgrade_jenkins_from_rpm() {
    echo -e "Downloading Jenkins war file"
    curl -sL ${jenkins_rpm_url} -o ${backup_path}/jenkins-${jenkins_core_version}.rpm

    echo -e "Upgrading rpm for Jenkins version $(java -jar ${jenkins_war_path}/jenkins.war --version) with ${jenkins_core_version}"
    rpm -i ${backup_path}/jenkins-${jenkins_core_version}.rpm
}

upgrade_jenkins_from_war() {
    echo -e "Downloading Jenkins war file"
    curl -sL ${jenkins_war_url} -o ${backup_path}/jenkins.war

    echo -e "Replacing war file version $(java -jar ${jenkins_war_path}/jenkins.war --version) with ${jenkins_core_version}"
    cp ${backup_path}/jenkins.war ${jenkins_war_path}/jenkins.war
}

usage() {
    echo -e "${0} [all|backup|install_plugins JENKINS_VERSION|restore BACKUP_ID|upgrade JENKINS_VERSION]"
}

case ${1} in
    all)
        check_hosts
        stop_jenkins
        backup_jenkins
        upgrade_jenkins
        restart_jenkins
        echo -e "Waiting for Jenkins to come up (${jenkins_restart_delay} seconds)"
        sleep ${jenkins_restart_delay}
        download_plugin_manager
        modify_json
        get_installed_plugins
        install_jenkins_plugins
        restart_jenkins
    ;;
    
    backup)
        stop_jenkins
        backup_jenkins
        restart_jenkins
    ;;

    install_plugins)
        check_hosts
        download_plugin_manager
        modify_json
        get_installed_plugins
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
        check_hosts
        stop_jenkins
        upgrade_jenkins
        restart_jenkins
        echo -e "Waiting for Jenkins to come up (60 seconds)"
        sleep 1m
        download_plugin_manager
        modify_json
        get_installed_plugins
        install_jenkins_plugins
        restart_jenkins
    ;;

    *)
        usage
    ;;
esac
