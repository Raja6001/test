#!/bin/bash
#
# Backup all MySQL Databases in this instance
#
# Last Modified: Nov-10-2023
#
# mysql -uroot -pAdmin@123 -A 
# CREATE USER 'backup_user'@'localhost' IDENTIFIED WITH MYSQL_NATIVE_PASSWORD BY 'BkP+nsR6';
# GRANT BACKUP_ADMIN, EVENT, EXECUTE, RELOAD, PROCESS, SELECT, SHOW DATABASES, SHOW VIEW, TRIGGER ON *.* TO 'backup_user'@'localhost'; 
# FLUSH PRIVILEGES;
# \q
# mysql_config_editor set --login-path=backup --host=localhost --user=backup_user --password --port=3306
# 
#export PATH="/bin:/usr/local/mysql8.0/bin:$PATH"

# directory to put the backup files
BACKUP_DIR=/tmp/mysql_backup

# MYSQL Parameters
#MYSQL_UNAME='dba'
TODAY=`date +"%d%b%Y"`

# Don't backup databases with these names
# Example: starts with mysql (^mysql) or ends with _schema (_schema$)
IGNORE_DB="(mysql|information_schema|performance_schema|sys)"

# Number of days to keep backups
KEEP_BACKUPS_FOR=10  #days

#Empty log file before starting
cp /dev/null /tmp/backupError.log
#==============================================================================
# METHODS
#==============================================================================

# YYYY-MM-DD
TIMESTAMP=$(date +%F)

function delete_old_backups()
{
# set -x
  echo "Deleting $BACKUP_DIR/* older than $KEEP_BACKUPS_FOR days"
#  find $BACKUP_DIR/* -mtime +$KEEP_BACKUPS_FOR -exec rm -rf {} \;
cd $BACKUP_DIR
ls -t | tail -n +$KEEP_BACKUPS_FOR | xargs rm -rf --
 if [ $? -ne 0 ]; then
        echo "Error Deleting Old Backups" >> /tmp/backupError.log
   fi
}

#function mysql_login() {
#  local mysql_login="-u $MYSQL_UNAME"
#  echo $mysql_login
#}

function database_list() {
  local show_databases_sql="SHOW DATABASES WHERE \`Database\` NOT REGEXP '$IGNORE_DB'"
  echo $(mysql --login-path=backup -e "$show_databases_sql"|awk -F " " '{if (NR!=1) print $1}')
  if [ $? -ne 0 ]; then
        echo "Error running show databases" >> /tmp/backupError.log
  fi

}

function echo_status(){
  printf '\r';
  printf ' %0.s' {0..100}
  printf '\r';
  printf "$1"'\r'
}

function backup_database(){
    mkdir -p ${BACKUP_DIR}/${TODAY}
    backup_file="$BACKUP_DIR/${TODAY}/$TIMESTAMP.$database.sql.gz"
    output+="$database => $backup_file\n"
    echo_status "...backing up $count of $total databases: $database"
    $(mysqldump --login-path=backup --opt --quick --single-transaction --routines --triggers --events --force $database | gzip -c > $backup_file)
    if [ $? -ne 0 ]; then
        echo "Error running mysqldump for $database" >> /tmp/backupError.log
    fi
}

function backup_databases(){
  local databases=$(database_list)
  local total=$(echo $databases | wc -w | xargs)
  local output=""
  local count=1
  for database in $databases; do
    backup_database
    local count=$((count+1))
  done
  echo -ne $output | column -t
}

function hr(){
  printf '=%.0s' {1..100}
  printf "\n"
}

#==============================================================================
# RUN SCRIPT
#==============================================================================
delete_old_backups
hr
backup_databases
hr
if [ -s /tmp/backupError.log ]; then
   cat /tmp/backupError.log # | mail -s "Error running backup on `hostname`" visubalan@infodynamic.in,shaik.m@infodynamic.in
   exit 1
else
   echo "All backed up!\n\n"
fi