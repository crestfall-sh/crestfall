#!/bin/bash
set -x

# 1. updates modules
# 2. updates symlinks of package.json, package-lock.json, .env
# 3. updates node_modules in /auth, /studio

npm outdated
npm update

# core
rm ./core/.env
ln ./.env ./core/.env

# auth
rm ./auth/package.json
rm ./auth/package-lock.json
rm ./auth/.env
rm -rf ./auth/node_modules/
ln ./package.json ./auth/package.json
ln ./package-lock.json ./auth/package-lock.json
ln ./.env ./auth/.env
cp -R ./node_modules/ ./auth/

# studio
rm ./studio/package.json
rm ./studio/package-lock.json
rm ./studio/.env
rm -rf ./studio/node_modules/
ln ./package.json ./studio/package.json
ln ./package-lock.json ./studio/package-lock.json
ln ./.env ./studio/.env
cp -R ./node_modules/ ./auth/

rm -rf ./node_modules/