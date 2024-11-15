#!/bin/bash

# Variables
DB_USER="root"
DB_PASSWORD="root"
DB_NAME="fontys"
EXPORT_DIR="IndividualProject\appbackups\encrypted"
TIMESTAMP=$(date +%F_%H-%M-%S)
ARCHIVE_NAME="data_backup_${TIMESTAMP}.tar.gz"
ENCRYPTED_ARCHIVE_NAME="data_backup_.tar.gz.enc"
REMOTE_USER="user01"
REMOTE_SERVER="ip_mirror_db02"
REMOTE_DIR="/home/riccardo/store"
REMOTE_PRIVATE_KEY="$HOME/.ssh/id_rsa"
ENCRYPTION_PASSWORD="user01"


mkdir -p $EXPORT_DIR
rm -f $EXPORT_DIR/*.csv


tables=$(mysql -u $DB_USER -p$DB_PASSWORD -e "SHOW TABLES IN $DB_NAME;" | tail -n +2)
for table in $tables; do
    mysql -u $DB_USER -p$DB_PASSWORD -e "SELECT * INTO OUTFILE '$EXPORT_DIR/${table}_${TIMESTAMP}.csv' FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' FROM $DB_NAME.$table;"
done

tar -czvf $ARCHIVE_NAME -C $EXPORT_DIR .
openssl enc -aes-256-cbc -salt -in $ARCHIVE_NAME -out $ENCRYPTED_ARCHIVE_NAME -k $ENCRYPTION_PASSWORD -pbkdf2

# Securely copy the encrypted file to the backup server (mirror database)
scp -i $REMOTE_PRIVATE_KEY $ENCRYPTED_ARCHIVE_NAME $REMOTE_USER@$REMOTE_SERVER:$REMOTE_DIR

# Commands to run on the backup server to decrypt and extract data
REMOTE_COMMANDS="
cd $REMOTE_DIR;
openssl enc -d -aes-256-cbc -in $ENCRYPTED_ARCHIVE_NAME -out $ARCHIVE_NAME -k $ENCRYPTION_PASSWORD -pbkdf2;
tar -xzvf $ARCHIVE_NAME -C $REMOTE_DIR;
rm $ENCRYPTED_ARCHIVE_NAME $ARCHIVE_NAME;
"

#SSH
ssh -i $REMOTE_PRIVATE_KEY $REMOTE_USER@$REMOTE_SERVER "$REMOTE_COMMANDS"


python upload_to_azure.py "$ENCRYPTED_ARCHIVE_NAME"
rm $ARCHIVE_NAME $ENCRYPTED_ARCHIVE_NAME
echo "Data migration completed successfully."
