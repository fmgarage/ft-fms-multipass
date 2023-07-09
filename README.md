# ft-fms-multipass

**About**
- [Installation on macOS](#installation-on-macos)
- [Installation on Windows 10](#installation-on-windows-10)
- [Administration](#administration)
- [Issues](#issues)

## About

Run FileMaker Server 19.3 for Ubuntu in Multipass for Mac or Windows. Everything you need to automatically build a ready-to-run Instance.

We are constantly improving the scripts and try to get rid of the remaining issues. If you want to stay up-to-date, make sure to watch the repo and maybe follow us on Twitter: [fmgarage](https://twitter.com/fmgarage)

TIP: Also see [ft-fms-docker](https://github.com/fmgarage/ft-fms-docker), our approach to run FileMaker Server in Docker. While Multipass is even more lightweight, and a little easier to use due to its focused nature, it is not yet as mature as Docker and still yields some bugs and missing features. 
The mount of external volumes for example doesn't handle ownership mapping the way it should, so FileMaker Server directories must be accessed via SFTP instead. 
On the other hand, with multipass, it is possible to run multiple FileMaker Servers in parallel.

**What does 'FT' stand for?**
All our FileMaker-based projects and products are prefixed with an F, and the T is for tools, technology, tipps&tricks, techniques, or open templates for the community. These files are basically examples and demonstrations where you can copy stuff from and include it in your individual apps and solutions.

Browse all our FT repos:
[https://github.com/fmgarage?q=ft-](https://github.com/fmgarage?q=ft-)

If you are looking for other ways to run a FileMaker Server for Linux, check out our regarding repos:
[https://github.com/fmgarage?q=ft-fms-](https://github.com/fmgarage?q=ft-fms-)

## Installation on macOS

### Multipass

Download and install Multipass and make sure it is running: [https://multipass.run](https://multipass.run)

### Repo

Clone or download the repo.

### FileMaker Server

Download a copy of the FileMaker Server installer for Linux from your Claris account page, unpack the zip file and move the `deb` file to the folder where you put the repo. You can also put a link into the config.txt instead, the installer will be downloaded then.

### SSH key pair generation

If you want to connect to the instance's filesystem without a password, and you don't already have a public/private ssh key pair, you will need to create one. With the following command, a key pair gets generated and saved to your home directory in the `.ssh` folder:

ssh-keygen -t rsa -b 4096

markdown
Copy code

### Config

Adjust settings in `config.txt`

- Set instance name. Must be unique.
instance_name=fms1

sql
Copy code

- Set resources for the instance. Leave empty for default values.
include::doc/admo_disk.adoc[]

cpus=1
add_disk=2
mem=2

vbnet
Copy code

- Set path to ssh public key for key-based SFTP file access. Leave empty for password authentication.
ssh_pub_key_path=/Users/nancy/.ssh/id_rsa.pub

vbnet
Copy code

You can adjust the settings for the _Assisted Install.txt_ file in the `config.txt`, but you don't need to. The server admin console login will be admin/admin then, which can be changed later.

//include::doc/build.adoc[]

### Build and run Instance

Open Terminal.app, drag the `launch.sh` into the terminal window and hit return.

After the installation process finishes, the IP of the instance will be printed out by the script.
Also check the multipass menu, there should be a running instance named like set in `config.txt`.

Open the admin console by browsing to with `\https://<IP_from_output>:16000`

Mind that:
- *Chrome* does not work without a valid certificate
- *Safari* lets you bypass the certificate warning
- *Edge* lets you bypass the certificate warning, but you need to append `https://`.

Clicking `Open Shell` from the Multipass menu will open a terminal window where you can use the fmsadmin command to control your server.

## Installation on Windows 10

### WSL2

Install the Windows Subsystem for Linux WSL first. To do so, follow these instructions: [https://docs.microsoft.com/de-de/windows/wsl/install-win10](https://docs.microsoft.com/de-de/windows/wsl/install-win10) ("Manual Installation Steps").

### Ubuntu

Download and install Ubuntu from the Windows Store. The `Ubuntu` and `Ubuntu 20.04` apps are identical, just make sure it is the one offered by Canonical Group Limited.
When installed, update packages:

```shell
sudo apt update
sudo apt upgrade
Most likely, it will be necessary to restart Ubuntu after the update, which in this case is done by leaving the linux environment with

shell
Copy code
exit
and then starting Ubuntu again.

Multipass
Download and install Multipass and make sure it is running: https://multipass.run

Repo
Clone or download and unzip the repo.

FileMaker Server
Download a copy of the FileMaker Server installer for Linux from your Claris account page, unpack the zip file and move the deb file to the folder where you put the repo. You can also put a link into the config.txt instead, the installer will be downloaded then.

SSH key pair generation
If you want to connect to the instance's filesystem without a password, and you don't already have a public/private ssh key pair, you will need to create one. With the following command, a key pair gets generated and saved to your home directory in the .ssh folder:

css
Copy code
ssh-keygen -t rsa -b 4096
Then, from WinSCP or PuTTY or the Windows SFTP client of your choice, you might need to convert the private key to the PuTTY ppk format.

Config
Adjust settings in config.txt

Set instance name. Must be unique.
makefile
Copy code
instance_name=fms1
Set resources for the instance. Leave empty for default values.
makefile
Copy code
include::doc/admo_disk.adoc[]

cpus=1
add_disk=2
mem=2
Set path to ssh public key for key-based SFTP file access. Leave empty for password authentication.
ruby
Copy code
ssh_pub_key_path=/mnt/c/Users/nancy/.ssh/id_rsa.pub
You can adjust the settings for the Assisted Install.txt file in the config.txt, but you don't need to. The server admin console login will be admin/admin then, which can be changed later.

Run install script
In Ubuntu shell, run the installer from the folder where you put the repository:

bash
Copy code
/mnt/c/Users/<User>/Downloads/ft-fms-multipass/launch.sh
After the installation process finishes, the IP of the instance will be