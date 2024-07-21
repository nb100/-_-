#!/bin/bash

echo "
  _       _                 
 | |     (_)                
 | |__    _   _ __    _   _ 
 | '_ \  | | | '_ \  | | | |
 | | | | | | | |_) | | |_| |
 |_| |_| |_| | .__/   \__, |
             | |       __/ |
             |_|      |___/ 
"

echo "相关项目信息：
前端: https://github.com/hjdhnx/hipy-ui
后端: https://github.com/hjdhnx/hipy-server
桌面: https://github.com/Hiram-Wong/ZyPlayer
教程: https://zy.catni.cn"

echo -e "\033[33m[Hipy] 安装预计需半小时(取决于网络), 中途退出安装请删除安装目录后重新运行脚本[默认路径: /data/hipy]\033[0m"

qrcode() {
    echo

    echo "█████████████████████████████"
    echo "██ ▄▄▄▄▄ █▀▀ ▀▀   ▄█ ▄▄▄▄▄ ██"
    echo "██ █   █ █▄▀█  █ ███ █   █ ██"
    echo "██ █▄▄▄█ █ ▄▀██ ▀  █ █▄▄▄█ ██"
    echo "██▄▄▄▄▄▄▄█ █ █▄█ █▄█▄▄▄▄▄▄▄██"
    echo "██▄▄▀ ██▄ ▀▀██ ▄█▄ ▀ ▄▄█▄▄▀██"
    echo "██▄▄ █▀█▄▄█▀▀█ ▀██▄ █▀ ██▄▄██"
    echo "██▄▄▄▀▀█▄█ ▀▄▄  ██▄▀  █ ▀▄ ██"
    echo "██▄▀▄▀▀ ▄▀▄ ▀ ▀▀▄█ ▀▀▄ █▄▀▄██"
    echo "██▄▄█▄█▄▄▄▀▄█▀▀▄▀  ▄▄▄  ▄█▀██"
    echo "██ ▄▄▄▄▄ █▄▄███▄▄  █▄█  ▀  ██"
    echo "██ █   █ █▀█▀▄▀▄▄█▄▄▄   ▀████"
    echo "██ █▄▄▄█ █▀███ ▀▄█▀▄█▄▄▀▄█▄██"
    echo "██▄▄▄▄▄▄▄▀▄▄█▄▄██▄▄▄▄▄███▄▄██"
    echo "█████████████████████████████"

    echo
    echo "QQ扫描上方二维码加入项目讨论组"
}

command_exists() {
    command -v "$1" 2>&1
}

check_container_health() {
    local container_name=$1
    local max_retry=30
    local retry=0
    local health_status="unhealthy"
    echo "Waiting for $container_name to be healthy"
    while [[ "$health_status" == "unhealthy" && $retry -lt $max_retry ]]; do
        health_status=$(docker inspect --format='{{.State.Health.Status}}' $container_name 2>/dev/null || echo 'unhealthy')
        sleep 1
        retry=$((retry+1))
    done
    if [[ "$health_status" == "unhealthy" ]]; then
        abort "Container $container_name is unhealthy"
    fi
    echo "Container $container_name is healthy"
}

space_left() {
    dir="$1"
    while [ ! -d "$dir" ]; do
        dir=`dirname "$dir"`;
    done
    echo `df -h "$dir" --output='avail' | tail -n 1`
}

start_docker() {
    systemctl start docker && systemctl enable docker
}

confirm() {
    echo -e -n "\033[34m[Hipy] $* \033[1;36m(Y/n)\033[0m"
    read -n 1 -s opt

    [[ "$opt" == $'\n' ]] || echo

    case "$opt" in
        'y' | 'Y' ) return 0;;
        'n' | 'N' ) return 1;;
        *) confirm "$1";;
    esac
}

info() {
    echo -e "\033[37m[Hipy] $*\033[0m"
}

warning() {
    echo -e "\033[33m[Hipy] $*\033[0m"
}

abort() {
    echo -e "\033[31m[Hipy] $*\033[0m"
    exit 1
}

trap 'onexit' INT
onexit() {
    echo
    abort "用户手动结束安装"
}

replace_domain() {
    local directory="$1"
    local old_domain="$2"
    local new_domain="$3"

    # 使用sed命令替换文件中的域名
	sed -i "s#$old_domain#$new_domain#g" $(grep -rl "$old_domain" "$directory")
	sed -i "s#^API_DOMAIN=.*\$#API_DOMAIN=$new_domain#" ".env"

    info "域名已替换为: $new_domain"
}

# CPU ssse3 指令集检查
support_ssse3=1
lscpu | grep ssse3 > /dev/null 2>&1
if [ $? -ne "0" ]; then
    echo "not found info in lscpu"
    support_ssse3=0
fi

cat /proc/cpuinfo | grep ssse3 > /dev/null 2>&1
if [ $support_ssse3 -eq "0" -a $? -ne "0" ]; then
    abort "hipy需要运行在支持 ssse3 指令集的 CPU 上，虚拟机请自行配置开启 CPU ssse3 指令集支持"
fi

hipy_path='/data/hipy'
api_domain='http://172.23.0.3:5707/'

if [ -z "$BASH" ]; then
    abort "请用 bash 执行本脚本"
fi

if [ ! -t 0 ]; then
    abort "STDIN 不是标准的输入设备"
fi

if [ "$#" -ne "0" ]; then
    abort "当前脚本无需任何参数"
fi

if [ "$EUID" -ne "0" ]; then
    abort "请以 root 权限运行"
fi

info "脚本调用方式确认正常"

if [ -z `command_exists docker` ]; then
    warning "缺少 Docker 环境"
    if confirm "是否需要自动安装 Docker"; then
        curl -sSLk https://get.docker.com/ | bash
        if [ $? -ne "0" ]; then
            abort "Docker 安装失败"
        fi
        info "Docker 安装完成"
    else
        abort "中止安装"
    fi
fi
info "发现 Docker 环境: '`command -v docker`'"

start_docker
docker version > /dev/null 2>&1
if [ $? -ne "0" ]; then
    abort "Docker 服务工作异常"
fi
info "Docker 工作状态正常"

compose_command="docker compose"
if $compose_command version; then
    info "发现 Docker Compose Plugin"
else
    warning "未发现 Docker Compose Plugin"
    compose_command="docker-compose"
    if [ -z `command_exists "docker-compose"` ]; then
        warning "未发现 docker-compose 组件"
        if confirm "是否需要自动安装 Docker Compose Plugin"; then
            curl -sSLk https://get.docker.com/ | bash
            if [ $? -ne "0" ]; then
                abort "Docker Compose Plugin 安装失败"
            fi
            info "Docker Compose Plugin 安装完成"
            compose_command="docker compose"
        else
            abort "中止安装"
        fi
    else
        info "发现 docker-compose 组件: '`command -v docker-compose`'"
    fi
fi

while true; do
    echo -e -n "\033[34m[Hipy] hipy安装目录 (留空则为 '$hipy_path'): \033[0m"
    read input_path
    [[ -z "$input_path" ]] && input_path=$hipy_path

    if [[ ! $input_path == /* ]]; then
        warning "'$input_path' 不是合法的绝对路径"
        continue
    fi

    if [ -f "$input_path" ] || [ -d "$input_path" ]; then
        warning "'$input_path' 路径已经存在，请换一个"
        continue
    fi

    hipy_path=$input_path

    if confirm "目录 '$hipy_path' 当前剩余存储空间为 `space_left \"$hipy_path\"` ，hipy至少需要 5G，是否确定"; then
        break
    fi
done

mkdir -p "$hipy_path"
if [ $? -ne "0" ]; then
    abort "创建安装目录 '$hipy_path' 失败"
fi
info "创建安装目录 '$hipy_path' 成功"
cd "$hipy_path"

curl "https://zy.catni.cn/release/latest/compose.yaml" -sSLk -o compose.yaml

if [ $? -ne "0" ]; then
    abort "下载 compose.yaml 脚本失败"
fi
info "下载 compose.yaml 脚本成功"

touch ".env"
if [ $? -ne "0" ]; then
    abort "创建 .env 脚本失败"
fi
info "创建 .env 脚本成功"

echo "HIPY_DIR=$hipy_path" >> .env
echo "FASTAPI_PORT=5707" >> .env
echo "SNIFFER_PORT=5708" >> .env
echo "VUE_PORT=8707" >> .env
echo "POSTGRES_PASSWORD=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 32)" >> .env
echo "REDIS_PASSWORD=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 32)" >> .env
echo "SUBNET_PREFIX=172.23.0" >> .env
echo "API_DOMAIN=http://172.23.0.3:5707/" >> .env

mkdir -p hipyTmp
if [ $? -ne "0" ]; then
    abort "创建 hipyTmp 临时目录失败"
fi
info "创建 hipyTmp 临时目录成功"

info "即将开始拉取 sniffer 最新代码"
curl "https://github.com/nb100/hipy-sniffer/archive/refs/heads/main.zip" -SLk -o ./hipyTmp/sniffer.zip -w "\nDownload complete. Total size: %{size_download} bytes. Speed: %{speed_download}\n"
unzip -q ./hipyTmp/sniffer.zip -d ./hipyTmp/sniffer
#arch=$(uname -m)
#if [[ $arch == *"arm"* ]]; then
	sed -i 's/"USE_CHROME": true,/"USE_CHROME": false,/g' ./hipyTmp/sniffer/hipy-sniffer-main/quart_config.json
#fi
mkdir -p resources/sniffer
mv ./hipyTmp/sniffer/hipy-sniffer-main/* ./resources/sniffer
touch "./resources/sniffer/nohup.out"

info "即将开始拉取 server 最新代码"
curl "https://github.com/nb100/hipy-server/archive/refs/heads/master.zip" -SLk -o ./hipyTmp/server.zip -w "\nDownload complete. Total size: %{size_download} bytes. Speed: %{speed_download}\n"
unzip -q ./hipyTmp/server.zip -d ./hipyTmp/server
mkdir -p resources/fastapi
mv ./hipyTmp/server/hipy-server-master/app/* ./resources/fastapi
curl "https://zy.catni.cn/release/latest/.env" -sSLk -o ./resources/fastapi/configs/.env

info "即将开始拉取 vue 最新代码"
curl "https://zy.catni.cn/release/latest/vue.zip" -SLk -o ./hipyTmp/vue.zip -w "\nDownload complete. Total size: %{size_download} bytes. Speed: %{speed_download}\n"
unzip -q ./hipyTmp/vue.zip -d ./hipyTmp/vue
mkdir -p resources/vue
mv ./hipyTmp/vue/* resources/vue/

while true; do
    echo -e -n "\033[34m[Hipy] 是否自定义后端API域名 (留空则为 '$api_domain'): \033[0m"
    read input_api_domain
    [[ -z "$input_api_domain" ]] && input_api_domain=$api_domain
	
	if ! [[ $input_api_domain =~ ^https?://[^/]+/$ ]]; then
        warning "'$input_api_domain' 不是合法的域名，必须以'http://'或'https://'开头，并以'/'结尾。"
        continue
    fi

    if confirm "启用新后端域名:$input_api_domain，是否确定"; then
		replace_domain "./resources/vue" "$api_domain" "$input_api_domain"
        break
    fi
done


info "即将开始下载 Docker 镜像"

$compose_command up -d

if [ $? -ne "0" ]; then
    abort "启动 Docker 容器失败"
fi

qrcode

check_container_health hipy-pg
check_container_health hipy-fastapi
sleep 1

cat <<EOF > ./hipyTmp/check_and_install_git.sh
#!/bin/bash

# 检查git是否已安装
if ! command -v git &> /dev/null; then
    # 如果没有安装，则安装git
    apt update && apt install -y git > /dev/null 2>&1
fi
EOF
docker cp ./hipyTmp/check_and_install_git.sh hipy-fastapi:/check_and_install_git.sh
docker exec hipy-fastapi bash -c "chmod +x /check_and_install_git.sh && /check_and_install_git.sh"
info "检测并添加缺少git依赖完成"
docker exec hipy-fastapi python3 initial_data.py > /dev/null 2>&1
info "数据库初始化完成"

CRON_COMMAND="*/30 * * * * docker restart hipy-sniffer"
(crontab -l ; echo "$CRON_COMMAND") | crontab -
info "嗅探器定时重启任务写入成功"

warning "安装成功, 请访问以下地址访问控制台"
warning "http://0.0.0.0:8707"
warning "如需域名访问, 请自行使用 nginx 反向代理"

# bash -c "$(curl -fsSLk https://zy.catni.cn/release/latest/setup.sh)"