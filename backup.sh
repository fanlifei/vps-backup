#! /bin/bash
#===============================================================================================
#   System Required:  CentOS6.x (32bit/64bit)
#   Description: Server backup and restore script
#   Author: Jalena <jalena@bcsytv.com>
#   Intro:  https://jalena.bcsytv.com/archives/1358
#===============================================================================================

[[ $EUID -ne 0 ]] && echo 'Error: This script must be run as root!' && exit 1

# global variables
variables(){
    current_date=`date +%Y%m%d`
    backup_dir="/root/backup"
}

# Initialize the database of account information
initialization(){
    if [[ ! -e '/root/.my.cnf' ]]; then
        read -p "Please enter the MySQL user (Default : root): " MYSQL_USER
        [[ -z "$MYSQL_USER" ]] && MYSQL_USER="root"
        read -p "Please enter the MySQL password:" MYSQL_PASS
        echo -e "---------------------------"
        echo -e "MySQL User = $MYSQL_USER"
        echo -e "MySQL Pass = $MYSQL_PASS"
        echo -e "---------------------------"
cat > /root/.my.cnf<<EOF
[client]
user=$MYSQL_USER
password=$MYSQL_PASS

[mysqldump]
user=$MYSQL_USER
password=$MYSQL_PASS
EOF
    fi

    if [[ ! -e '.backup.option' ]]; then
        read -p "Please enter the web Path (Default : /data/wwwroot):" WEB_PATH
            [[ -z $WEB_PATH ]] && WEB_PATH="/data/wwwroot"
        read -p "Please enter the nginx configuration path (Default : /usr/local/nginx/conf/vhost):" NGINX_PATH
            [[ -z $NGINX_PATH ]] && NGINX_PATH="/usr/local/nginx/conf/vhost"
        echo -e "---------------------------"
        echo -e "Backup directory = $WEB_PATH"
        echo -e "nginx directory = $NGINX_PATH"
        echo -e "---------------------------"
cat > /root/.backup.option<<EOF
WEB_PATH=$WEB_PATH
NGINX_PATH=$NGINX_PATH
EOF
    fi
}

initialization_check(){
    variables # The global variable
    if [[ -e '/root/.backup.option' ]]; then
        source .backup.option # Can be used .
    else
        echo -e "Not initialized, Please enter: \033[032m./backup.sh init"
        exit 1
    fi

    if [[ -d $backup_dir ]]; then
        cd $backup_dir
    else
        mkdir -p $backup_dir
        cd $backup_dir
    fi

    if [[ ! -e '/root/.my.cnf' ]]; then
        echo -e "Not initialized, Please enter: \033[032m./backup.sh init"
        exit 1
    fi
}

# Backup all database tables
backup_database(){
    for db in $(mysql -B -N -e 'SHOW DATABASES' |sed -e '/_schema/d' -e '/mysql/d' -e '/sys/d')
        do
            mysqldump ${db} | gzip -9 - > ${db}.sql.gz
            echo -e "\t\e[1;32m--- Backup data table \e[1;31m${db} \e[1;32msuccess! ---\e[0m"
    done

    # Pack all database tables
    tar zcf mysql_$current_date.tar.gz *.sql.gz --remove-files
}

# Packing site data
packing_data(){
    for web in $(ls -1 ${WEB_PATH} |sed -e '/phpMy/d')
    do
        tar zcPf ${web}_$current_date.tar.gz ${WEB_PATH}/${web}
        echo -e "\t\e[1;32m--- package \e[1;31m${web} \e[1;32msuccess! ---\e[0m"
    done
}

# package the nginx configuration file
configuration(){
    tar cPf nginx_$current_date.tar.gz $NGINX_PATH
    echo -e "\t\e[1;32m--- package \e[1;31mnginx_$current_date.tar.gz \e[1;32msuccess! ---\e[0m"
    find / -name nginx.conf |grep -v root | xargs tar rPf nginx_$current_date.tar.gz
    echo -e "\t\e[1;32m--- Additional file successfully ---\e[0m"
}

# Upload data
upload_file(){
    variables
    cd ~
    # Upload data
    for file in $(ls -1 $backup_dir)
        do
            #scp ${file} root@23.239.196.3:/root/backup/${file}
            #sh /root/dropbox_uploader.sh upload ${file} backup/${file}
            ./qshell fput backup ${file} ${backup_dir}/${file} http://up.qiniug.com
    done
}

# Restore all data
restore_all(){
    initialization_check
    tar zxf mysql*.tar.gz
    for db in $(find *.sql.gz | sed 's/.sql.gz//g')
        do
            mysqladmin create ${db}
            gunzip -f < ${db}.sql.gz | mysql ${db}
    done

    for web in $(ls -1 *.tar.gz| grep -v mysql |grep -v nginx)
        do
            tar zxPf ${web}
    done

    for nginx in $(ls -1 nginx*)
        do
            tar zxPf ${nginx}
    done
}

# Initialization settings
initial_setup(){
    initialization
}

backup_db(){
    initialization_check
    backup_database
}

# Full backup
backup_all(){
    initialization_check
    backup_database
    packing_data
    configuration
    upload_file
}

# Initialization step
action=$1
# [  -z $1 ] && action=backup
case "$action" in
init)
    initial_setup
    ;;
backup)
    backup_all
    ;;
db)
    backup_db
    ;;
up)
    upload_file
    ;;
Restore)
    restore_all
    ;;
*)
    echo -e "\n\t\e[1;32mUsage: \e[1;33m./backup.sh init|backup|db|Restore\n\e[0m"
    ;;
esac
