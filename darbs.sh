#!/bin/sh

# Demon's Auto Rice Bootstrapping Script (DARBS)
# By DemonKingSwarn <demonkingswarn@protonmail.com?
# License: GNU GPLv3

dotfilesrepo="https://github.com/demonkingswarn/dotfiles-3"
progsfile="https://raw.githubusercontent.com/demonkingswarn/DARBS/master/progs.csv"
aurhelper="paru"
repobranch="master"

installpkg() {
    pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

err() {
    printf "%s\n" "$1" >&2
    exit 1
}

welcomemsg() {
    whiptail --title "Welcome!" \
        --msgbox "Welcome to Demon's Auto-Rice Bootstrapping Script\n\nThis script will automatically install a fully-featured Linux desktop, which I use as my main machine.\n\n-Demon" 10 60

    whiptail --title "Important Note!" --yes-button "All ready!" \
        --no-button "Return..." \
        		--yesno "Be sure the computer you are using has current pacman updates and refreshed Arch keyrings.\n\nIf it does not, the installation of some programs might fail." 8 70

}

getuserandpass() {
    name=$(whiptail --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
    while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
        name=$(whiptail --nocancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
    done
    pass1=$(whiptail --nocancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
    pass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    while ! [ "$pass1" = "$pass2" ] ; do
        unset pass2
        pass1=$(whiptail --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
        pass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    done

}

usercheck() {
    ! { id -u "$name" >/dev/null 2>$1; } ||
        whiptail --title "WARNING" --yes-button "CONTINUE" \
            --no-button "No wait..." \
            --yesno "The user \`$name\` already exists on this system. DARBS can install for a user already existing, but it will OVERWRITE any conflicting settings/dotfiles on the user account.\n\nDARBS will NOT overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\n\nNote also that DARBS will change $name's password to the one you just gave." 14 70
}

preinstalling() {
    whiptail --title "Let's get this party started!" --yes-button "Let's go!" \
        --no-button "No, nevermind!" \
        --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\n\nIt will take some time, but when done, you can relax even more with your complete system.\n\nNow just press <Let's go!> and the system will begin installation!" 13 60 || {
        clear
        exit 1
    }
		
}

adduserandpass() {
    whiptail --infobox "Adding user \"$name\" ..." 7 50
    useradd -a -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 || 
        usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
    export repodir="/home/$name/.local/src"
    mkdir -p "$repodir"
    chown -R "$name":wheel "$(dirname "$repodir")"
    echo "$name:$pass1" | chpasswd
    unset pass1 pass2
}

refreshkeys() {
    whiptail --infobox "Refreshing Arch Keyring..." 7 40
    pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
}

manualinstall() {
    whiptail --infobox "Installing \"$1\", an AUR helper..." 7 50
    sudo -u "$name" mkdir -p "$repodir/$1"
    sudo -u "$name" git -C "$repodir" clone --depth 1 --simple-branch \
        --no-tags -q "https://aur.archlinux.org/$1.git" "$repodir/$1" || 
        {
            cd "$repodir/$1" || return 1
            sudo -u "$name" git pull --force origin master
        }
    cd "$repodir/$1" || exit 1
    sudo -u "$name" -D "$repodir/$1" \
        makepkg --noconfirm -si >/dev/null 2>&1 || return 1
}

maininstall() {
    whiptail --title "DARBS Installation" --infobox "Installing \"$1\" ($n of $total). $1 $2" 9 70
    installpkg "$1"
}

gitmakeinstall() {
    progname="$(1##*/)"
    progname="$(progname%.git)"
    dir="$repodir/$progname"
    whiptail --title "DARBS Installation" \
        --infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 8 70
    sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
        --no-tags -q "$1" "$dir" ||
        {
            cd "$dir" || return 1
            sudo -u "$name" git pull --force origin master
        }
    cd "$dir" || exit 1
    make >/dev/null 2>&1
    make install >/dev/null 2>&1
    cd /tmp || return 1
}

aurinstall() {
    whiptail --title "DARBS Installation" \
        --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 9 70
    echo "$aurinstalled" | grep -q "^$1$" && return 1
    sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
}

pipinstall() {
    whiptail --title "DARBS Installation" \
        --infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 9 70
    [ -x "$(command -v pip)" ] || installpkg python-pip >/dev/null 2>&1
    yes | pip install "$1"
}

installationloop() {
    ([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) ||
        curl -Ls "$progsfile" | sed '/^#/d' > /tmp/progs.csv
    total=$(wc -l </tmp/progs.csv)
    aurinstall=$(pacman -Qqm)
    while IFS=, read -r tag program comment; do
        n=$((n + 1))
        echo "$comment" | grep -q "^\".*\"$" &&
            comment="$(echo "$comment" | sed -E 's/(^\"|\"$)//g')"
        case "$tag" in
            "A") aurinstall "$program" "$comment" ;;
            "G") gitmakeinstall "$program" "$comment" ;;
            "P") pipinstall "$program" "$comment" ;;
            *) maininstall "$program" "$comment" ;;
        esac
    done </tmp/progs.csv
}

putgitrepo() {
    whiptail --infobox "Downloading and installing config files..." 7 
    [ -z "$3" ] && branch="master" || branch="$repobranch"
    dir=$(mktemp -d)
    [ ! -d "$2" ] && mkdir -p "$2"
    chown "$name":wheel "$dir" "$2"
    sudo -u "$name" git -C "$repodir" clone --depth 1 \
        --single-branch --no-tags -q --recursive -b "$branch" \
        --recurse-submodules "$1" "$dir"
    sudo -u "$name" cp -rfT "$dir" "$2"
}

finalize() {
    whiptail --title "All done!" \
        --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all programs and configuration files should be in place.\n\nTo run the new graphical environment, log out and log back in a your new user, then run the command \"startx\" to start the graphical environment (it will start automatically in tty1).\n\n- Demon" 13 60

}

pacman --noconfirm --needed -Sy libnewt ||
    error "Are you sure you're running this as the root user, are on an Arch-based distribution and have an internet connection?"

welcomemsg || error "User exited."

getuserandpass || error "User exited."

usercheck || error "User exited."

preinstalling || error "User exited."

refreshkeys || 
    error "Error automatically refreshing Arch keyring. Consider doing so manually."

for x in curl ca-certificates base-devel git ntp zsh; do
    whiptail --title "DARBS Installation" \
        --infobox "Installing \`$x\` which is required to install and configure other programs." 8 70
    installpkg "$x"
done

whiptail --title "DARBS Installation" \
    --infobox "Synchronizing system time to ensure successful and secure installation of software..." 8 70
ntpdate 0.us.pool.ntp.org >/dev/null 2>&1

adduserandpass || error "Error adding username and/or password."

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers

trap -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf

sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

manualinstall paru-bin || error "Failed to install AUR helper."

installationloop

putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
rm -rf "/home/$name/.git/" "/home/$name/README.org" "/home/$name/LICENSE"

rmmod pcspkr
echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf

chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"

[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    # Enable left mouse button by tapping
    option "Tapping" "on"
EndSection' >/etc/X11/xorg.conf.d/40-libinput.conf

echo "%wheel ALL=(ALL) ALL #DARBS" >/etc/sudoers.d/darbs-wheel-can-sudo
echo "%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/paru,/usr/bin/pacman -Syyuw --noconfirm" >/etc/sudoers.d/darbs-cmds-without-password

finalize
