#!/bin/bash
# wait-for-mysql.sh

set -e

host="$1"
db="$2"
sec=0

function checkDBstatus
{
        theHost=$1
        theDb=$2
        while [ `mysqlshow -h$theHost -uroot -ppassword $theDb | grep -v Wildcard | grep -c $theDb` == 0 ]
        do
                  echo "DB is unavailable - sleeping"
                  sleep 1
                  if [ $sec -gt 600 ];
                  then
                        echo "DB is still unavailable. Close connection by timeout"
                 	break
                  fi
                  sec=$((sec+1))
                  echo $sec
        done

}


checkDBstatus $host $db 

echo "DB is up - executing command"

