#!/bin/bash
#
# This script is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This script is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this script.  If not, see <http://www.gnu.org/licenses/>.
#
# Author: João Manoel <joaomanoel7@gmail.com>
# License: GPL <http://www.gnu.org/licenses/gpl.txt>
#
# When this script is ready, you can run:
# $ ocs-iso -g pt_BR.UTF-8 -k br -s -m ./clonetux-sms
# to create the iso file for CD/DVD. Or run:
# $ ocs-live-dev -g pt_BR.UTF-8 -k br -s -c -m ./clonetux-sms
# to create the zip file for USB flash drive.
#
# Begin of the script:
#
DRBL_SCRIPT_PATH="${DRBL_SCRIPT_PATH:-/usr/share/drbl}"

. $DRBL_SCRIPT_PATH/sbin/drbl-conf-functions
. /etc/drbl/drbl-ocs.conf
. $DRBL_SCRIPT_PATH/sbin/ocs-functions

# load the setting for clonezilla live.
. /etc/ocs/ocs-live.conf
# Load language files. For English, use "en_US.UTF-8". For Portuguese (Brazil), use "pt_BR.UTF-8"
ask_and_load_lang_set pt_BR.UTF-8
export LANG=pt_BR.UTF-8

#####################
# Functions - BEGIN #
#####################

get_devices ()
{
    DEVICES=

    IFS=$'\n'
    for disk_id in `ls -1 /dev/disk/by-id`
    do
        test -n "`echo $disk_id | egrep '^usb'`" && continue
        id_type="`udevadm info --query=property --name=/dev/disk/by-id/$disk_id | egrep '^ID_TYPE='  | sed 's/^ID_TYPE=//'`"
        test "$id_type" = "cd" && continue
        test -n "`echo $disk_id | egrep '^.*-part[1-9][0-9]*$'`" && continue
        devname="`udevadm info --query=property --name=/dev/disk/by-id/$disk_id | egrep '^DEVNAME=' | sed 's/^DEVNAME=//'`"
        test -n "`echo $DEVICES | grep $devname`" && continue
        DEVICES="$DEVICES\n$devname"
    done

    DEVICES="$DEVICES\n"
    DEVICES="`echo -en "$DEVICES" | sed '1d'`"

    return 0
}

get_partitions ()
{
    PARTITIONS=

    IFS=$'\n'
    for disk_id in `ls -1 /dev/disk/by-id`
    do
        test -n "`echo $disk_id | egrep '^usb'`" && continue
        id_type="`udevadm info --query=property --name=/dev/disk/by-id/$disk_id | egrep '^ID_TYPE='  | sed 's/^ID_TYPE=//'`"
        test "$id_type" = "cd" && continue
        test -z "`echo $disk_id | egrep '^.*-part[1-9][0-9]*$'`" && continue
        devname="`udevadm info --query=property --name=/dev/disk/by-id/$disk_id | egrep '^DEVNAME=' | sed 's/^DEVNAME=//'`"
        test -n "`echo $PARTITIONS | grep $devname`" && continue
        PARTITIONS="$PARTITIONS\n$devname"
    done

    PARTITIONS="$PARTITIONS\n"
    PARTITIONS="`echo -en "$PARTITIONS" | sed '1d'`"

    return 0
}

get_partitions_usb ()
{
    PARTITIONS_USB=

    IFS=$'\n'
    for disk_id in `ls -1 /dev/disk/by-id`
    do
        test -z "`echo $disk_id | egrep '^.*-part[1-9][0-9]*$'`" && continue
        devpath="`udevadm info --query=property --name=/dev/disk/by-id/$disk_id | egrep '^DEVPATH='  | sed 's/^DEVPATH=//'`"
        test -z "`echo $devpath | grep 'usb'`" && continue
        devname="`udevadm info --query=property --name=/dev/disk/by-id/$disk_id | egrep '^DEVNAME=' | sed 's/^DEVNAME=//'`"
	test -n "`echo $PARTITIONS_USB | grep $devname`" && continue
        PARTITIONS_USB="$PARTITIONS_USB\n$devname"
    done

    PARTITIONS_USB="$PARTITIONS_USB\n"
    PARTITIONS_USB="`echo -en "$PARTITIONS_USB" | sed '1d'`"

    return 0
}

save_home_saude ()
{
        IFS=$'\n'
        for partition in `echo -en "$PARTITIONS"`; do

            type="`udevadm info --query=property --name=$partition | egrep '^ID_FS_TYPE=' | sed -e 's/^ID_FS_TYPE=//'`"
            test "$type" != "ext2" \
              -a "$type" != "ext3" \
              -a "$type" != "ext4" \
              && continue

            sleep 2
            mount -t $type $partition $MNT_HDD >/dev/null 2>&1
            mount_err=$?
            sleep 2
            [ $mount_err -eq 0 ] && savefile_home_saude $MNT_HDD $SAVEFILE
            umount_partitions $partition

            if [ $BACKUP -eq 0 ]; then
                BACKUP_ERRORS=
                return $BACKUP
	    fi

            BACKUP_ERRORS="$BACKUP_ERRORS,$partition $BACKUP"

        done

	BACKUP_ERRORS="`echo -en "$BACKUP_ERRORS" | sed 's/^,//'`"
        return $BACKUP
}

savefile_home_saude ()
{
    BACKUP=1
    save_pwd="$PWD"
    cd $1

    IFS=$'\n'
    for backup in `ls -1`; do
        cd $1
        if [ "$backup" = "home" -o "$backup" = "saude" ]; then
            if [ "$backup" = "home" ]; then
                if [ -d "home/saude" ]; then
                    cd home
                else
                    continue
                fi
            fi
            rm -rf $LISTFILES
            find saude -type f | egrep -v '^.*\/\..*$' > $LISTFILES
            if [ "`file $LISTFILES | sed 's/^[^:]\{1,\}: //'`" = "empty" ]; then
        	BACKUP=2
        	continue
            fi
            if find saude -type f | egrep -v '^.*\/\..*$' | cpio -o -H ustar 2>/dev/null | gzip -9 -c >$2; then
                cd "$save_pwd"
                BACKUP=0
        	return $BACKUP
            else
                cd "$save_pwd"
                BACKUP=3
        	return $BACKUP
            fi
        fi
    done

    cd "$save_pwd"
    return $BACKUP
}

imprime ()
{
    if [ "$CORES" = "true" ]; then

        case "$3" in
            "azul")
                echo -en "${BBlue}${1}${Color_Off}"
                ;;
            "amarelo")
                echo -en "${BYellow}${1}${Color_Off}"
                ;;
            "branco")
                echo -en "${BWhite}${1}${Color_Off}"
                ;;
            "verde")
                echo -en "${BGreen}${1}${Color_Off}"
                ;;
            "vermelho")
                echo -en "${BRed}${1}${Color_Off}"
                ;;
            *)
                echo -en "$1"
                ;;
        esac

    else # CORES="false"

      echo -en "$1"

    fi

    test "$2" = "ok" && pressione_enter

    return 0
}

imprime_menu_devices ()
{
    imprime_cabecalho
    imprime "\n\t\tMENU DE OPÇÕES\n" "msg" "branco"

    opcao=1

    IFS=$'\n'
    for device in `echo -en "$DEVICES"`; do
        MODEL="`udevadm info --query=property --name=$device | egrep '^ID_MODEL=' | sed 's/^ID_MODEL=//'`"
        SERIAL="`udevadm info --query=property --name=$device | egrep '^ID_SERIAL_SHORT=' | sed 's/^ID_SERIAL_SHORT=//'`"
        imprime "\n$opcao) HD $MODEL $SERIAL\n" "msg" "branco"
        opcao=$((opcao+1))
    done

    return $opcao
}

imprime_ok ()
{
    sleep 1
    imprime "[ "    "msg" "branco"
    imprime "OK"    "msg" "verde"
    imprime " ]\n"  "msg" "branco"
    sleep 1
    return 0
}

imprime_falhou ()
{
    sleep 1
    imprime "[ "      "msg" "branco"
    imprime "FALHOU"  "msg" "vermelho"
    imprime " ]\n"    "msg" "branco"
    sleep 1
    return 0
}

pergunta ()
{
    resp=

    while true; do
        imprime "$1" "msg" "amarelo"
        read resp
        [ "$resp" = "S" -o "$resp" = "s" -o "$resp" = "N" -o "$resp" = "n" ] && break
    done

    [ "$resp"  = "S" -o "$resp" = "s" ] && return 0

    return 1
}

imprime_cabecalho ()
{
    clear
    imprime "\nPrefeitura de Goiânia-GO, Secretaria Municipal de Saúde - SMS\n\n" "msg" "azul"
    return 0
}

imprime_menu_principal ()
{
    imprime_cabecalho
    imprime "\n\t\t\tMENU DE OPÇÕES\n"               "msg" "branco"
    imprime "\n\t\t1) FAZER BACKUP DE /home/saude\n"   "msg" "branco"
    imprime "\n\t\t2) CRIAR PARTIÇÕES"                 "msg" "branco"
    imprime "\n\t\t3) FORMATAR PARTIÇÕES"              "msg" "branco"
    imprime "\n\t\t4) INSTALAR SISTEMA"                "msg" "branco"
    imprime "\n\t\t5) CONFIGURAR SISTEMA"              "msg" "branco"
    imprime "\n\t\t6) FINALIZAR (reboot)"              "msg" "branco"
    imprime "\n\t\t7) SAIR DESTE SCRIPT\n"             "msg" "branco"
    return 0
}

pressione_enter ()
{
    imprime "\nPressione <ENTGER> para continuar ... " "msg" "branco"
    read
    return 0
}

backup_home_saude ()
{
    imprime_cabecalho

    if [ $BACKUP -eq 0 ]; then
        imprime "\nJá foi realizado com sucesso o backup de /home/saude\n" "msg" "branco"
        pergunta "\nDeseja continuar mesmo assim ? (S/N) "
        if [ $? -eq 1 ]; then
            return 0
        fi
    fi

    imprime "\nFazendo a imagem de backup dos arquivos do usuário saude (/home/saude) ... " "msg" "branco"

    save_home_saude

    case $BACKUP in
        0)
            imprime_ok
            imprime "\nA imagem de backup foi salva com sucesso em:\n\n\t\t\"$SAVEFILE\"\n" "ok" "branco"
	    ;;
        100)
            imprime_falhou
            imprime "\nNão foi possível montar as partições para procurar pelo diretório /home/saude neste PC!\n" "ok" "branco"
            ;;
        *)
            imprime_falhou
	    if [ -n "$BACKUP_ERRORS" ]; then
		BACKUP_ERRORS="${BACKUP_ERRORS},"
                for ((c=1; ; c++)); do

                    backup_err="`echo -en "$BACKUP_ERRORS" | cut -d ',' -f $c`"
                    test -z "$backup_err" && break

                    partition="`echo -en "$backup_err" | cut -d ' ' -f 1`"
                    test -z "$partition" && break

                    backup="`echo -en "$backup_err" | cut -d ' ' -f 2`"
                    test -z "$backup" && break

                    case $backup in
                        1)
                            imprime "\n$partition: não foi possível encontrar o diretório /home/saude\n" "msg" "branco"
                            ;;
                        2)
                            imprime "\n$partition: não foi possível encontrar os arquivos do usuário saude\n" "msg" "branco"
                            ;;
                        3)
                            imprime "\n$partition: não foi possível fazer a imagem de backup em:\n\n\t\t\"$SAVEFILE\"\n" "msg" "branco"
                            ;;
                        *)
                            imprime "\n$partition: erro desconhecido!\n" "msg" "branco"
                            ;;
                    esac
                done
		pressione_enter
            else
                imprime "\nDesculpe, houve um erro desconhecido,\nfavor tentar fazer a imagem de backup novamente!\n" "ok" "branco"
		BACKUP=100
	    fi
            ;;
    esac

    return $BACKUP
}

make_partitions ()
{
    imprime_cabecalho

    if [ $MAKE_PARTITIONS -eq 0 ]; then
        imprime "\nJá foi realizado com sucesso o particionamento do HD\n" "msg" "branco"
        pregunta "\nDeseja continuar mesmo assim ? (S/N) "
        if [ $? -eq 1 ]; then
            return $MAKE_PARTITIONS
        fi
    fi

    if [ ! $BACKUP -eq 0 ]; then
        pergunta "\nDeseja mesmo continuar sem um backup de /home/saude ? (S/N) "
        if [ $? -eq 1 ]; then
            return $MAKE_PARTITIONS
        fi
    fi

    if [ -n "`echo "$DEVICES" | egrep '[[:blank:]]'`" ]; then
        
        while true; do
            opcoes=imprime_menu_devices
            imprime "\nEm qual HD você deseja instalar o Linux-SMS ? " "msg" "amarelo"
            read hd
            hd="`echo $hd | sed 's/[^[:digit:]]*//g'`"
            [ -z "$hd" ] && continue
            [ $hd -ge 1 -a $hd -le $opcoes ] && break
        done
        
        i=1
        
        IFS=$'\n'
        for DEVICE in `echo -en "$DEVICES"`; do
            if [ $hd -eq $i ]; then
        	MODEL="`udevadm info --query=property --name=$DEVICE | egrep '^ID_MODEL=' | sed 's/^ID_MODEL=//'`"
        	SERIAL="`udevadm info --query=property --name=$DEVICE | egrep '^ID_SERIAL_SHORT=' | sed 's/^ID_SERIAL_SHORT=//'`"
        	break
            fi
            i=$((i+1))
        done
        
    else
        
        DEVICE=$DEVICES
        MODEL="`udevadm info --query=property --name=$DEVICE | egrep '^ID_MODEL=' | sed 's/^ID_MODEL=//'`"
        SERIAL="`udevadm info --query=property --name=$DEVICE | egrep '^ID_SERIAL_SHORT=' | sed 's/^ID_SERIAL_SHORT=//'`"
        
    fi

    imprime "\nATENÇÃO SE CONTINUAR AGORA, SERÁ PARTICIONADO O HD $MODEL $SERIAL\nESTA OPERAÇÃO PODERÁ SER IRREVERSÍVEL\n" "msg" "branco"
    pergunta "\nDeseja continuar mesmo assim? (S/N) "
    if [ $? -eq 1 ]; then
        return $MAKE_PARTITIONS
    fi

    umount_partitions all

    imprime "\nCriando as partições no HD $MODEL $SERIAL ... " "msg" "branco"

    fdisk -l $DEVICE >/tmp/fdisk_${DEVICE////_}.1 2>/dev/null
    sleep 2

    "`fdisk $DEVICE <<EOF
o
n
p
1

+8G
n
p
2

+256M
n
p
3

+20G
t
2
82
w
EOF
`" >/dev/null 2>&1
    fdisk_err=$?
    sleep 2

    fdisk -l $DEVICE >/tmp/fdisk_${DEVICE////_}.2 2>/dev/null
    sleep 2

    if [ ! $fdisk_err -eq 0 ]; then
	if [ -z "`cmp /tmp/fdisk_${DEVICE////_}.1 /tmp/fdisk_${DEVICE////_}.2`" ]; then
            imprime_falhou
	    pressione_enter
            MAKE_PARTITIONS=1
            return $MAKE_PARTITIONS
	fi
	partprobe $DEVICE >/dev/null 2>&1
	sleep 2
    fi
    
    imprime_ok
    imprime "\nO HD $MODEL $SERIAL foi particionado com sucesso!\n" "ok" "branco"

    MAKE_PARTITIONS=0
    return $MAKE_PARTITIONS
}

umount_partitions ()
{
    if [ "$1" = "all" ]; then
        
        imprime "\nDesmontando possíveis partições montadas ... " "msg" "branco"

        IFS=$'\n'
        for partitions in `echo -en "$PARTITIONS"`; do
            sleep 2
            umount -f $partitions >/dev/null 2>&1
            sleep 2
        done

        IFS=$'\n'
        for partitions in `echo -en "$PARTITIONS" | sort -r`; do
            sleep 2
            umount -f $partitions >/dev/null 2>&1
            sleep 2
        done

        sleep 2
        umount -f $MNT_HDD >/dev/null 2>&1
        sleep 2

        imprime_ok

    else
        
        sleep 2
        umount -f "$1" >/dev/null 2>&1
        sleep 2
        
    fi

    return 0
}

format_partitions ()
{
    imprime_cabecalho

    if [ ! $MAKE_PARTITIONS -eq 0 ]; then
        imprime "\nO HD ainda não foi particionado, favor voltar depois de particionar o HD!\n" "ok" "branco"
        FORMAT_PARTITIONS=100
        return $FORMAT_PARTITIONS
    fi

    if [ $FORMAT_PARTITIONS -eq 0 ]; then
        imprime "\nO HD $MODEL $SERIAL já foi formatado!\n" "msg" "branco"
        pergunta "\nDeseja continuar mesmo assim? (S/N)"
        if [ $? -eq 1 ]; then
            return $FORMAT_PARTITIONS
        fi
    fi

    imprime "\nATENÇÃO SE CONTINUAR AGORA, SERÁ FORMATADO O HD $MODEL $SERIAL\nESTA OPERAÇÃO SERÁ IRREVERSÍVEL\n" "msg" "branco"
    pergunta "\nDeseja continuar mesmo assim? (S/N) "
    if [ $? -eq 1 ]; then
        return $FORMAT_PARTITIONS
    fi

    umount_partitions all

    imprime "\nFormatando a partição raiz (/) como EXT3 ... " "msg" "branco"
    mkfs.ext3 -L ROOT ${DEVICE}1 >/dev/null 2>&1
    if [ ! $? -eq 0 ]; then
        imprime_falhou
        FORMAT_PARTITIONS=1
        return $FORMAT_PARTITIONS
    fi
    imprime_ok
    
    imprime "\nFormatando a partição swap como SWAP ... " "msg" "branco"
    mkswap -L SWAP ${DEVICE}2 >/dev/null 2>&1
    if [ ! $? -eq 0 ]; then
        imprime_falhou
        FORMAT_PARTITIONS=2
        return $FORMAT_PARTITIONS
    fi
    imprime_ok
    
    imprime "\nFormatando a partição home (/home) como EXT3 ... " "msg" "branco"
    mkfs.ext3 -L HOME ${DEVICE}3 >/dev/null 2>&1
    if [ ! $? -eq 0 ]; then
        imprime_falhou
        FORMAT_PARTITIONS=3
        return $FORMAT_PARTITIONS
    fi
    imprime_ok

    imprime "\nA formatação do HD $MODEL $SERIAL foi feita com sucesso!\n" "ok" "branco"

    FORMAT_PARTITIONS=0
    return $FORMAT_PARTITIONS
}

instalar_sistema ()
{
    imprime_cabecalho

    if [ ! $MAKE_PARTITIONS -eq 0 ]; then
        imprime "\nO HD ainda não foi particionado, favor voltar depois de particionar e formatar o HD!\n" "ok" "branco"
        INSTALAR_SISTEMA=100
        return $INSTALAR_SISTEMA
    fi

    if [ ! $FORMAT_PARTITIONS -eq 0 ]; then
        imprime "\nO HD ainda não foi formatado, favor voltar depois de formatar o HD!\n" "ok" "branco"
        INSTALAR_SISTEMA=100
        return $INSTALAR_SISTEMA
    fi

    umount_partitions all

    imprime "\nCriando o diretório $MNT_HDD ... " "msg" "branco"
    mkdir -p $MNT_HDD >/dev/null 2>&1
    if [ ! $? -eq 0 ]; then
        imprime_falhou
        INSTALAR_SISTEMA=1
        return $INSTALAR_SISTEMA
    fi
    imprime_ok

    imprime "\nMontando a partição raiz (/) em $MNT_HDD ... " "msg" "branco"
    mount -t ext3 ${DEVICE}1 $MNT_HDD >/dev/null 2>&1
    mount_err=$?
    sleep 1.5
    if [ ! $mount_err -eq 0 ]; then
        imprime_falhou
        INSTALAR_SISTEMA=2
        return $INSTALAR_SISTEMA
    fi
    imprime_ok
    
    imprime "\nEntrando no diretório $MNT_HDD ... " "msg" "branco"
    cd $MNT_HDD >/dev/null 2>&1
    if [ ! $? -eq 0 ]; then
        imprime_falhou
        INSTALAR_SISTEMA=3
        return $INSTALAR_SISTEMA
    fi
    imprime_ok

    imprime "\nInstalando os arquivos do Linux-SMS em $MNT_HDD ... " "msg" "branco"
    zcat $SAVEDIR/rootfs.cpio.gz | cpio -idum 2>/dev/null
    if [ ! $? -eq 0 ]; then
        imprime_falhou
        INSTALAR_SISTEMA=4
        return $INSTALAR_SISTEMA
    fi
    imprime_ok
    
    imprime "\nCriando o diretório ${MNT_HDD}/home ... " "msg" "branco"
    mkdir -p ${MNT_HDD}/home >/dev/null 2>&1
    if [ ! $? -eq 0 ]; then
        imprime_falhou
        INSTALAR_SISTEMA=5
        return $INSTALAR_SISTEMA
    fi
    imprime_ok
    
    imprime "\nMontando a partição home (/home) em ${MNT_HDD}/home ... " "msg" "branco"
    mount -t ext3 ${DEVICE}3 ${MNT_HDD}/home >/dev/null 2>&1
    mount_err=$?
    sleep 1.5
    if [ ! $mount_err -eq 0 ]; then
        imprime_falhou
        INSTALAR_SISTEMA=6
        return $INSTALAR_SISTEMA
    fi
    imprime_ok

    imprime "\nEntrando no diretório ${MNT_HDD}/home ... " "msg" "branco"
    cd ${MNT_HDD}/home >/dev/null 2>&1
    if [ ! $? -eq 0 ]; then
        imprime_falhou
        INSTALAR_SISTEMA=7
        return $INSTALAR_SISTEMA
    fi
    imprime_ok
    
    imprime "\nInstalando os arquivos de /home/saude em ${MNT_HDD}/home/saude ... " "msg" "branco"
    zcat $SAVEDIR/saudefs.cpio.gz | cpio -idum 2>/dev/null
    if [ ! $? -eq 0 ]; then
        imprime_falhou
        INSTALAR_SISTEMA=8
        return $INSTALAR_SISTEMA
    fi
    imprime_ok
    
    if [ $BACKUP -eq 0 -a -f $SAVEFILE ]; then
        imprime "\nRestaurando o backup de /home/saude em ${MNT_HDD}/home/saude ... " "msg" "branco"
        zcat $SAVEFILE | cpio -idum 2>/dev/null
        if [ ! $? -eq 0 ]; then
            imprime_falhou
            imprime "\nSe finalizar a instalação agora, depois terá de restaurar manualmente o backup de /home/saude\n" "msg" "branco"
            if pergunta "\nDeseja finalizar a instalação agora? (S/N) "; then
        	INSTALAR_SISTEMA=0
        	return $INSTALAR_SISTEMA
            fi
            INSTALAR_SISTEMA=9
            return $INSTALAR_SISTEMA
        fi
        imprime_ok
    fi

    imprime "\nA instalação foi feita com sucesso!\n" "ok" "branco"
    
    INSTALAR_SISTEMA=0
    return $INSTALAR_SISTEMA
}

update_grub ()
{
        sleep 2
        
        mount proc $MNT_HDD/proc -t proc >/dev/null 2>&1
        mount_err=$?
        sleep 2
        test ! $mount_err -eq 0 && return 1
        
        mount sysfs $MNT_HDD/sys -t sysfs >/dev/null 2>&1
        mount_err=$?
        sleep 2
        test ! $mount_err -eq 0 && return 2
        
        mount udev $MNT_HDD/dev -t devtmpfs >/dev/null 2>&1
        mount_err=$?
        sleep 2
        test ! $mount_err -eq 0 && return 3
        
        mount devpts $MNT_HDD/dev/pts -t devpts >/dev/null 2>&1
        mount_err=$?
        sleep 2
        test ! $mount_err -eq 0 && return 4
        
        chroot $MNT_HDD /usr/sbin/grub-install --recheck $DEVICE >/dev/null 2>&1
        test ! $? -eq 0 && return 5
        sleep 2
        
        chroot $MNT_HDD /usr/sbin/update-grub >/dev/null 2>&1
        test ! $? -eq 0 && return 6
        sleep 2

        umount -f $MNT_HDD/dev/pts >/dev/null 2>&1; sleep 2
        umount -f $MNT_HDD/dev     >/dev/null 2>&1; sleep 2
        umount -f $MNT_HDD/sys     >/dev/null 2>&1; sleep 2
        umount -f $MNT_HDD/proc    >/dev/null 2>&1; sleep 2

        return 0
}

update_fstab ()
{
    UUID1="`udevadm info --query=property --name=${DEVICE}1 | egrep '^ID_FS_UUID=' | sed 's/^ID_FS_//'`"
    sed "s/^UUID=[[:xdigit:]\-]\{1,\}[[:blank:]]\{1,\}\/[[:blank:]]\{1,\}.*$/$UUID1\t\/\text3\terrors=remount-ro\t0\t1/" -i $MNT_HDD/etc/fstab >/dev/null 2>&1
    sed_err=$?
    sleep 1
    test ! $sed_err -eq 0 && return 1

    UUID2="`udevadm info --query=property --name=${DEVICE}2 | egrep '^ID_FS_UUID=' | sed 's/^ID_FS_//'`"
    sed "s/^UUID=[[:xdigit:]\-]\{1,\}[[:blank:]]\{1,\}none[[:blank:]]\{1,\}swap.*$/$UUID2\tnone\tswap\tsw\t0\t0/" -i $MNT_HDD/etc/fstab >/dev/null 2>&1
    sed_err=$?
    sleep 1
    test ! $sed_err -eq 0 && return 2

    UUID3="`udevadm info --query=property --name=${DEVICE}3 | egrep '^ID_FS_UUID=' | sed 's/^ID_FS_//'`"
    sed "s/^UUID=[[:xdigit:]\-]\{1,\}[[:blank:]]\{1,\}\/home[[:blank:]]\{1,\}.*$/$UUID3\t\/home\text3\tdefaults\t0\t2/" -i $MNT_HDD/etc/fstab >/dev/null 2>&1
    sed_err=$?
    sleep 1
    test ! $sed_err -eq 0 && return 3

    return 0
}

configurar_sistema ()
{
    imprime_cabecalho
    
    if [ ! $MAKE_PARTITIONS -eq 0 ]; then
        imprime "\nO HD ainda não foi particionado,\nfavor voltar depois de particionar e formatar o HD, e instalar o sistema!\n" "ok" "branco"
        CONFIGURAR_SISTEMA=100
        return $CONFIGURAR_SISTEMA
    fi

    if [ ! $FORMAT_PARTITIONS -eq 0 ]; then
        imprime "\nO HD ainda não foi formatado, favor voltar depois de particionar o HD, e instalar o sistema!\n" "ok" "branco"
        CONFIGURAR_SISTEMA=100
        return $CONFIGURAR_SISTEMA
    fi

    if [ ! $INSTALAR_SISTEMA -eq 0 ]; then
        imprime "\nO Sistema ainda não foi instalado, favor voltar depois de instalar o sistema!\n" "ok" "branco"
        CONFIGURAR_SISTEMA=100
        return $CONFIGURAR_SISTEMA
    fi

    imprime "\nAtualizando /etc/fstab em ${DEVICE} ... " "msg" "branco"
    update_fstab
    if [ ! $? -eq 0 ]; then
        imprime_falhou
        CONFIGURAR_SISTEMA=1
        return $CONFIGURAR_SISTEMA
    fi
    imprime_ok

    imprime "\nAtualizando o grub em ${DEVICE} ... " "msg" "branco"
    update_grub
    if [ ! $? -eq 0 ]; then
        imprime_falhou
        CONFIGURAR_SISTEMA=2
        return $CONFIGURAR_SISTEMA
    fi
    imprime_ok

    imprime "\nA Configuração do sistema foi um sucesso!\n" "ok" "branco"
    CONFIGURAR_SISTEMA=0
    return $CONFIGURAR_SISTEMA
}

checksum_images () {
    $CHECKSUM_CMD -c ./rootfs.cpio.gz.$CHECKSUM_EXT >/dev/null 2>&1 || return 1
    $CHECKSUM_CMD -c ./saudefs.cpio.gz.$CHECKSUM_EXT >/dev/null 2>&1 || return 2
    return 0
}

exist_images () {
    if [ "`mount | grep '/lib/live/mount/medium' | sed -e 's/^.*type //' -e 's/ .*$//'`" = "iso9660" ]; then
	FIND_USB="true"
	get_partitions_usb
        IFS=$'\n'
        for partitions_usb in `echo -en "$PARTITIONS_USB"`; do
	    umount_partitions $partitions_usb
	    mount $partitions_usb $MNT_SDD >/dev/null 2>&1
	    mount_err=$?
	    sleep 2
	    test ! $mount_err -eq 0 $$ continue
	    if [ ! -f "$MNT_SDD/saude/rootfs.cpio.gz" -o \
		 ! -f "$MNT_SDD/saude/rootfs.cpio.gz.$CHECKSUM_EXT" -o \
		 ! -f "$MNT_SDD/saude/saudefs.cpio.gz" -o \
		 ! -f "$MNT_SDD/saude/saudefs.cpio.gz.$CHECKSUM_EXT" ]; then
		umount_partitions $partitions_usb
		continue
	    fi
      	    SAVEDIR="$MNT_SDD/saude"
	    SAVEFILE="$SAVEDIR/saudefs.bak.cpio.gz"
	    test -f "$SAVEFILE" && BACKUP=0
	    return 0
	done
    else
	test ! -d "$SAVEDIR/" && return 1
	test ! -f "$SAVEDIR/rootfs.cpio.gz" && return 2
	test ! -f "$SAVEDIR/rootfs.cpio.gz.$CHECKSUM_EXT" && return 3
	test ! -f "$SAVEDIR/saudefs.cpio.gz" && return 4
	test ! -f "$SAVEDIR/saudefs.cpio.gz.$CHECKSUM_EXT" && return 5
	test -f "$SAVEFILE" && BACKUP=0
	return 0
    fi
    return 1
}

###################
# Functions - END #
###################

################
# Main - BEGIN #
################

CHECKSUM_CMD="/usr/bin/md5sum"
CHECKSUM_EXT="md5"

TMP="$(mktemp /tmp/menu.XXXXXX)"
LISTFILES="/tmp/saude.list"
SAVEDIR="/lib/live/mount/medium/saude"
test -d "$1" && SAVEDIR="$1"
SAVEFILE="$SAVEDIR/saudefs.bak.cpio.gz"
MNT_HDD="/mnt/hdd"
MNT_SDD="/mnt/sdd"

BACKUP=100
MAKE_PARTITIONS=100
FORMAT_PARTITIONS=100
INSTALAR_SISTEMA=100
CONFIGURAR_SISTEMA=100

FIND_USB="false"
DEVICES=
DEVICE=
MODEL=
SERIAL=
PARTITIONS=
PARTITIONS_USB=
PARTITION=
BACKUP_ERRORS=

if [ -x /usr/bin/tput -o -x /bin/tput ] && tput setaf 1 >/dev/null 2>&1; then
    CORES="true"
    . $SAVEDIR/bash_colors
else
    CORES="false"
fi

IFS=$'\n'
unalias -a
mkdir -p $MNT_HDD
mkdir -p $MNT_SDD

imprime_cabecalho

imprime "\nVerificando a existência das imagens para clonagem ... " "msg" "branco"
exist_images
exist_images_err=$?
if [ ! $exist_images_err -eq 0 ]; then
    imprime_falhou
    if [ "${FIND_USB:-false}" = "true" ]; then
	imprime "\nNão foi possível encontrar um dispositivo USB conectado que tenha,\num diretório \"saude\" na raiz com as seguintes imagens/checksums necessários(as):\n\t\trootfs.cpio.gz\n\t\trootfs.cpio.gz.$CHECKSUM_EXT\n\t\tsaudefs.cpio.gz\n\t\tsaudefs.cpio.gz.$CHECKSUM_EXT\n" "msg" "branco"
    else
	case $exist_images_err in
	    1)
		imprime "\nImpossível continuar, não existe o diretório das imagens:\n\n\t\t\"$SAVEDIR\"\n" "ok" "branco"
		;;
	    2)
		imprime "\nImpossível continuar, não existe a imagem:\n\n\t\t\"$SAVEDIR/rootfs.cpio.gz\"\n" "ok" "branco"
		;;
	    3)
		imprime "\nImpossível continuar, não existe o checksum:\n\n\t\t\"$SAVEDIR/rootfs.cpio.gz.$CHECKSUM_EXT\"\n" "ok" "branco"
		;;
	    4)
		imprime "\nImpossível continuar, não existe a imagem:\n\n\t\t\"$SAVEDIR/saudefs.cpio.gz\"\n" "ok" "branco"
		;;
	    5)
		imprime "\nImpossível continuar, não existe o checksum:\n\n\t\t\"$SAVEDIR/saudefs.cpio.gz.$CHECKSUM_EXT\"\n" "ok" "branco"
		;;
	    *)
		imprime "\nDesculpe, houve um erro desconhecido, tente novamente!\n" "ok" "branco"
		;;
	esac
    fi
    imprime "\nDICA: tente executar este script da seguinte forma:\n\t\t$0 <diretorio>\nOnde: <diretorio> é o caminho completo para o diretorio das imagens/checksums\n" "ok" "branco"
    exit 1
fi
imprime_ok

cd "$SAVEDIR"

if [ $BACKUP -eq 0 ]; then
    imprime "\nExiste uma imagem de backup dos arquivos do usuário saúde, salvo em:\n\n\t\t\"$SAVEFILE\"\n" "msg" "branco"
    pergunta "\nDeseja utilizar esta imagem? (S/N) "
    if [ $? -eq 1 ]; then
	for ((i=0; ; i++)); do
	    if [ ! -e "$SAVEFILE.$i" ]; then
		mv -f "$SAVEFILE" "$SAVEFILE.$i" >/dev/null 2>&1
		break
	    fi
	done
	BACKUP=100
    fi
fi

imprime "\nVerificando a soma ${CHECKSUM_EXT^^} das imagens para clonagem ... " "msg" "branco"
checksum_images
checksum_images_err=$?
if [ ! $checksum_images_err -eq 0 ]; then
    imprime_falhou
    case $checksum_images_err in
	1)
	    imprime "\nImpossível continuar, falhou a soma ${CHECKSUM_EXT^^} da imagem:\n\n\t\t\"$SAVEDIR/rootfs.cpio.gz\"\n" "ok" "branco"
	    ;;
	2)
	    imprime "\nImpossível continuar, falhou a soma ${CHECKSUM_EXT^^} da imagem:\n\n\t\t\"$SAVEDIR/saudefs.cpio.gz\"\n" "ok" "branco"
	    ;;
	*)
	    imprime "\nDesculpe, houve um erro desconhecido, tente novamente!\n" "ok" "branco"
	    ;;
    esac
    exit 2
fi
imprime_ok

get_devices
if [ ! $? -eq 0 ]; then
    imprime "\nNão foi possível ler/encontrar os HDs presentes neste PC!\n" "ok" "branco"
    exit 3
fi

get_partitions
if [ ! $? -eq 0 ]; then
    imprime "\nNão foi possível ler/encontrar as partições dos HDs presentes neste PC!\n" "ok" "branco"
    exit 4
fi

umount_partitions all

while true; do

    trap "[ -f "$TMP" ] && rm -f $TMP" HUP INT QUIT TERM EXIT
    $DIA --backtitle "Prefeitura de Goiânia-GO, Secretaria Municipal de Saúde - SMS" --title  \
	"CloneTux - SMS" --menu "\n    Menu de opções:" \
	0 0 0 \
	"1" "Fazer backup de /home/saude" \
	"2" "Criar partições" \
	"3" "Formatar partições" \
	"4" "Instalar sistema" \
	"5" "Configurar sistema" \
	"6" "Finalizar (reboot)" \
	"7" "Sair deste script" \
	2> $TMP
    op="$(cat $TMP)"
    [ -f "$TMP" ] && rm -f $TMP

    if [ -z "$op" ]; then
        if [ ! $CONFIGURAR_SISTEMA -eq 0 ]; then
            pergunta "\nSistema ainda não foi instalado e configurado, deseja mesmo sair? (S/N) "
            test $? -eq 1 && continue
            umount_partitions all
            exit 1
        fi
        break
    fi

    case $op in
        1)
            backup_home_saude
            ;;
        2)
            make_partitions
            ;;
        3)
            format_partitions
            ;;
        4)
            instalar_sistema
            ;;
        5)
            configurar_sistema
            ;;
        6)
            if [ ! $CONFIGURAR_SISTEMA -eq 0 ]; then
        	pergunta "\nSistema ainda não foi instalado e configurado, deseja mesmo finalizar(reboot)? (S/N) "
        	test $? -eq 1 && continue
            fi
            reboot
            ;;
        7)
            if [ ! $CONFIGURAR_SISTEMA -eq 0 ]; then
        	pergunta "\nSistema ainda não foi instalado e configurado, deseja mesmo sair? (S/N) "
        	test $? -eq 1 && continue
        	umount_partitions all
        	exit 1
            fi
            break
            ;;
	*)
	    imprime "\nOpção desconhecida: \"$op\"! Favor tentar novamente.\n" "ok" "branco"
	    ;;
    esac

done

umount_partitions all

##############
# Main - END #
##############

exit 0
