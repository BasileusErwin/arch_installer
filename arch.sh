#!/bin/bash

MY_GITHUB="https://github.com/KaiserErwin"

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
NORMAL="\033[0m"
BLUE="\033[0;34m"

# TODO: Cambiar mensages de error o panic
warn() {
  echo -e "${YELLOW}-> Warning:${NORMAL} $1" >&2
}

error() {
  echo -e "${RED}==> Error:${NORMAL} $1" >&2
}

panic() {
  echo -e "${RED}==> Panic:${NORMAL} $1" >&2
  exit 1
}

message() {
  echo -e "${BLUE}==> Info:${NORMAL} $1"
}

question() {
  echo -e "${GREEN}==> Questions:${NORMAL} $1"
}

# Functions
program_exists() {
    command -v $1 &> /dev/null
}

command_success() {
  if [[ $1 == 1 ]]; then
    error $2

    question "Do you want to continue?"
    read -p "-> Yes/No: " OPTION

    if [[ ${OPTION,,} == "yes" ]] || [[ $OPTION == "" ]]; then
        warn "Continuing . . . $3"
        return 0
    fi
    panic $2
  fi
}

config_to_dell_instpiron() {
  echo "options snd-intel-dspcfg dsp_driver=1 \
        options snd-hda-intel dmic_detect=0 \
        # Add delayed register for HyperX Cloud Flight S Headset \
        options snd-usb-audio delayed_register=095116ea:02 \
        options snd-usb-audio quirk_alias=095116ea:095116d8 delayed_register=095116ea:02" >> /etc/modprobe.d/alas.conf
  command_success $? "" ""

  sed -i -e 's/MODULES=()/MODULES=( vmd )' /etc/mkinitcpio.conf
  command_success $? "" ""

  mkinitcpio -P
  command_success $? "" ""
}

create_user(){
  question "Create a user?"
  read -p "-> Yes/No: " OPTION

  if [[ "${OPTION,,}" == "yes" ]] || [[ $OPTION == "" ]]; then
    read -p "--> username: " USERNAME
    useradd -m -g users -G audio,lp,optical,storage,video,wheel,power -s /bin/bash $USERNAME
    return `command_success $? "The new user could not be created" "Not create new user"`

    passwd $USERNAME
  fi
}

get_aur() {
  git clone https://aur.archlinux.org/$1.git /opt/$1
  cd /opt/$1
  makepkg -si
}

grub() {
  message "Grub install"
  grub-install --efi-directory=$EFI --bootloader-id=$BOOT_NAME --target=x86_64-efi
  command_success $? "The grub could not be installed" "Grub not installed"

  message "Grub config"
  echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
  if [[ $? == 1 ]]; then
    warn "Could not add OS-prober option"
  fi

  grub-mkconfig -o /boot/grub/grub.cfg
  command_success $? "Could not configure grub" "Grub not config"
}

get_my_config() {
  PACKAGES_TO_INSTALL="neovim bspwm sxhkd rofi nodejs npm python python-pip ruby rubygems xsel fzf ripgrep fd prettier pacman-contrib brightnessctl pamixer upower zsh"
  AUR_PACKAGES_TO_INSTALL="lightdm-webkit-theme-aether brave nerd-fonts-ubuntu-mono nerd-fonts-jetbrains-mono nerd-fonts-liberation-mono eslint standard cmake-language-server vscode-json-languageserver"   

  pacman -Sy --noconfirm $PACKAGES_TO_INSTALL

  get_aur "paru"

  paru --noconfirm $AUR_PACKAGES_TO_INSTALL
 
  pip install neovim
  gem install neovim
  npm i -g neovim

  chsh -s /bin/zsh $USERNAME

  git clone "$MY_GITHUB/dotfiles.git" /opt/dotfiles
  cd /opt/
  cp -r dotfiles/.config/*/!(*.md) "$USERNAME/.config/"
  cp -r dotfiles/.zshrc "$USERNAME"
  cp -r dotfiles/.xprofile "$USERNAME"
  cp -r dotfiles/zsh_plugins/* /usr/share/
  cp dotfiles/.local/bin/percentage ~/.local/bin/
  cp dotfiles/.local/bin/battery ~/.local/bin/
  cp dotfiles/.local/bin/brightness ~/.local/bin/
  cp dotfiles/.local/bin/volume ~/.local/bin/

  echo "[D-BUS Service] \
        Name=org.freedesktop.Notifications \
        Exec=/usr/lib/notification-daemon-1.0/notification-daemon" >> /usr/share/dbus-1/services/org.freedesktop.Notifications.service
}

is_mounted() { findmnt "$1" >/dev/null }

refresh_key() { pacman-key --refresh-keys }

echo -e "GET http://archlinux.org HTTP/1.0\n\n" | nc archlinux.org 80 > /dev/null 2>&1
[[ $? == 1 ]] && panic "There is no Internet conection . . . Can't continue" || message "Internet connection"

# DEFAULT VALUES
TIME_ZONE="America/Montevideo"
USERNAME=""
EFI="/boot/efi"
BOOT_NAME="Arch Linux"
MOUNT="/mnt"
LANG="es_UY"
KEYMAP="en"
HOSTNAME="ArchLinux"
REFRESH_KEY=false
PACKAGES="base base-devel linux linux-firmware linux-headers grub efibootmgr networkmanager git os-probes \
  xorg-xinit git ranger pcmanfm glib2 gvfs unzip zip xcb-util-cursor lxappearance kvantum-qt5 lightdm-webkit2-greeter\
  dhcpcd netctl wpa_supplicant dialog xf86-input-synaptics geeqie vlc firefox alacritty redshift scrot\
  ntfs-3g networkmanager gvfs gvfs-afc gvfs-mtp xdg-user-dirs network-manager-applet bluez bluez-utils \
  feh lightdm lightdm-gtk-greeter ttf-dejavu ttf-liberation noto-fonts pulseaudio pavucontrol udiskie ntfs-3g libnotify notification-daemon\
  "
INSPIRON=false
MY_CONFIG=false

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  KEY="$1"

  case $KEY in
    -m|--mount)
      is_mounted "$2" && MOUNT="$2" || panic "Device ROOT is not mounted"
      shift
      shift
    ;;
    -t|--time)
      [[ "$2" != "" ]] && TIME_ZONE="$2" || panic "Time Zone not null"
      shift
      shift
    ;;
    -l|--lang)
      LANG="$2"
      [[ "$2" != "" ]] && LANG="$2" || panic "Lang not null"
      shift
      shift
      shift
    ;;
    -k|--keymap)
      [[ "$2" != "" ]] && KEYMAP="$2" || panic "Keymap not null"
      shift
      shift
    ;;
    -H|--hostname)
      [[ "$2" != "" ]] && HOSTNAME="$2" || panic "Hostname not null"
      shift
      shift
    ;;
    -e|--efi)
      is_mounted "$2" && EFI="$2" || panic "Device EFI is not mounted"
      shift
      shift
    ;;
    -r|--refresh-keys)
      REFRESH_KEY=true
      shift
      shift
    ;;
    --inspiron)
      INSPIRON=true
      shift
      shift
    ;;
    -b|--boot-name)
      BOOT_NAME="$2"
      shift
      shift
    ;;
    -c|--my-config)
      MY_CONFIG=true
      shift
      shift
    ;;
  -h|--help)
    echo "-b boot-name \n
          -c my config \n
          --inspiron \n
          -r refrech key"
    exit 0
    ;;
    *)
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done

pacman -Sy

if [[ $REFRESH_KEY ]]; then
  refresh_key
fi

message "Installing ${PACKAGES}"
sleep 2
pacstrap $MOUNT $PACKAGES
command_success $? "" ""

genfstab -pU $MOUNT >> $MOUNT/etc/fstab
command_success $? "Could not create fstab" "Could not create fstab"

arch-chroot $MOUNT
if [[ $? == 1 ]]; then
  fatal "The chroot could not be executed"
fi

message "Set zonetime"
ln -sf /usr/share/zoneinfo/$TIME_ZONE /etc/localtime
command_success $? "" ""

hwclock --systohc
command_success $? "" ""

message "Set lang sistem"
echo "LANG="$LANG.UTF-8"" > /etc/locale.conf
command_success $? "" ""

echo "$LANG.UTF-8 UTF-8" > /etc/locale.gen
command_success $? "" ""

message "Set Keymap"
echo "KEYMAP="$KEYMAP"" > /etc/vconsole.conf
command_success $? "" ""

message "Set hostname"
echo $HOSTNAME > /etc/hostname
command_success $? "" ""

fc-list

if [[ $INSPIRON ]]; then
 config_to_dell_instpiron
fi

create_user

if [[ $MY_CONFIG ]]; then
  get_my_config
fi
