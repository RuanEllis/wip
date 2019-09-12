#!/bin/bash
VERSION=$1

mkdir -p /appliance

## RVM installation
if ! gpg2 --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB ; then
    curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
    curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import -
fi

curl -sSL https://get.rvm.io | bash -s stable --ruby
source /etc/profile.d/rvm.sh
rvm install ruby # Install standard ruby otherwise 2.5.0 install fails with "executable host ruby is required. use --with-baseruby option."
rvm install "ruby-2.5.0"

rvm --default use 2.5.0

## Install postgresql 9.6
yum -y install postgresql-server postgresql-devel

## Install node.js 8.12.0
curl -sL https://rpm.nodesource.com/setup_8.x | bash -
yum -y install nodejs-8.12.0

## Install yarn
curl -sL https://dl.yarnpkg.com/rpm/yarn.repo -o /etc/yum.repos.d/yarn.repo
yum -y install yarn

## Flight Terminal Service setup
git clone https://github.com/alces-software/flight-terminal-service /appliance/flight-terminal-service
cat << EOF > /appliance/flight-terminal-service/.env
INTERFACE=127.0.0.1
CMD_EXE="/bin/sudo"
CMD_ARGS_FILE="cmd.args.json"
INTEGRATION=no-auth-localhost
EOF

cat << EOF > /appliance/flight-terminal-service/cmd.args.json
{
  "args": [
    "-u", "root",
    "TERM=linux",
    "/opt/flight/bin/flight", "shell"
  ]
}
EOF

cd /appliance/flight-terminal-service
yarn

## Flighthub-GUI setup
yum -y -e0 install pam-devel
cd /appliance/
git clone https://github.com/alces-software/flighthub-gui.git
cd flighthub-gui
if [ ! -z $VERSION ] ; then
    git checkout $VERSION
fi
cp .env.example .env
touch /appliance/cluster.md

