#!/bin/bash
# Usage sample: ./deploy.sh chulets@192.168.100.19 /opt/soft/django 30
set -e


inServer=$1
inPath=$2
inVersion=$3
registry="gannagp"
app="django"
nginx="reverse"
ssh="ssh $inServer"

# Returns error and exits the script
die() {
    echo "Dying: $@"
    exit 10
}

# Check if the image with the specified tag exists
function docker_tag_exists() {
    curl --silent -f -lSL https://index.docker.io/v1/repositories/$1/tags/$2 > /dev/null
}

# Check input parameters
if [ -z "$inServer" ]; then
    die "No server is set"
fi

if [ -z "$inPath" ]; then
    die "No dockerComposePath is set"
fi

if [ -z "$inVersion" ]; then
    die "No application version is set"
fi

if docker_tag_exists $registry/$app $inVersion; then
    echo "Image $registry/$app:$inVersion exists"
else
    die "Specified image tag does not exist in registry $registry/$app"
fi

if docker_tag_exists $registry/reverse $inVersion; then
    echo "Image $registry/reverse:$inVersion exists"
else
    die "Specified image tag does not exist in registry $registry/reverse"
fi


backupCompose(){
    echo "$(date --rfc-3339='ns'): ********* Prepare backup and set new version to docker-compose *********"
    oldVersion=`$ssh grep -a "$registry\/$app" $inPath/docker-compose.yml | cut -f3 -d':'`
    echo "The old version is $oldVersion, new one is $inVersion"
    $ssh "mkdir -p $inPath/backup/$inVersion && \
                cp $inPath/docker-compose.yml $inPath/backup/$inVersion && \
                sed -i 's/$oldVersion/$inVersion/g' $inPath/docker-compose.yml
    "
}

containerId=""

getContainerId(){
    containerId="$($ssh docker container ls | grep django_web | tr -s ' '| cut -f1 -d' ')"
}

if [ `$ssh ls -d $inPath  2> /dev/null| wc -l` == 0  ]
 then
    echo "$(date --rfc-3339='ns'): ********* Prepare folder for deployment from scratch *********"
    $ssh "mkdir -p $inPath && \
                   mkdir -p $inPath/db_django"
    scp docker-compose.yml $inServer:/$inPath
    scp manage.py $inServer:/$inPath
    scp -r web_django $inServer:/$inPath
    backupCompose
    echo "$(date --rfc-3339='ns'): ********* Run docker stack django *********"
    $ssh docker stack deploy -c$inPath/docker-compose.yml django
    sleep 30
    echo "$(date --rfc-3339='ns'): ********* Apply migrations to database *********"
    getContainerId
    echo $containerId
    sleep 60
    $ssh docker exec -i $containerId python manage.py makemigrations
    $ssh docker exec -i $containerId python manage.py migrate
    $ssh docker service update --force django_web
    getContainerId
    echo $containerId
    $ssh " echo \"from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@myproject.com', 'password')\" | docker exec -i $containerId python manage.py shell "

else
    backupCompose
    echo "$(date --rfc-3339='ns'): ********* Update django_web to new $inVersion *********"
    if $ssh docker service update --force django_web --image $registry/$app:$inVersion; then
        echo "success"
    else
        echo "$(date --rfc-3339='ns'): ********* Started rollback *********"
        $ssh "cp $inPath/backup/$inVersion/docker-compose.yml $inPath/docker-compose.yml && \
                docker stack deploy -c $inPath/backup/$inVersion/docker-compose.yml django_web
            "
    fi
fi

