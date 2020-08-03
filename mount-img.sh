#!/bin/bash
#
# Mount partitions from a disk image
#
# Requirements: partx, losetup
#

check_requirements () {
    if [ $(id -u) != 0 ]; then
        echo "Please run this script as root"
        exit 1
    fi

    requirements="partx losetup getopt"
    for req in $requirements; do
        if ! which $req>/dev/null; then
            echo "Can not find $req"
            exit 1
        fi
    done
}

usage () {
    echo "$0 [-h] [--ro] [-p <part_id>] [-o|--overlay] <image_file> <mount_point>"
    exit 1
}

check_requirements

if [[ $# -lt 2 ]]; then
    usage
    exit 1
fi

args=$(getopt -o "hp:o" --long "ro,overlay" -n $0 -- $@)
eval set -- "$args"

while true; do
    case "$1" in
        -h)
            usage
            exit 0;;
        -p)
            partId=$2
            shift 2;;
        --ro)
            mountOption=",ro"
            shift;;
        --overlay|-o)
            overlay=1
            mountOption=",ro"
            shift;;
        --)
            shift
            break;;
        *)
            echo "unrecognised argument: $1"
            exit 1;;
    esac
done


img=$1
mountPrefix=${2:-"/mnt"}

partition="none"

readarray partitions < <(partx -rg $img)

partToMount="$(seq ${#partitions[@]})"
if [ -v partId ];then 
    if [[ $partId -le ${#partitions[@]} ]];then
        partToMount="$partId"
    else
        echo "Partition ID out of range: ${#partitions[@]} partition(s) found"
        exit 1
    fi
fi

for i in $partToMount; do
    read i beg end sector size label < <(echo ${partitions[$((i-1))]})
    name=${label:-"${img%\.img}_$i"}
    offset=$(($beg*512))
    sizeLimit=$(($sector*512))
    mountPoint=${mountPrefix}/${name}

    if [ ! -d $mountPoint ]; then
        mkdir $mountPoint
    fi
    loopOptions="loop,offset=${offset},sizelimit=${sizeLimit}${mountOption}"

    if [ -v overlay ]; then
        lower=${mountPoint}/lower
        upper=${mountPoint}/upper
        workdir=${mountPoint}/workdir
        merged=${mountPoint}/merged
        for d in $lower $upper $workdir $merged; do
            if [ ! -d $d ]; then
                mkdir $d
            fi
        done
        mount ${img} $lower -o $loopOptions
        overlayOptions="lowerdir=$lower,upperdir=$upper,workdir=$workdir"
        mount -t overlay -o $overlayOptions none $merged
    else
        mount $img $mountPoint -o ${loopOptions}
    fi

done

