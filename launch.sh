#!/usr/bin/env bash

# when Windows
wsl=$(env | grep WSL )
if [ -n "$wsl" ]; then
  shopt -s expand_aliases
  alias multipass='multipass.exe'
fi

# go to working dir
printf "\n \e[36m go to working directory... \e[39m\n"
pwd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || {
    printf "error while determining work directory\n"
    exit 1
  }
cd "$pwd" || {
    printf "error while changing to work directory\n"
    exit 1
  }

source "$pwd"/common/settings.sh
source "$pwd"/common/instance.sh

# get settings from config
# todo not found
printf "\n \e[36m get config... \e[39m\n"
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

pub_key_path=$(get_setting "ssh_pub_key_path" ./config.txt) || {
    printf "error while getting ssh key path\n"
    exit 1
  }
if [ -n "$pub_key_path" ]; then
    pub_key=$(cat "${pub_key_path}") || {
        printf "error while getting ssh pub key\n"
        exit 1
      }
else
  pub_key=""
fi

admin_user=$(get_setting "Admin Console User" ./config.txt)
admin_pass=$(get_setting "Admin Console Password" ./config.txt)
admin_pin=$(get_setting "Admin Console PIN" ./config.txt)
license=$(get_setting "License Certificate Path" ./config.txt)

printf "\n \e[36m checking config... \e[39m\n"
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

printf "\n \e[36m write assisted_install.txt... \e[39m\n"
cat > assisted_install.txt <<EOF
[Assisted Install]

License Accepted=1

Deployment Options=0

Admin Console User=${admin_user}

Admin Console Password=${admin_pass}

Admin Console PIN=${admin_pin}

License Certificate Path=${license}
EOF

printf "\n \e[36m write cloud-config to init.yml... \e[39m\n"
cat > init.yml <<EOF
#cloud-config
users:
  - default
  - name: fmserver
    lock_passwd: false
    plain_text_passwd: 'fmserver'
    ssh_authorized_keys:
      - ${pub_key}
ssh_pwauth: true
chpasswd: { expire: False }
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

#find package/check url before launching instance
package=$(find . -name "*.deb")
if [[ ! $package ]]; then
  printf "\n \e[36m no local package found, checking fms package url... \e[39m\n"
  url=$(get_setting "url" ./config.txt)
  check_setting "$url"
  STATUS=$(curl -s --head --output /dev/null -w '%{http_code}' "$url")
  if [ ! "$STATUS" -eq 200 ]; then
    echo "Error while checking fms package URL: Got a $STATUS from: $url ..."
    exit 1
  fi
  printf "\n \e[36m found package at URL. \e[39m\n"
  package_url=1
fi

printf "\n \e[36m launch multipass instance... \e[39m\n"
eval multipass launch "${launch_options}"--name "${instance}" --cloud-init init.yml 18.04 || {
    printf "error while launching multipass instance\n"
    remove_instance "${instance}"
    exit 1
  }

printf "\n \e[36m transfer assisted_install.txt... \e[39m\n"
multipass transfer assisted_install.txt "${instance}": || {
    printf "error while transferring assisted_install.txt\n"
    remove_instance "${instance}"
    exit 1
  }

# download from URL or transfer from local
if [[ $package_url -eq 1 ]]; then
  printf "\n \e[36m downloading fms package ... \e[39m\n"

  multipass exec "${instance}" -- wget "${url}" -O /home/ubuntu/fms.deb
  # curl "${url}" -O || exit
elif [[ $package ]]; then
  printf "\n \e[36m Transferring install package... \e[39m\n"

  multipass transfer "${package}" "${instance}":/home/ubuntu/fms.deb || {
    printf "error while transferring installer package\n"
    remove_instance "${instance}"
    exit 1
  }
else
  printf "error while preparing installer package\n"
  exit 1
fi

printf "\n \e[36m Installing FileMaker Server... \e[39m\n"
multipass exec "${instance}" -- bash -c "sudo FM_ASSISTED_INSTALL=/home/ubuntu/assisted_install.txt apt install /home/ubuntu/fms.deb -y" || {
    printf "error while installing fmserver package\n"
    remove_instance "${instance}"
    exit 1
  }
multipass exec "${instance}" -- fmsadmin -u ${admin_user} -p ${admin_pass} set serverconfig SecureFilesOnly=false || {
    printf "error while setting SecureFileOnly\n"
    remove_instance "${instance}"
    exit 1
  }
multipass exec "${instance}" -- fmsadmin -u ${admin_user} -p ${admin_pass} -y disable schedule 1 || {
    printf "error while setting disable schedule\n"
    remove_instance "${instance}"
    exit 1
  }

# cleanup
printf "\n \e[36m cleaning up... \e[39m\n"
multipass exec "${instance}" -- rm -v /home/ubuntu/fms.deb || {
    printf "error while removing deb package\n"
    remove_instance "${instance}"
    exit 1
  }
multipass exec "${instance}" -- bash -c "sudo apt clean && sudo apt autoremove --purge" || {
    printf "error while apt cleanup\n"
    remove_instance "${instance}"
    exit 1
  }

printf "\n \e[36m Restarting instance to finish installation... \e[39m\n"
multipass restart "${instance}"

printf "\n \e[36m Done. FileMaker Server is running at the following IP: \e[39m\n"
multipass info "${instance}" | grep IPv4
