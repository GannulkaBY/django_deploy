#!/bin/bash
# Usage sample: ./rollback.sh chulets@192.168.100.19 /opt/soft/django 30
set -e


inServer=$1
inPath=$2
inVersion=$3
ssh="ssh $inServer"
registry="gannagp"
app="django"

# Returns error and exits the script
die() {
    echo "Dying: $@"
    exit 10
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

echo "$(date --rfc-3339='ns'): ********* Started rollback *********"
        $ssh "cp $inPath/backup/$inVersion/docker-compose.yml $inPath/docker-compose.yml"
        oldVersion=`$ssh grep -a "$registry\/$app" $inPath/docker-compose.yml | cut -f3 -d':'`
        echo "Run rollback to the old version $oldVersion"
        $ssh docker service update --force django_web --image $registry/$app:$oldVersion