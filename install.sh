#!/bin/bash

#fonts color
Green="\033[32m"
Red="\033[31m"
#Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
YellowBG="\033[43;37m"
Font="\033[0m"

#notification information
# Info="${Green}[信息]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[错误]${Font}"
Warning="${Red}[警告]${Font}"

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

cd "$(
  cd "$(dirname "$0")" || exit
  pwd
)" || exit

source '/etc/os-release'
VERSION=$(echo "${VERSION}" | awk -F "[()]" '{print $2}')

is_root() {
  if [ 0 == $UID ]; then
    echo -e "${OK} ${GreenBG} 当前用户是root用户，进入安装流程 ${Font}"
    sleep 3
  else
    echo -e "${Error} ${RedBG} 当前用户不是root用户，请切换到root用户后重新执行脚本 ${Font}"
    exit 1
  fi
}

judge() {
  if [[ 0 -eq $? ]]; then
    echo -e "${OK} ${GreenBG} $1 完成 ${Font}"
    sleep 1
  else
    echo -e "${Error} ${RedBG} $1 失败${Font}"
    exit 1
  fi
}

check_system() {
  if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
    echo -e "${OK} ${GreenBG} 当前系统为 Centos ${VERSION_ID} ${VERSION} ${Font}"
    INS="yum"
  elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]]; then
    echo -e "${OK} ${GreenBG} 当前系统为 Debian ${VERSION_ID} ${VERSION} ${Font}"
    INS="apt"
    $INS update
    ## 添加 Nginx apt源
  elif [[ "${ID}" == "ubuntu" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 16 ]]; then
    echo -e "${OK} ${GreenBG} 当前系统为 Ubuntu ${VERSION_ID} ${UBUNTU_CODENAME} ${Font}"
    INS="apt"
    rm /var/lib/dpkg/lock
    dpkg --configure -a
    rm /var/lib/apt/lists/lock
    rm /var/cache/apt/archives/lock
    $INS update
  else
    echo -e "${Error} ${RedBG} 当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内，安装中断 ${Font}"
    exit 1
  fi

  $INS install dbus -y

  systemctl stop firewalld
  systemctl disable firewalld
  echo -e "${OK} ${GreenBG} firewalld 已关闭 ${Font}"

  systemctl stop ufw
  systemctl disable ufw
  echo -e "${OK} ${GreenBG} ufw 已关闭 ${Font}"
}

dependency_install() {
  ${INS} install wget git lsof -y

  if [[ "${ID}" == "centos" ]]; then
    ${INS} -y install crontabs

  else
    ${INS} -y install cron
  fi
  judge "安装 crontab"

  if [[ "${ID}" == "centos" ]]; then
    touch /var/spool/cron/root && chmod 600 /var/spool/cron/root
    systemctl start crond && systemctl enable crond
  else
    touch /var/spool/cron/crontabs/root && chmod 600 /var/spool/cron/crontabs/root
    systemctl start cron && systemctl enable cron
  fi
  judge "crontab 自启动配置 "

  ${INS} -y install bc
  judge "安装 bc"

  ${INS} -y install unzip
  judge "安装 unzip"

  ${INS} -y install qrencode
  judge "安装 qrencode"

  ${INS} -y install curl
  judge "安装 curl"

  ${INS} -y install python36
  judge "安装 python36"

  if [[ "${ID}" == "centos" ]]; then
    ${INS} -y groupinstall "Development tools"
  else
    ${INS} -y install build-essential
  fi
  judge "编译工具包 安装"

  if [[ "${ID}" == "centos" ]]; then
    ${INS} -y install pcre pcre-devel zlib-devel epel-release
  else
    ${INS} -y install libpcre3 libpcre3-dev zlib1g-dev dbus
  fi

  mkdir -p /usr/local/bin >/dev/null 2>&1
}

basic_optimization() {
  # 最大文件打开数
  sed -i '/^\*\ *soft\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
  sed -i '/^\*\ *hard\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
  echo '* soft nofile 65536' >>/etc/security/limits.conf
  echo '* hard nofile 65536' >>/etc/security/limits.conf

  # 关闭 Selinux
  if [[ "${ID}" == "centos" ]]; then
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    setenforce 0
  fi

}

v2ray_qr_config_file="/usr/local/etc/xray/config.json"
old_config_exist_check() {
  if [[ -f $v2ray_qr_config_file ]]; then
    echo -e "${OK} ${GreenBG} 检测到旧配置文件，是否读取旧文件配置 [Y/N]? ${Font}"
    read -r ssl_delete
    case $ssl_delete in
    [yY][eE][sS] | [yY])
      echo -e "${OK} ${GreenBG} 已保留旧配置  ${Font}"
      old_config_status="on"
      ;;
    *)
      rm -rf $v2ray_qr_config_file
      echo -e "${OK} ${GreenBG} 已删除旧配置  ${Font}"
      ;;
    esac
  fi
}

v2ray_install() {
#  if [[ -f /usr/local/bin/xray ]]; then
#    echo -e "${OK} ${GreenBG} 检测到已经安装，正在删除 ${Font}"
#    bash template/install-xray-release.sh remove
#  fi
#
#  if [[ -f /usr/local/etc/xray/config.json ]]; then
#    bash rm -rf /usr/local/etc/xray
#    judge "已删除旧配置"
#  fi
  if [[  -f template/install-xray-release.sh ]]; then
    echo -e "${OK} ${GreenBG} 检测到内置脚本，是否重新下载安装脚本 [Y/N]? ${Font}"
    read -r down_xray_install
    case $down_xray_install in
    [yY][eE][sS] | [yY])
      wget -N --no-check-certificate https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh -O template/install-xray-release.sh
      ;;
    *)
      echo -e "${OK} ${GreenBG} 正在使用默认脚本 ${Font}"
    esac
  else
    echo -e "${OK} ${GreenBG} 未检测到脚本，开始下载 ${Font}"
    wget -N --no-check-certificate https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh -O template/install-xray-release.sh
  fi

  if [[ -f template/install-xray-release.sh ]]; then
    systemctl daemon-reload
    #bash template/install-xray-release.sh install
    judge "安装 xray"
  else
    echo -e "${Error} ${RedBG} V2ray 安装文件下载失败，请检查下载地址是否可用 ${Font}"
    exit 4
  fi
}

config_xray() {
  echo -e "${OK} ${GreenBG} 进入节点配置过程 ${Font}"
  sleep 3
  echo -e "${OK} ${GreenBG} 请给这个节点命名，会生成 NAME-0形式的节点 [Name]? ${Font}"
  read -r NodeName
  if [ ! "$NodeName" ]; then
    NodeName="Node"
  fi
  python3 configFactory.py $NodeName
}

install_v2ray_ws() {
  is_root
  check_system
  dependency_install
  basic_optimization
  old_config_exist_check
  v2ray_install
  config_xray

}
remove_all() {
  if [[  -f template/install-xray-release.sh ]]; then
    echo -e "${OK} ${GreenBG} 检测到内置脚本，是否重新下载安装脚本 [Y/N]? ${Font}"
    read -r down_xray_install
    case $down_xray_install in
    [yY][eE][sS] | [yY])
      wget -N --no-check-certificate https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh -O template/install-xray-release.sh
      ;;
    *)
      echo -e "${OK} ${GreenBG} 正在使用默认脚本 ${Font}"
    esac
  else
    echo -e "${OK} ${GreenBG} 未检测到脚本，开始下载 ${Font}"
    wget -N --no-check-certificate https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh -O template/install-xray-release.sh
  fi
  bash template/install-xray-release.sh remove --force
  rm -rf /usr/local/etc/xray/config.json
}

#remove_all
install_v2ray_ws
