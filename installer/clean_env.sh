#!/bin/bash

INSTALLER_DIRECTORY=$(dirname $(realpath "$0"))
echo "Start cleaning the environment......"
rm -rf "$INSTALLER_DIRECTORY/resources/src/envs/.nvm"
rm -rf "$HOME/.pyenv"
echo "Successfully cleaned up the environment! please re execute the script soca_installer.sh"