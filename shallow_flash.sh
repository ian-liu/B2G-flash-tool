#!/bin/bash
#==========================================================================
# 
# IMPORTANT: only for internal use!
# 
# Description:
#   This script was written for shallow flash the gaia and/or gecko.
#
# Author: Askeing fyen@mozilla.com
# History:
#   2013/08/02 Askeing: v1.0 First release.
#==========================================================================


####################
# Parameter Flags  #
####################
VERY_SURE=false
ADB_DEVICE="Device"
FLASH_GAIA=false
FLASH_GAIA_FILE=""
FLASH_GECKO=false
FLASH_GECKO_FILE=""


####################
# Functions        #
####################

## helper function
function helper(){
    echo -e "This script was written for shallow flash the gaia and/or gecko.\n"
    echo -e "Usage: ./shallow_flash.sh [parameters]"
    echo -e "-g|--gaia\tFlash the gaia (zip format) into your device."
    echo -e "-G|--gecko\tFlash the gecko (tar.gz format) into your device."
    echo -e "-s <serial number>\tdirects command to device with the given serial number."
    echo -e "-y\t\tflash the file without asking askeing (it's a joke...)"
    echo -e "-h|--help\tDisplay help."
    echo -e "Example:"
    echo -e "  Flash gaia.\t\t./shallow_flash.sh --gaia=gaia.zip"
    echo -e "  Flash gecko.\t\t./shallow_flash.sh --gecko=b2g-18.0.en-US.android-arm.tar.gz"
    echo -e "  Flash gaia and gecko.\t./shallow_flash.sh -ggaia.zip -Gb2g-18.0.en-US.android-arm.tar.gz"
    exit 0
}

## adb with flags
function run_adb()
{
    # TODO: Bug 875534 - Unable to direct ADB forward command to inari devices due to colon (:) in serial ID
    # If there is colon in serial number, this script will have some warning message.
	adb $ADB_FLAGS $@
}

## make sure user want to shallow flash
function make_sure() {
    echo "Are you sure you want to flash "
    if [ $FLASH_GAIA == true ]; then
        echo -e "Gaia: $FLASH_GAIA_FILE "
    fi
    if [ $FLASH_GECKO == true ]; then
        echo -e "Gecko: $FLASH_GECKO_FILE "
    fi
    read -p "to your $ADB_DEVICE? [y/N]" isFlash
    test "$isFlash" != "y"  && test "$isFlash" != "Y" && echo -e "byebye." && exit 0
}

## adb root, then remount and stop b2g
function adb_root_remount() {
    run_adb root
    run_adb wait-for-device     #in: gedit display issue
    run_adb remount
    run_adb wait-for-device     #in: gedit display issue
    run_adb shell mount -o remount,rw /system &&
    run_adb wait-for-device     #in: gedit display issue
    run_adb shell stop b2g
    run_adb wait-for-device     #in: gedit display issue
}

## adb sync then reboot
function adb_reboot() {
    run_adb shell sync
    run_adb shell reboot
    run_adb wait-for-device     #in: gedit display issue
}

## clean cache, gaia (webapps) and profiles
function adb_clean_gaia() {
    echo "Clean Gaia and profiles ..."
    run_adb shell rm -r /cache/* &&
    run_adb shell rm -r /data/b2g/* &&
    run_adb shell rm -r /data/local/webapps &&
    run_adb shell rm -r /data/local/user.js &&
    run_adb shell rm -r /data/local/permissions.sqlite* &&
    run_adb shell rm -r /data/local/OfflineCache &&
    run_adb shell rm -r /data/local/indexedDB &&
    run_adb shell rm -r /data/local/debug_info_trigger &&
    run_adb shell rm -r /system/b2g/webapps &&
    echo "Clean Done."
}

## push gaia into device
function adb_push_gaia() {
    GAIA_DIR=$1
    ## Adjusting user.js
    cat $GAIA_DIR/gaia/profile/user.js | sed -e "s/user_pref/pref/" > $GAIA_DIR/user.js
    
    echo "Push Gaia ..."
    run_adb shell mkdir -p /system/b2g/defaults/pref &&
    run_adb push $GAIA_DIR/gaia/profile/webapps /system/b2g/webapps &&
    run_adb push $GAIA_DIR/user.js /system/b2g/defaults/pref &&
    run_adb push $GAIA_DIR/gaia/profile/settings.json /system/b2g/defaults &&
    echo "Push Done."
}

## shallow flash gaia
function shallow_flash_gaia() {
    GAIA_ZIP_FILE=$1
    
    if ! [ -f $GAIA_ZIP_FILE ]; then
        echo "Cannot found $GAIA_ZIP_FILE file."
        exit -1
    fi

    if ! which mktemp > /dev/null; then
        echo "Package \"mktemp\" not found!"
        rm -rf ./shallowflashgaia_temp
        mkdir shallowflashgaia_temp
        cd shallowflashgaia_temp
        TMP_DIR=`pwd`
        cd ..
    else
        TMP_DIR=`mktemp -d -t shallowflashgaia.XXXXXXXXXXXX`
    fi

    unzip_file $GAIA_ZIP_FILE $TMP_DIR &&
    adb_clean_gaia &&
    adb_push_gaia $TMP_DIR

    rm -rf $TMP_DIR
}

## unzip zip file
function unzip_file() {
    ZIP_FILE=$1
    DEST_DIR=$2
    if ! [ -z $ZIP_FILE ]; then
        test ! -f $ZIP_FILE && echo -e "The file $ZIP_FILE DO NOT exist." && exit 1
    fi
    echo "Unzip $ZIP_FILE to $DEST_DIR ..."
    test -e $ZIP_FILE && unzip -q $ZIP_FILE -d $DEST_DIR || echo "Unzip $ZIP_FILE Failed."
    #ls -LR $DEST_DIR
}

## shallow flash gecko
function shallow_flash_gecko() {
    GECKO_TAR_FILE=$1

    if ! [ -f $GECKO_TAR_FILE ]; then
        echo "Cannot found $GECKO_TAR_FILE file."
        exit -1
    fi

    if ! which mktemp > /dev/null; then
        echo "Package \"mktemp\" not found!"
        rm -rf ./shallowflashgecko_temp
        mkdir shallowflashgecko_temp
        cd shallowflashgecko_temp
        TMP_DIR=`pwd`
        cd ..
    else
        TMP_DIR=`mktemp -d -t shallowflashgaia.XXXXXXXXXXXX`
    fi
    
    untar_file $GECKO_TAR_FILE $TMP_DIR &&
    echo "Push Gecko ..."
    ## push gecko into device
    run_adb push $TMP_DIR/b2g /system/b2g &&
    echo "Push Done."
    
    rm -rf $TMP_DIR
}

## untar tar.gz file
function untar_file() {
    TAR_FILE=$1
    DEST_DIR=$2
    if ! [ -z $TAR_FILE ]; then
        test ! -f $TAR_FILE && echo -e "The file $TAR_FILE DO NOT exist." && exit 1
    fi
    echo "Untar $TAR_FILE to $DEST_DIR ..."
    test -e $TAR_FILE && tar -xzf $TAR_FILE -C $DEST_DIR || echo "Untar $TAR_FILE Failed."
    #ls -LR $DEST_DIR
}


#########################
# Processing Parameters #
#########################

## show helper if nothing specified
if [ $# = 0 ]; then echo "Nothing specified"; helper; exit 0; fi

## distinguish platform
case `uname` in
    "Linux")
        ## add getopt argument parsing
        TEMP=`getopt -o g::G::s::yh --long gaia::,gecko::,help \
        -n 'invalid option' -- "$@"`

        if [ $? != 0 ]; then echo "Try '--help' for more information." >&2; exit 1; fi

        eval set -- "$TEMP";;
    "Darwin");;
esac

while true
do
    case "$1" in
        -g|--gaia) 
            FLASH_GAIA=true;
            case "$2" in
                "") FLASH_GAIA_FILE="gaia.zip"; shift 2;;
                *) FLASH_GAIA_FILE=$2; shift 2;;
            esac ;;
        -G|--gecko)
            FLASH_GECKO=true;
            case "$2" in
                "") FLASH_GECKO_FILE="b2g-18.0.en-US.android-arm.tar.gz"; shift 2;;
                *) FLASH_GECKO_FILE=$2; shift 2;;
            esac ;;
        -s)
            case "$2" in
                "") shift 2;;
                *) ADB_DEVICE=$2; ADB_FLAGS+="-s $2"; shift 2;;
            esac ;;
        -y) VERY_SURE=true; shift;;
        -h|--help) helper; exit 0;;
        --) shift;break;;
        "") shift;break;;
        *) helper; echo error occured; exit 1;;
    esac
done


####################
# Make Sure        #
####################
if [ $VERY_SURE == false ] && ([ $FLASH_GAIA == true ] || [ $FLASH_GECKO == true ]); then
    make_sure
fi
if ! [ -f $FLASH_GAIA_FILE ] && [ $FLASH_GAIA == true ]; then
    echo "Cannot found $FLASH_GAIA_FILE file."
    exit -1
fi
if ! [ -f $FLASH_GECKO_FILE ] && [ $FLASH_GECKO == true ]; then
    echo "Cannot found $FLASH_GECKO_FILE file."
    exit -1
fi


####################
# ADB Work         #
####################
adb_root_remount


####################
# Processing Gaia  #
####################
if [ $FLASH_GAIA == true ]; then
    echo "Processing Gaia: $FLASH_GAIA_FILE"
    shallow_flash_gaia $FLASH_GAIA_FILE
fi


####################
# Processing Gecko #
####################
if [ $FLASH_GECKO == true ]; then
    echo "Processing Gecko: $FLASH_GECKO_FILE"
    shallow_flash_gecko $FLASH_GECKO_FILE
fi


####################
# ADB Work         #
####################
adb_reboot


####################
# Version          #
####################
if [ -e ./check_versions.sh ]; then
    bash ./check_versions.sh
fi


####################
# Done             #
####################
echo -e "Shallow Flash Done!"


