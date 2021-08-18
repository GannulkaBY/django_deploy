#!/bin/bash
# Usage sample: ./deploy.sh chulets@192.168.100.19 /opt/soft/django 30
set -e


inServer=$1
inPath=$2
inVersion=$3

# Returns error and exits the script
die() {
    echo "Dying: $@"
    exit 10
}

#Check input parameters
if [ -z "$inServer" ]; then
    die "No server is set"
fi

if [ -z "$inPath" ]; then
    die "No dockerComposePath is set"
fi

if [ -z "$inVersion" ]; then
    die "No application version is set"
fi

if [ "$(ssh $inServer docker images -q gannagp/django:$inVersion 2> /dev/null)" == "" ]; then
  die "Specified image tag does not exist in registry"
fi

if [ "$(ssh $inServer docker images -q gannagp/reverse:$inVersion 2> /dev/null)" == "" ]; then
  die "Specified image tag does not exist in registry"
fi


backupCompose(){
    echo "$(date --rfc-3339='ns'): ********* Prepare backup and set new version to docker-compose *********"
    oldVersion=`ssh $inServer grep -a 'gannagp\/django' $inPath/docker-compose.yml | cut -f3 -d':'`
    ssh $inServer "mkdir -p $inPath/backup/$inVersion && \
                cp $inPath/docker-compose.yml $inPath/backup/$inVersion && \
                sed -i 's/$oldVersion/$inVersion/g' $inPath/docker-compose.yml
    "
}

containerId=""

getContainerId(){
    containerId="$(ssh $inServer docker container ls | grep django_web | tr -s ' '| cut -f1 -d' ')"
}

if [ `ssh $inServer ls -d $inPath  2> /dev/null| wc -l` == 0  ]
 then
    echo "$(date --rfc-3339='ns'): ********* Prepare folder for deployment from scratch *********"
    ssh $inServer "mkdir -p $inPath && \
                   mkdir -p $inPath/db_django"
    scp docker-compose.yml $inServer:/$inPath
    scp manage.py $inServer:/$inPath
    scp -r web_django $inServer:/$inPath
    backupCompose
    echo "$(date --rfc-3339='ns'): ********* Run docker stack django *********"
    ssh $inServer docker stack deploy -c$inPath/docker-compose.yml django
    sleep 30
    echo "$(date --rfc-3339='ns'): ********* Apply migrations to database *********"
    getContainerId
    echo $containerId
    sleep 60
    ssh $inServer docker exec -i $containerId python manage.py makemigrations
    ssh $inServer docker exec -i $containerId python manage.py migrate
    ssh $inServer docker service update --force django_web
    getContainerId
    echo $containerId
    ssh $inServer " echo \"from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@myproject.com', 'password')\" | docker exec -i $containerId python manage.py shell "

else
    backupCompose
    echo "$(date --rfc-3339='ns'): ********* Update django_web to new $inVersion *********"
    ssh $inServer docker service update --force django_web --image gannagp/django:$inVersion 
fi

