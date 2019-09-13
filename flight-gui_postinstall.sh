#!/bin/bash

cd /appliance/flighthub-gui

sed -i "s@APPLICATION_NAME=ABC@APPLICATION_NAME='$alces_APPLIANCE_NAME'@g;s@^#SECRET_KEY_BASE=.*@SECRET_KEY_BASE=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 25)@g" .env
sed -i 's@^export APPLIANCE_INFORMATION_FILE_PATH=ABC@export APPLIANCE_INFORMATION_FILE_PATH=/appliance/cluster.md@g;s@^#RAILS_SERVE_STATIC_FILES@RAILS_SERVE_STATIC_FILES@g;s@^export SSH_KEYS_FILE_PATH=ABC@export SSH_KEYS_FILE_PATH=/appliance/siteadmin/.ssh/authorized_keys@g;s@export NETWORK_VARIABLES_FILE_PATH=ABC@export NETWORK_VARIABLES_FILE_PATH=/appliance/scripts/vars.sh@g;s@export NETWORK_SETUP_SCRIPT_FILE_PATH=ABC@export NETWORK_SETUP_SCRIPT_FILE_PATH=/appliance/scripts/personality_base.sh@g' .env
alces_SITEADMIN_PASS='alcestest'

echo "Password for DB = ${alces_SITEADMIN_PASS}"

#Setup Postgres

postgresql-setup initdb
sed -i 's/peer$/trust/g;s/ident$/trust/g' /var/lib/pgsql/data/pg_hba.conf
systemctl enable postgresql
systemctl start post

#Ensure pam-devel is installed...

yum -y -e0 install pam-devel

bundle install

## Generate database
RAILS_ENV=production bin/rails db:create
RAILS_ENV=production bin/rails db:schema:load
RAILS_ENV=production bin/rails data:migrate

## Create siteadmin Overware user
echo "User.create(username: 'siteadmin', password: '$alces_SITEADMIN_PASS')" |RAILS_ENV=production rails console

## Enable bolt-ons
echo "bolt_on = BoltOn.find_by(name: 'VPN') ; bolt_on.enabled = true ; bolt_on.save! " |RAILS_ENV=production rails console
echo "bolt_on = BoltOn.find_by(name: 'Console') ; bolt_on.enabled = true ; bolt_on.save! " |RAILS_ENV=production rails console
echo "bolt_on = BoltOn.find_by(name: 'Assets') ; bolt_on.enabled = true ; bolt_on.save! " |RAILS_ENV=production rails console

## Compile assets
rake assets:precompile

## Launch server in background
cat << EOF > /usr/lib/systemd/system/flight-gui.service
[Unit]
Description=Alces Flight GUI Appliance
Requires=network.target postgresql.service
[Service]
Type=simple
User=root
WorkingDirectory=/appliance/flighthub-gui
ExecStart=/usr/bin/bash -lc 'bundle exec bin/rails server -e production --port 80'
TimeoutSec=30
RestartSec=15
Restart=always
[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /usr/lib/systemd/system/flight-terminal.service
[Unit]
Description=Flight terminal service
Requires=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/appliance/flight-terminal-service
ExecStart=/usr/bin/bash -lc 'yarn run start'
TimeoutSec=30
RestartSec=15
Restart=always
[Install]
WantedBy=multi-user.target
EOF

## Firewall service for Overware & Flight Terminal
firewall-cmd --new-service flight-gui --permanent
firewall-cmd --permanent --service=flight-gui --set-description="Flight management web interface" --add-port=25288/tcp --add-port=80/tcp --add-port=443/tcp
firewall-cmd --add-service flight-gui --zone internal --permanent
firewall-cmd --add-service flight-gui --zone external --permanent
firewall-cmd --reload


chmod 644 /usr/lib/systemd/system/flight-gui.service /usr/lib/systemd/system/flight-terminal.service
systemctl daemon-reload

systemctl enable flight-gui.service
systemctl enable flight-terminal.service
systemctl start flight-gui
systemctl start flight-terminal