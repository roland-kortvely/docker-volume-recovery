#!/bin/bash

# Function to display help and usage information
display_help() {
    echo "Usage: $0 [options...] (--minio-url=URL --access-key=KEY --secret-key=KEY --bucket=BUCKET --volume=VOLUME [--filename=FILENAME] | --config=CONFIG --volume=VOLUME [--filename=FILENAME])"
    echo
    echo "Options:"
    echo "  --config=CONFIG       Path to JSON configuration file (default: credentials.json)"
    echo "  --minio-url=URL        URL of the MinIO server"
    echo "  --access-key=KEY       Access key for MinIO"
    echo "  --secret-key=KEY       Secret key for MinIO"
    echo "  --bucket=BUCKET        MinIO bucket name"
    echo "  --volume=VOLUME        Name of the Docker volume to recover"
    echo "  --filename=FILENAME    Filename in the MinIO bucket without the .tar.gz extension"
    echo
    echo "Example: $0 --minio-url=http://minio-server --access-key=access-key --secret-key=secret-key --bucket=bucket-name --volume=volume-name"
}

# Function to validate root user
validate_root_user() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit
    fi
}

# Function to validate if mc is installed
validate_mc_installation() {
    if ! command -v mc &> /dev/null; then
        echo "mc (MinIO Client) could not be found. Please install it."
        echo
        echo "Install Minio Client:"
        echo "wget https://dl.min.io/client/mc/release/linux-amd64/mc"
        echo "chmod +x mc"
        echo "sudo mv mc /usr/local/bin/mc"
        exit
    fi
}

# Function to setup minio client alias
setup_mc_alias() {
    echo "Setting up MinIO Client alias..."
    mc alias set myminio $MINIO_URL $ACCESS_KEY $SECRET_KEY --api S3v4
}

# Function to validate Minio connection
validate_minio_connection() {
    echo "Validating connection to MinIO server..."
    if ! mc ls myminio &>/dev/null; then
        echo "Failed to connect to MinIO server. Please check your MinIO parameters."
        exit 1
    fi
}

# Function to check if volume exists
volume_exists() {
    local volume_name=$1

    if docker volume inspect $volume_name >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to delete volume
delete_volume() {
    local volume_name=$1

    echo "Volume $volume_name already exists."
    read -p "Do you want to delete the existing volume? (y/n): " confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo "Deleting volume $volume_name..."
        if ! docker volume rm $volume_name >/dev/null 2>&1; then
            echo "Failed to delete volume $volume_name. Please make sure it is not attached to any containers."
            exit 1
        fi
        echo "Volume $volume_name deleted."
    else
        echo "Skipping volume deletion."
        exit 0
    fi
}

# Function to check if volume exists and create it if not
create_volume_if_not_exists() {
    local volume_name=$1

    if volume_exists $volume_name; then
        delete_volume $volume_name
    fi

    echo "Creating volume $volume_name..."
    if ! docker volume create $volume_name >/dev/null; then
        echo "Failed to create volume $volume_name."
        exit 1
    fi
    echo "Volume $volume_name created."
}

recover_volume() {
    # Download the volume backup file from MinIO
    rm -f $FILENAME.tar.gz
    echo "Downloading volume backup from MinIO..."
    mc cp myminio/$BUCKET/$FILENAME.tar.gz $FILENAME.tar.gz

    # Create a container and restore the volume from the backup
    echo "Creating a temporary container to restore the volume..."
    docker run --rm -v $VOLUME:/data -v $(pwd):/backup busybox sh -c "tar -xzf /backup/$FILENAME.tar.gz -C /data"

    # Remove the backup file
    rm -f $FILENAME.tar.gz
}

# Parse arguments
for i in "$@"
do
case $i in
    --minio-url=*)
    MINIO_URL="${i#*=}"
    shift # past argument=value
    ;;
    --access-key=*)
    ACCESS_KEY="${i#*=}"
    shift # past argument=value
    ;;
    --secret-key=*)
    SECRET_KEY="${i#*=}"
    shift # past argument=value
    ;;
    --bucket=*)
    BUCKET="${i#*=}"
    shift # past argument=value
    ;;
    --volume=*)
    VOLUME="${i#*=}"
    shift # past argument=value
    ;;
    --filename=*)
    FILENAME="${i#*=}"
    shift # past argument=value
    ;;
    -h|--help)
    display_help
    shift # past argument with no value
    ;;
    *)
    # unknown option
    display_help
    ;;
esac
done

# If a configuration file is not specified, set it to the default
if [ -z "$MINIO_URL" ] || [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
    if [ -z "$CONFIG" ]; then
        CONFIG="credentials.json"
    fi
fi

if [ -n "$CONFIG" ]; then
    validate_jq_installation
    if [ ! -f "$CONFIG" ]; then
        echo "Configuration file $CONFIG not found."
        exit 1
    fi

    MINIO_URL=$(jq -r '.url' $CONFIG)
    ACCESS_KEY=$(jq -r '.accessKey' $CONFIG)
    SECRET_KEY=$(jq -r '.secretKey' $CONFIG)
fi

if [ -z "$MINIO_URL" ] || [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ] || [ -z "$BUCKET" ]; then
    echo "MinIO parameters and bucket name are required."
    display_help
    exit 1
fi

if [ -z "$VOLUME" ] ; then
    echo "Volume name is required."
    display_help
    exit 1
fi

# Set the filename from the bucket
if [ -z "$FILENAME" ]; then
    FILENAME=$VOLUME
fi

#validate_root_user
validate_mc_installation

# Check if the volume exists and create it if not
create_volume_if_not_exists $VOLUME

setup_mc_alias
validate_minio_connection

recover_volume
