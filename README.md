# Docker Volume Recovery Script

This script allows you to recover a Docker volume from a MinIO backup. It downloads the volume backup file from a MinIO server, creates a temporary container, and restores the volume from the backup.

## Prerequisites

- Bash
- Docker
- MinIO Client (mc)
- JQ (optional, if using a configuration file)

## Usage

```bash
./recover_volume.sh [options...]

Options:
  --config=CONFIG        Path to JSON configuration file (default: credentials.json)
  --minio-url=URL        URL of the MinIO server
  --access-key=KEY       Access key for MinIO
  --secret-key=KEY       Secret key for MinIO
  --bucket=BUCKET        MinIO bucket name
  --volume=VOLUME        Name of the Docker volume to recover
  --filename=FILENAME    Filename in the MinIO bucket without the .tar.gz extension

Example: ./recover_volume.sh --minio-url=http://minio-server --access-key=access-key --secret-key=secret-key --bucket=bucket-name --volume=volume-name
```

## Options

- `--config=CONFIG`: Path to a JSON configuration file that contains the MinIO connection parameters (optional, default: credentials.json). If this option is provided, the script will read the MinIO URL, access key, and secret key from the specified configuration file.
- `--minio-url=URL`: URL of the MinIO server.
- `--access-key=KEY`: Access key for MinIO.
- `--secret-key=KEY`: Secret key for MinIO.
- `--bucket=BUCKET`: MinIO bucket name that contains the volume backups.
- `--volume=VOLUME`: Name of the Docker volume to recover.
- `--filename=FILENAME`: Filename in the MinIO bucket without the `.tar.gz` extension (optional, default: same as the volume name).

## Examples

Recover a Docker volume using command-line arguments:

```bash
./recover_volume.sh --minio-url=http://minio-server --access-key=access-key --secret-key=secret-key --bucket=bucket-name --volume=volume-name
```

Recover a Docker volume using a configuration file:

```bash
./recover_volume.sh --config=credentials.json --volume=volume-name
```

## Notes

- The script requires root or sudo access to create and delete Docker volumes.
- The MinIO server should be accessible and properly configured with the provided URL, access key, and secret key.
- The MinIO bucket should contain the volume backup files in the `.tar.gz` format.
- If the `--filename` option is not provided, the script will use the volume name as the filename when downloading the backup file from the bucket.

## License

This script is released under the MIT License. See the [LICENSE](LICENSE) file for more details.
