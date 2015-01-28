#!/bin/bash
SCRIPT=$(readlink -f $0)
DIR="`dirname "$SCRIPT"`"
EXE="${1:-$SHELL}"
PS4='+\t \s> '

cd "$DIR"

declare -A NEW_ENV
NEW_ENV[HOST]="`basename $DIR`"
NEW_ENV[TERM]="${TERM%-256color}"
NEW_ENV[HOME]=/root/
NEW_ENV[PATH]="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin"
NEW_ENV[QEMU_RESERVED_VA]="0xf7000000"
NEW_ENV[PS1]="\[\e[31m\]\u\[\e[m\]@\[\e[36m\]\h\[\e[m\]\\$ "


do_chroot() {
	 [ -f /proc/sys/fs/binfmt_misc/arm_rpi ] || echo ':arm_rpi:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/opt/qemu-arm-rpi/qemu-wrapper:' > /proc/sys/fs/binfmt_misc/register

        local -a environ
        for key in "${!NEW_ENV[@]}"
        do
                environ+=( "${key}=${NEW_ENV[$key]}" )
        done
        env -i - "${environ[@]}" linux32 chroot . "$@"
        RET=$?
        echo "command $* returned $RET"
}

UMOUNT=""

trymount() {
        for DST in "$@"; do true; done
        if mount | grep -q "$DIR/$DST"
        then
                echo "$DST already mounted"
        else
                echo "mounting $DST"
                mount "$@"
                UMOUNT="$DST $UMOUNT"
        fi
}

#set -x

trymount --bind {/,}dev
mkdir -v -p dev/{pts,shm}
trymount -t devpts -o gid=5 devpts dev/pts
trymount -t tmpfs -o size=100M tmpfs dev/shm

trymount -t proc none proc

[[ -d usr/portage ]] && \
trymount --bind {/,}usr/portage
[[ -d usr/portage/distfiles ]] && \
trymount --bind {/,}usr/portage/distfiles
#[[ -d var/portage/ccache ]] && \
#trymount --bind /var/prosys/ccache/amd64 var/portage/ccache
[[ -d usr/portage/packages/eeepc ]] && \
trymount --bind {/,}usr/portage/packages/router


[[ -f ./chroot_conf ]] && source ./chroot_conf

#trymount -t tmpfs -o size=7G tmpfs var/tmp
#trymount -t tmpfs -o size=500M tmpfs tmp

# cp -v /etc/resolv.conf etc/
cat proc/mounts >etc/mtab


#if [ -n "$DISPLAY" ] && [ -x ./usr/bin/xauth ]
#then
#        echo "copying over X Authentication for $DISPLAY"
#        xauth extract - $DISPLAY | do_chroot /bin/bash -x -c '/usr/bin/xauth merge -'
#        NEW_ENV[DISPLAY]="127.0.0.1${DISPLAY}"
#fi

do_chroot "$EXE"

for M in $UMOUNT
do
        echo "unmouting $M"
        umount "$M"
done
set -x
exit $RET
