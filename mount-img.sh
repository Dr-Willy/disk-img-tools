#!/bin/bash
#
# Mount partitions from a disk image
#
# Requirements: partx, losetup
#

img=$1
mountPrefix=${2:-"/mnt"}

partition="none"

readarray partitions < <(partx -rg $img)

for line in "${partitions[@]}";do
    read i beg end sector size label < <(echo $line)
    name=${label:-"${img%\.img}_$i"}
    offset=$(($beg*512))
    sizeLimit=$(($sector*512))
    mountPoint=${mountPrefix}/${name}
    echo "mounting $name on $mountPoint"

    if [ ! -d $mountPoint ]; then
        mkdir $mountPoint
    fi

    mount $img $mountPoint -o loop,offset=${offset},sizelimit=${sizeLimit}

done

