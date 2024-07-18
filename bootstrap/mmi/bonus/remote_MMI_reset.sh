#!/bin/bash
set -eEuo pipefail
trap '[ $? -eq 0 ] && exit 0 || onError $?' EXIT

onError () {
  echo "reset FAILED. Error $1."
  exit "$1"
}

help() {
  cat <<EOF
This script will, in sequence
1) reset the MMI data partition, erasing in the process all existing logs and databases
2) reset the operating system on both slots
3) personalize the board
Please be patient as the sequence involves 4 reboots of the board.
On a local network, the whole process takes about 10 minutes.
EOF
}

usage() {
  cat <<EOF
Usage: $0 <target-ip-address-or-hostname> <serial-number>
EOF
  help
  return 42
}

if [ $# -ne 2 ]
then
    usage
fi

IP="$1"
SERIAL_NUMBER="$2"
MMI_IMAGE="$(pwd)"

banner() {
  echo "==================================================="
  echo "$1 / $(date)"
  echo "==================================================="
}

scmd() {
  cmd=$1
  shift
  $cmd \
    -o StrictHostKeyChecking=no \
    -o GlobalKnownHostsFile=/dev/null \
    -o UserKnownHostsFile=/dev/null \
    $@
}

sshcmd() {
  scmd ssh root@$IP $@
}

sshupload() {
  if [ -f "$1" ]
  then
    scmd scp $1 root@$IP:$2
  else
    echo "Missing $1"
    usage
  fi
}

checkBoardIsAvailable() {
  scmd ssh -q -o ConnectTimeout=20 root@$IP exit
  echo $?
}

waitForBoard() {
  echo "Waiting for $IP..." 
  while [ "$(checkBoardIsAvailable)" != "0" ]
  do
    echo "Still waiting for $IP..."
  done
}

getSlotsStatus() {
  export ACTIVE_SLOT=$(sshcmd "rauc status 2>/dev/null | grep Booted | cut -c 21")
  export INACTIVE_SLOT=$(( 1 - $ACTIVE_SLOT ))
  export SLOTS=(A B)
  echo "Current status: Active=${SLOTS[$ACTIVE_SLOT]} Inactive=${SLOTS[$INACTIVE_SLOT]}"
}

removeDataPartitionFromFstabAndReboot() {
getSlotsStatus
sshcmd <<EOF
if [ -f /home/root/.ssh/authorized_keys ]
then
  cp /home/root/.ssh/authorized_keys /root
  grep -v AuthorizedKeysFile /etc/ssh/sshd_config > /tmp/sshd_config
  echo "AuthorizedKeysFile /root/authorized_keys" >> /tmp/sshd_config
  cp /tmp/sshd_config /etc/ssh/sshd_config
fi

grep -v /datafs /etc/fstab > /tmp/fstab
cp /tmp/fstab /etc/fstab
fw_setenv BOOT_${SLOTS[$ACTIVE_SLOT]}_LEFT 3
fw_setenv BOOT_${SLOTS[$INACTIVE_SLOT]}_LEFT 3
fw_printenv | grep BOOT_
systemctl disable boostheat-wpa-supplicant || true
systemctl disable reverse-ssh || true
echo "Data partition disabled. Rebooting."
reboot
EOF
}

resetDataPartition() {
DATA_DEVICE=/dev/mmcblk0p5
cat > /tmp/reset.conf <<EOF
[system]
compatible=colibri-imx7-emmc-mmi2
bootloader=uboot
statusfile=/dev/null

[slot.appfs.5]
device=${DATA_DEVICE}
type=ext4
EOF
sshupload /tmp/reset.conf /tmp
sshupload "${MMI_IMAGE}/Boostheat_image-colibri-imx7-emmc-data.tar.gz" /tmp/data.tar.gz
sshcmd <<EOF
umount ${DATA_DEVICE}
rauc -c /tmp/reset.conf write-slot appfs.5 /tmp/data.tar.gz

mount /dev/mmcblk0p5 /datafs
cp /root/authorized_keys  /datafs/home/root/.ssh
EOF
}

resetInactiveSlotAndActivateItAndReboot() {
sshupload "${MMI_IMAGE}/Boostheat_image-colibri-imx7-emmc.bootfs.tar.xz" /tmp/bootfs.tar.xz
sshupload "${MMI_IMAGE}/Boostheat_image-colibri-imx7-emmc.tar.xz" /tmp/rootfs.tar.xz
getSlotsStatus
sshcmd <<EOF
echo "Unmouning /run/bootfs*"
umount /run/bootfs* 2>/dev/null
set -ex
rauc write-slot bootfs.${INACTIVE_SLOT} /tmp/bootfs.tar.xz
rauc write-slot rootfs.${INACTIVE_SLOT} /tmp/rootfs.tar.xz
fw_setenv BOOT_ORDER "${SLOTS[$INACTIVE_SLOT]} ${SLOTS[$ACTIVE_SLOT]}"
fw_setenv BOOT_${SLOTS[$ACTIVE_SLOT]}_LEFT 3
fw_setenv BOOT_${SLOTS[$INACTIVE_SLOT]}_LEFT 3
fw_printenv | grep BOOT_
systemctl disable boostheat-wpa-supplicant || true
systemctl disable reverse-ssh || true
echo "Slot ${INACTIVE_SLOT} reset complete. Rebooting."
reboot
EOF
}

personalizeAndReboot() {
sshupload "${MMI_IMAGE}/authorized_keys" /home/root/.ssh/authorized_keys
sshcmd <<EOF
systemctl disable boostheat-wpa-supplicant || true
systemctl disable reverse-ssh || true

callRedis() {
  REDIS_DB=\$1
  shift
  redis-cli -h "127.0.0.1" -p 6379 -n "\$REDIS_DB" "\$@"
}

setValue() {
  callRedis \$1 HMSET "\$2" at "09:00:00.0000000" value "\$3" > /dev/null
}

echo "FACTORY PERSONALIZATION"
setValue 3 device:serial_number "${SERIAL_NUMBER}"                                                                                                                                                                                

reboot
EOF
}


displaySystemStatus() {
sshcmd <<EOF
systemctl --failed|cat
EOF
}

waitForBoard
banner "UNMOUNT DATA PARTITION"
removeDataPartitionFromFstabAndReboot
waitForBoard
banner "RESET DATA PARTITION"
resetDataPartition
banner "RESET FIRST SLOT"
resetInactiveSlotAndActivateItAndReboot
waitForBoard
banner "RESET SECOND SLOT"
resetInactiveSlotAndActivateItAndReboot
waitForBoard
banner "PERSONALIZE"
personalizeAndReboot
waitForBoard
banner "DONE"
displaySystemStatus
