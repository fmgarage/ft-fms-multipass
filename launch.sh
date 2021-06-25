#!/usr/bin/env bash

# when Windows
wsl=$(env | grep WSL )
if [ -n "$wsl" ]; then
  shopt -s expand_aliases
  alias multipass='multipass.exe'
fi

# go to working dir
printf "go to working directory...\n"
pwd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || {
    printf "error while determining work directory\n"
    exit 1
  }
cd "$pwd" || {
    printf "error while changing to work directory\n"
    exit 1
  }

# parse config
source "$pwd"/common/settings.sh

# get settings from config
# todo not found
printf "get config...\n"

instance=$(get_setting "instance_name" ./config.txt)
cpus=$(get_setting "cpus" ./config.txt)
if [ -z "$cpus" ];then
  cpus=1
fi
disk=$(get_setting "add_disk" ./config.txt)
if [ -z "$disk" ];then
  disk=0
fi
mem=$(get_setting "mem" ./config.txt)
if [ -z "$mem" ];then
  mem=1
fi

pub_key_path=$(get_setting "ssh_pub_key_path" ./config.txt)
pub_key=$(cat "${pub_key_path}") || {
    printf "error while getting ssh pub key\n"
    exit 1
  }
admin_user=$(get_setting "Admin Console User" ./config.txt)
admin_pass=$(get_setting "Admin Console Password" ./config.txt)
admin_pin=$(get_setting "Admin Console PIN" ./config.txt)
license=$(get_setting "License Certificate Path" ./config.txt)

printf "checking config...\n"
check_setting "$instance"
check_setting "$cpus"
check_integer "$cpus"
check_setting "$disk"
check_integer "$disk"
check_setting "$mem"
check_integer "$mem"
check_setting "$admin_user"
check_setting "$admin_pass"
check_setting "$admin_pin"
check_setting "$license"


printf "write assisted_install.txt...\n"
cat > assisted_install.txt <<EOF
[Assisted Install]

License Accepted=1

Deployment Options=0

Admin Console User=${admin_user}

Admin Console Password=${admin_pass}

Admin Console PIN=${admin_pin}

License Certificate Path=${license}
EOF


printf "write cloud-config to init.yml...\n"
cat > init.yml <<EOF
#cloud-config
users:
  - default
  - name: fmserver
    lock_passwd: false
    plain_text_passwd: 'fmserver'
    ssh_authorized_keys:
      - ${pub_key}
output: {all: '| tee -a /var/log/cloud-init-output.log'}
packages: []
package_update: true
package_upgrade: true
EOF

# exit if instance exists
find_instance=$(multipass ls | grep "${instance}")
if [ -n "$find_instance" ]; then
    printf "An instance with the name %s already exists!\n" "$instance"
    exit 1
fi

# recognize launch options defaults

if [ $cpus -eq 1 ]; then
  cpus=""
else
  cpus="--cpus ${cpus}"
fi

if [ $disk -eq 0 ]; then
  disk_space=""
else
  disk_space="--disk "$((disk + 5))G
fi

if [ $mem -eq 1 ]; then
  mem=""
else
  mem="--mem ${mem}G"
fi

# build launch options
launch_options=""
for option in $cpus $disk_space $mem; do
  launch_options+="${option} "
done

printf "launch multipass instance...\n"
eval multipass launch "${launch_options}"--name "${instance}" --cloud-init init.yml 18.04 || {
    printf "error while launching multipass instance\n"
    exit 1
  }

printf "transfer assisted_install.txt...\n"
multipass transfer assisted_install.txt "${instance}": || {
    printf "error while transferring assisted_install.txt\n"
    exit 1
  }

# download from URL if not found locally
package=$(find . -name "*.deb")
if [[ ! $package ]]; then
  printf "\ndownloading fms package ...\n"
  url=$(get_setting "url" ./config.txt)
  check_many "$url"
  STATUS=$(curl -s --head --output /dev/null -w '%{http_code}' "$url")
  if [ ! "$STATUS" -eq 200 ]; then
    echo "Error while downloading fms package: Got a $STATUS from URL: $url ..."
    exit 1
  fi
    multipass exec "${instance}" -- wget "${url}" -O /home/ubuntu/fms.deb
  # curl "${url}" -O || exit
else
  printf "Transferring install package...\n"
  multipass transfer "${package}" "${instance}":/home/ubuntu/fms.deb || {
    printf "error while transferring installer package\n"
    exit 1
  }
fi

printf "Installing FileMaker Server...\n"
multipass exec "${instance}" -- bash -c "sudo FM_ASSISTED_INSTALL=/home/ubuntu/assisted_install.txt apt install /home/ubuntu/fms.deb -y" || {
    printf "error while installing fmserver package\n"
    exit 1
  }
multipass exec "${instance}" -- fmsadmin -u ${admin_user} -p ${admin_pass} set serverconfig SecureFilesOnly=false || {
    printf "error while setting SecureFileOnly\n"
    exit 1
  }
multipass exec "${instance}" -- fmsadmin -u ${admin_user} -p ${admin_pass} -y disable schedule 1 || {
    printf "error while setting disable schedule\n"
    exit 1
  }

printf "Restarting instance to finish installation...\n"
multipass restart "${instance}"

printf "Done. FileMaker Server is running at the following IP:\n"
multipass info "${instance}" | grep IPv4
