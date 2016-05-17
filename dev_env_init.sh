#!/bin/bash

NODE_VERSION=0.4.7
NPM_VERSION=1.0.94

# Save script's current directory
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#cd "${DIR}"

#
# Check if Homebrew is installed
#
which -s brew
if [[ $? != 0 ]] ; then
    # Install Homebrew
    # https://github.com/mxcl/homebrew/wiki/installation
    /usr/bin/ruby -e "$(curl -fsSL https://raw.github.com/gist/323731)"
else
    brew update
fi

#
# Check if Git is installed
#
which -s git || brew install git

#
# Check if Node is installed and at the right version
#
echo "Checking for Node version ${NODE_VERSION}"
node --version | grep ${NODE_VERSION}
if [[ $? != 0 ]] ; then
    # Install Node
    cd `brew --prefix`
    $(brew versions node | grep ${NODE_VERSION} | cut -c 16- -)
    brew install node

    # Reset Homebrew formulae versions
    git reset HEAD `brew --repository` && git checkout -- `brew --repository`
fi

cd /tmp

#
# Check if Node Package Manager is installed and at the right version
#
echo "Checking for NPM version ${NPM_VERION}"
npm --version | grep ${NPM_VERSION}
if [[ $? != 0 ]] ; then
    echo "Downloading npm"
    git clone git://github.com/isaacs/npm.git && cd npm
    git checkout v${NPM_VERSION}
    make install
fi

#
# Ensure NODE_PATH is set
#
grep NODE_PATH ~/.bash_profile > /dev/null || cat "export NODE_PATH=/usr/local/lib/node_modules" >> ~/.bash_profile && . ~/.bash_profile

#
# Install Foreman
#
which -s foreman || sudo gem install foreman
if [[ ! -f ${DIR}/.env ]]; then
    echo "# Uncomment to use local mongodb instance" > ${DIR}/.env
    echo "#NODE_ENV=local" >> ${DIR}/.env
fi

#
# Check if Heroku toolbelt is installed
#
which -s heroku
if [[ $? != 0 ]] ; then
    # Install Heroku toolbelt
    echo "Downloading Heroku toolbelt"
    curl -O http://assets.heroku.com/heroku-toolbelt/heroku-toolbelt.pkg
    open /tmp/heroku-toolbelt.pkg
    read -p "Press return when done with Heroku installation"

    # open https://api.heroku.com/login
    # https://api.heroku.com/signup
else
    heroku update
fi

#
# Heroku setup
#
heroku login
heroku keys | grep 'No keys' && heroku keys:add

cd "${DIR}"
git remote | grep heroku > /dev/null || git remote add heroku git@heroku.com:app-name.git

# Install node packages
npm install
which -s http-console || npm install -g http-console

#
# MongoDB
#
which -s mongo || brew install mongodb
echo "Cloning app-name db to /data/db, you may be asked for your administrator password"
if [[ ! -d /data/db/ ]]; then
    sudo mkdir -p /data/db/
    sudo chown `id -u` /data/db
fi
if [[ ! -d /data/dumps/ ]]; then
    sudo mkdir -p /data/dumps/
    sudo chown `id -u` /data/dumps
fi

# Pull down a copy of the current app-name db
mongodump -h staff.mongohq.com:10084 -u app-name -p password -d db-name -o /data/dumps
mongod &
mongorestore -h localhost:27017 -d app-name /data/dumps/db-name/
ps -ef | grep mongod | awk '{print$2}' | xargs kill {}
echo
echo "The current app-name database has been installed locally. "
echo "You can start up your local mongodb instance by simply typing 'mongod' in terminal."
echo "Connect to mongo using the shell by typing 'mongo app-name' in another terminal."
if [[ ! -f ~/.mongorc.js ]]; then
    # Customize the mongo prompt to show what database you're connected to
    echo "prompt = function () { return db+'> '; }" > ~/.mongorc.js
fi