#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Current folder
cur_dir=$(pwd)
# Color
red='\033[0;31m'
green='\033[0;32m'
#yellow='\033[0;33m'
plain='\033[0m'
operation=(Install Update UpdateConfig logs restart delete)
# Make sure only root can run our script
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] Chưa vào root kìa !, vui lòng xin phép ROOT trước!" && exit 1

#Check system
check_sys() {
  local checkType=$1
  local value=$2
  local release=''
  local systemPackage=''

  if [[ -f /etc/redhat-release ]]; then
    release="centos"
    systemPackage="yum"
  elif grep -Eqi "debian|raspbian" /etc/issue; then
    release="debian"
    systemPackage="apt"
  elif grep -Eqi "ubuntu" /etc/issue; then
    release="ubuntu"
    systemPackage="apt"
  elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
    release="centos"
    systemPackage="yum"
  elif grep -Eqi "debian|raspbian" /proc/version; then
    release="debian"
    systemPackage="apt"
  elif grep -Eqi "ubuntu" /proc/version; then
    release="ubuntu"
    systemPackage="apt"
  elif grep -Eqi "centos|red hat|redhat" /proc/version; then
    release="centos"
    systemPackage="yum"
  fi

  if [[ "${checkType}" == "sysRelease" ]]; then
    if [ "${value}" == "${release}" ]; then
      return 0
    else
      return 1
    fi
  elif [[ "${checkType}" == "packageManager" ]]; then
    if [ "${value}" == "${systemPackage}" ]; then
      return 0
    else
      return 1
    fi
  fi
}

# Get version
getversion() {
  if [[ -s /etc/redhat-release ]]; then
    grep -oE "[0-9.]+" /etc/redhat-release
  else
    grep -oE "[0-9.]+" /etc/issue
  fi
}

# CentOS version
centosversion() {
  if check_sys sysRelease centos; then
    local code=$1
    local version="$(getversion)"
    local main_ver=${version%%.*}
    if [ "$main_ver" == "$code" ]; then
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}

get_char() {
  SAVEDSTTY=$(stty -g)
  stty -echo
  stty cbreak
  dd if=/dev/tty bs=1 count=1 2>/dev/null
  stty -raw
  stty echo
  stty $SAVEDSTTY
}
error_detect_depends() {
  local command=$1
  local depend=$(echo "${command}" | awk '{print $4}')
  echo -e "[${green}Info${plain}] Bắt đầu cài đặt các gói ${depend}"
  ${command} >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "[${red}Error${plain}] Cài đặt gói không thành công ${red}${depend}${plain}"
    exit 1
  fi
}

# Pre-installation settings
pre_install_docker_compose() {
    read -p "Nhập Link Web :" domain
    echo -e "Link Web là : ${domain}"

    read -p "Nhập Api Key :" APIKEY
    echo -e "API KEY là : ${APIKEY}"

    read -p "Nhập Node ID port 80 :" node_80
    echo -e "Node_80 là : ${node_80}"

    read -p "Nhập địa chỉ IP port 80 :" ip_80
    echo -e "Node_80 là : ${ip_80}"

    read -p "Nhập Node ID port 443 :" node_443
    echo -e "Node_443 là : ${node_443}"    

    read -p "Nhập SpeedLimit :" SpeedLimit
    echo -e "SpeedLimit = ${SpeedLimit}"

    read -p "Nhập DeviceLimit :" DeviceLimit
    echo -e "DeviceLimit = ${DeviceLimit}"

    read -p "Nhập dns trên cloudflare node 443:" CertDomain443
    echo -e "CertDomain443 = ${CertDomain443}"
  
}

# Config docker
config_docker() {
  cd ${cur_dir} || exit
  echo "Bắt đầu cài đặt các gói"
  install_dependencies
  echo "Tải tệp cấu hình DOCKER"
  cat >docker-compose.yml <<EOF
version: '3'
services: 
  xrayr: 
    image: aikocute/xrayr:v1.7.4
    volumes:
      - ./aiko.yml:/etc/XrayR/aiko.yml # Hệ Thống Lidar
      - ./dns.json:/etc/XrayR/dns.json 
    restart: always
    network_mode: host
EOF
  cat >dns.json <<EOF
{
    "servers": [
        "1.1.1.1",
        "8.8.8.8",
        "localhost"
    ],
    "tag": "dns_inbound"
}
EOF
  cat >aiko.yml <<EOF
Log:
  Level: none # Log level: none, error, warning, info, debug 
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: # /etc/XrayR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
InboundConfigPath: # /etc/XrayR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: # /etc/XrayR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnectionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 30 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB
Nodes:
  -
    PanelType: "V2board" # Panel type: SSpanel, V2board, NewV2board, PMpanel, Proxypanel, V2RaySocks
    ApiConfig:
      ApiHost: "${domain}"
      ApiKey: "${APIKEY}"
      NodeID: ${node_80}
      NodeType: V2ray # Node type: V2ray, Shadowsocks, Trojan, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: ${SpeedLimit} # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: ${DeviceLimit} # Local settings will replace remote settings, 0 means disable
      RuleListPath: # /etc/XrayR/rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      DisableSniffing: true # Disable domain sniffing 
      AutoSpeedLimitConfig:
        Limit: 0 # Warned speed. Set to 0 to disable AutoSpeedLimit (mbps)
        WarnTimes: 0 # After (WarnTimes) consecutive warnings, the user will be limited. Set to 0 to punish overspeed user immediately.
        LimitSpeed: 0 # The speedlimit of a limited user (unit: mbps)
        LimitDuration: 0 # How many minutes will the limiting last (unit: minute)
      GlobalDeviceLimitConfig:
        Enable: false # Enable the global device limit of a user
        RedisAddr: 127.0.0.1:6379 # The redis server address
        RedisPassword: YOUR PASSWORD # Redis password
        RedisDB: 0 # Redis DB
        Timeout: 5 # Timeout for redis request
        Expiry: 60 # Expiry time (second)
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Alpn: # Alpn, Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/features/fallback.html for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: file # Option about how to get certificate: none, file, http, tls, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "${ip_80}" # Domain to cert
        CertFile: /etc/XrayR/crt.pem # Provided if the CertMode is file
        KeyFile: /etc/XrayR/key.pem
        Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          ALICLOUD_ACCESS_KEY: aaa
          ALICLOUD_SECRET_KEY: bbb
  -
    PanelType: "V2board" # Panel type: SSpanel, V2board, NewV2board, PMpanel, Proxypanel, V2RaySocks
    ApiConfig:
      ApiHost: "${domain}"
      ApiKey: "${APIKEY}"
      NodeID: ${node_443}
      NodeType: Trojan # Node type: V2ray, Shadowsocks, Trojan, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: ${SpeedLimit} # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: ${DeviceLimit} # Local settings will replace remote settings, 0 means disable
      RuleListPath: # /etc/XrayR/rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      DisableSniffing: true # Disable domain sniffing 
      AutoSpeedLimitConfig:
        Limit: 0 # Warned speed. Set to 0 to disable AutoSpeedLimit (mbps)
        WarnTimes: 0 # After (WarnTimes) consecutive warnings, the user will be limited. Set to 0 to punish overspeed user immediately.
        LimitSpeed: 0 # The speedlimit of a limited user (unit: mbps)
        LimitDuration: 0 # How many minutes will the limiting last (unit: minute)
      GlobalDeviceLimitConfig:
        Enable: false # Enable the global device limit of a user
        RedisAddr: 127.0.0.1:6379 # The redis server address
        RedisPassword: YOUR PASSWORD # Redis password
        RedisDB: 0 # Redis DB
        Timeout: 5 # Timeout for redis request
        Expiry: 60 # Expiry time (second)
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Alpn: # Alpn, Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/features/fallback.html for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: file # Option about how to get certificate: none, file, http, tls, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "${CertDomain443}" # Domain to cert
        CertFile: /etc/XrayR/crt.pem # Provided if the CertMode is file
        KeyFile: /etc/XrayR/key.pem
        Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          ALICLOUD_ACCESS_KEY: aaa
          ALICLOUD_SECRET_KEY: bbb
  # -
  #   PanelType: "NewV2board" # Panel type: SSpanel, V2board, NewV2board, PMpanel, Proxypanel, V2RaySocks
  #   ApiConfig:
  #     ApiHost: "http://127.0.0.1:668"
  #     ApiKey: "123"
  #     NodeID: 4
  #     NodeType: Shadowsocks # Node type: V2ray, Shadowsocks, Trojan
  #     Timeout: 30 # Timeout for the api request
  #     EnableVless: false # Enable Vless for V2ray Type
  #     EnableXTLS: false # Enable XTLS for V2ray and Trojan
  #     SpeedLimit: 0 # Mbps, Local settings will replace remote settings
  #     DeviceLimit: 0 # Local settings will replace remote settings
  #   ControllerConfig:
  #     ListenIP: 0.0.0.0 # IP address you want to listen
  #     UpdatePeriodic: 10 # Time to update the nodeinfo, how many sec.
  #     EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
  #     CertConfig:
  #       CertMode: dns # Option about how to get certificate: none, file, http, dns
  #       CertDomain: "node1.test.com" # Domain to cert
  #       CertFile: /etc/XrayR/cert/node1.test.com.cert # Provided if the CertMode is file
  #       KeyFile: /etc/XrayR/cert/node1.test.com.pem
  #       Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
  #       Email: test@me.com
  #       DNSEnv: # DNS ENV option used by DNS provider
  #         ALICLOUD_ACCESS_KEY: aaa
  #         ALICLOUD_SECRET_KEY: bbb
EOF
  sed -i "s|DeviceLimit:.*|DeviceLimit: ${DeviceLimit}|" ./config.yml
}

# Install docker and docker compose
install_docker() {
  echo -e "bắt đầu cài đặt DOCKER "
 sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get install docker-ce docker-ce-cli containerd.io -y
systemctl start docker
systemctl enable docker
  echo -e "bắt đầu cài đặt Docker Compose "
curl -fsSL https://get.docker.com | bash -s docker
curl -L "https://github.com/docker/compose/releases/download/1.26.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
  echo "khởi động Docker "
  service docker start
  echo "khởi động Docker-Compose "
  docker-compose up -d
  echo
  echo -e "Đã hoàn tất cài đặt phụ trợ ！"
  echo -e "0 0 */3 * *  cd /root/${cur_dir} && /usr/local/bin/docker-compose pull && /usr/local/bin/docker-compose up -d" >>/etc/crontab
  echo -e "Cài đặt cập nhật thời gian kết thúc đã hoàn tất! hệ thống sẽ update sau [${green}24H${plain}] Từ lúc bạn cài đặt"
}

install_check() {
  if check_sys packageManager yum || check_sys packageManager apt; then
    if centosversion 5; then
      return 1
    fi
    return 0
  else
    return 1
  fi
}

install_dependencies() {
  if check_sys packageManager yum; then
    echo -e "[${green}Info${plain}] Kiểm tra kho EPEL ..."
    if [ ! -f /etc/yum.repos.d/epel.repo ]; then
      yum install -y epel-release >/dev/null 2>&1
    fi
    [ ! -f /etc/yum.repos.d/epel.repo ] && echo -e "[${red}Error${plain}] Không cài đặt được kho EPEL, vui lòng kiểm tra." && exit 1
    [ ! "$(command -v yum-config-manager)" ] && yum install -y yum-utils >/dev/null 2>&1
    [ x"$(yum-config-manager epel | grep -w enabled | awk '{print $3}')" != x"True" ] && yum-config-manager --enable epel >/dev/null 2>&1
    echo -e "[${green}Info${plain}] Kiểm tra xem kho lưu trữ EPEL đã hoàn tất chưa ..."

    yum_depends=(
      curl
    )
    for depend in ${yum_depends[@]}; do
      error_detect_depends "yum -y install ${depend}"
    done
  elif check_sys packageManager apt; then
    apt_depends=(
      curl
    )
    apt-get -y update
    for depend in ${apt_depends[@]}; do
      error_detect_depends "apt-get -y install ${depend}"
    done
  fi
  echo -e "[${green}Info${plain}] Đặt múi giờ thành phố Hà Nội GTM+7"
  ln -sf /usr/share/zoneinfo/Asia/Hanoi  /etc/localtime
  date -s "$(curl -sI g.cn | grep Date | cut -d' ' -f3-6)Z"

}

#update_image
Update_xrayr() {
  cd ${cur_dir}
  echo "Tải Plugin DOCKER"
  docker-compose pull
  echo "Bắt đầu chạy dịch vụ DOCKER"
  docker-compose up -d
}

#show last 100 line log

logs_xrayr() {
  echo "nhật ký chạy sẽ được hiển thị"
  docker-compose logs --tail 100
}

# Update config
UpdateConfig_xrayr() {
  cd ${cur_dir}
  echo "đóng dịch vụ hiện tại"
  docker-compose down
  pre_install_docker_compose
  config_docker
  echo "Bắt đầu chạy dịch vụ DOKCER"
  docker-compose up -d
}

restart_xrayr() {
  cd ${cur_dir}
  docker-compose down
  docker-compose up -d
  echo "Khởi động lại thành công!"
}
delete_xrayr() {
  cd ${cur_dir}
  docker-compose down
  cd ~
  rm -Rf ${cur_dir}
  echo "đã xóa thành công!"
}
# Install xrayr
Install_xrayr() {
  pre_install_docker_compose
  config_docker
  install_docker
}

# Initialization step
clear
while true; do
  echo "Docker 80-443 XrayR for Xflash"
  echo "Modder: TÚN"
  echo "Vui lòng nhập một số để Thực Hiện Câu Lệnh:"
  for ((i = 1; i <= ${#operation[@]}; i++)); do
    hint="${operation[$i - 1]}"
    echo -e "${green}${i}${plain}) ${hint}"
  done
  read -p "Vui lòng chọn một số và nhấn Enter (Enter theo mặc định ${operation[0]}):" selected
  [ -z "${selected}" ] && selected="1"
  case "${selected}" in
  1 | 2 | 3 | 4 | 5 | 6 | 7)
    echo
    echo "Bắt Đầu : ${operation[${selected} - 1]}"
    echo
    ${operation[${selected} - 1]}_xrayr
    break
    ;;
  *)
    echo -e "[${red}Error${plain}] Vui lòng nhập số chính xác [1-6]"
    ;;
  esac
done
