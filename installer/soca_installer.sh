#!/bin/bash

######################################################################################################################
#  Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.                                                #
#                                                                                                                    #
#  Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance    #
#  with the License. A copy of the License is located at                                                             #
#                                                                                                                    #
#      http://www.apache.org/licenses/LICENSE-2.0                                                                    #
#                                                                                                                    #
#  or in the 'license' file accompanying this file. This file is distributed on an 'AS IS' BASIS, WITHOUT WARRANTIES #
#  OR CONDITIONS OF ANY KIND, express or implied. See the License for the specific language governing permissions    #
#  and limitations under the License.                                                                                #
######################################################################################################################


if [[ ! "$BASH_VERSION" ]] ; then
    exec /bin/bash "$0" "$@"
fi

function realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

function run_pip() {
  if [[ "$QUIET_MODE" = "true" ]]; then
    pip3 install --upgrade pip --quiet
    pip3 install -r resources/src/requirements.txt --quiet
  else
    pip3 install --upgrade pip
    pip3 install -r resources/src/requirements.txt
  fi
}

function log_success() { echo -e "${GREEN}${1}${NC}" ;}
function log_warning() { echo -e "${YELLOW}${1}${NC}" ;}
function log_error() { echo -e "${RED}${1}${NC}" ;}

# export SOCA_PYTHON variable if your Python3 is located on a different place
# ex: export SOCA_PYTHON="python3" if this command is added to your $PATH
# ex: export SOCA_PYTHON="/usr/local/bin/python3" to specify the full path of your Python3 environment
# After you export SOCA_PYTHON, re-run the installer.
SOCA_PYTHON=${SOCA_PYTHON:-$(command -v python3)}
# Remove prompt when running virtual environment (not recommended)
SOCA_PYTHON_SKIP_VENV=${SOCA_PYTHON_SKIP_VENV:-"false"}

# Python3 must be available to build python dependencies on Lambda
REQUIRED_PYTHON_VERSION="3.11"

# Download and Install PyENV if needed
#PYENV_URL="https://pyenv.run"
# Change to "true" for more log
QUIET_MODE="false"

# Current path
INSTALLER_DIRECTORY=$(dirname $(realpath "$0"))

# Location of the Python Virtual Environment. It's not recommended to change the value
PYTHON_VENV="$INSTALLER_DIRECTORY/resources/src/envs/venv-py-installer"

# NVM path
NODEJS_BIN="https://gitee.com/gongjing/soca-china/blob/master/nvm-sh/nvm/v0.40.0/install.sh"

# Color
NC="\033[0m"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"


export NVM_DIR="$INSTALLER_DIRECTORY/resources/src/envs/.nvm"

# shellcheck disable=SC2164
cd "$INSTALLER_DIRECTORY"

log_success "======= Checking system pre-requisites ======="

# 检查是否为 root 用户，因为安装软件包需要 root 权限
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root to install packages"
   exit 1
fi
log_success "Verifying Python3 interpreter"
# shellcheck disable=SC2181
if [[ -z "$SOCA_PYTHON" ]]; then
    log_error "Python is not installed. Please download and install it from https://www.python.org/downloads/release/python-3119/"
    exit 1
else
    PYTHON_VERSION=$($SOCA_PYTHON -c "import sys;print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    # Check if current python shell is using the required version
    if [[ "$PYTHON_VERSION" != "$REQUIRED_PYTHON_VERSION" ]]; then
      log_warning "Your version of Python ($PYTHON_VERSION) does not match the supported version ($REQUIRED_PYTHON_VERSION)"
      exit 1
      # If pyenv is installed,
      log_success "List of Python $REQUIRED_PYTHON_VERSION versions installed via your PyEnv"
      PYTHON=$(command -v python3)
      if [[ $? -ne 0 ]]; then
          echo "Unable to find python3. Please download and install it from https://www.python.org/downloads/"
          exit 1
      else
          echo "Found python3: $PYTHON"
      fi
      SOCA_PYTHON=$(which python3)
    fi
    log_success "$SOCA_PYTHON detected, continuing installation ..."
fi

# Check if user is already running on a virtual environment
if [[ -n $VIRTUAL_ENV ]]; then
  log_warning "=====ATTENTION===="
  log_warning "You are currently using an existing Python virtual environment."
  log_warning "To prevent dependencies errors, It's highly recommended to exit your virtual environment first and re-launch the installer"
  log_warning "SOCA will create its own virtual environment and configure all required dependencies"
  log_warning "=================="
  if [[ $SOCA_PYTHON_SKIP_VENV == "false" ]]; then
    read -rp "Do you want to continue with your existing virtual environment? (yes/no) " EXISTINGVIRTENV
    case $EXISTINGVIRTENV in
      yes ) true ;;
      no ) exit 1;;
      * ) log_error "Please answer yes or no."
        exit 1 ;;
    esac
  fi
  sleep 5
else
  # Check if Python Virtual environment exist
  # If not, create the venv and install required python libraries
  if [[ ! -e $PYTHON_VENV/bin/activate ]]; then
      log_success "No Python virtual environment found. Creating one ..."
      rm -rf "$PYTHON_VENV"
      $SOCA_PYTHON -m venv "$PYTHON_VENV"
      # shellcheck disable=SC1090
      . "$PYTHON_VENV/bin/activate"
  else
    # Load Python environment
    log_success "Loading Python Virtual Environment"
    source "$PYTHON_VENV/bin/activate"
  fi
fi
# 检查系统类型
if command -v dnf &> /dev/null; then
    # 如果系统使用 dnf（如 Fedora、CentOS 8+）
    if ! dnf list installed python3-pip &> /dev/null; then
        log_warning "python3-pip not found. Installing..."
        dnf install python3-pip -y
        if [[ $? -ne 0 ]]; then
            log_error "Failed to install python3-pip"
            exit 1
        fi
    fi
elif command -v yum &> /dev/null; then
    # 如果系统使用 yum（如 CentOS 7 或更早版本）
    if ! yum list installed python3-pip &> /dev/null; then
        log_warning "python3-pip not found. Installing..."
        yum install python3-pip -y
        if [[ $? -ne 0 ]]; then
            log_error "Failed to install python3-pip"
            exit 1
        fi
    fi
elif command -v apt-get &> /dev/null; then
    # 如果系统使用 apt-get（如 Ubuntu、Debian）
    if ! dpkg -s python3-pip &> /dev/null; then
        log_warning "python3-pip not found. Installing..."
        apt-get update
        apt-get install python3-pip -y
        if [[ $? -ne 0 ]]; then
            log_error "Failed to install python3-pip"
            exit 1
        fi
    fi
else
    log_error "Unsupported package manager. Please install python3-pip manually."
    exit 1
fi
# Check if aws cli (https://aws.amazon.com/cli/) is installed
PIP3=$(command -v pip3)
if [[ -z "$PIP3" ]]; then
    log_error "pip3 not found even after installation attempt"
    exit 1
fi
log_success "pip3 is available at: $PIP3"

# Verify that latest dependency are available
run_pip

# Install local NodeJS environment and CDK
if [[ ! -d $NVM_DIR ]]; then
  mkdir -p "$NVM_DIR"
  log_success "Local NodeJS environment not detected, creating one ..."
  log_success "Downloading $NODEJS_BIN"
  curl --silent -o- "$NODEJS_BIN" | bash
  log_success "Installing Node & NPM via nvm"
  source "$NVM_DIR/nvm.sh"  # This loads nvm
  # shellcheck disable=SC1090
  source "$NVM_DIR/bash_completion"
  nvm install v18.20.4
  npm install -g aws-cdk@2.151.0
  log_success "Install Node & NPM & CDK successful!"
else
  source "$NVM_DIR/nvm.sh"  # This loads nvm
  source "$NVM_DIR/bash_completion"
fi

command -v aws > /dev/null
# shellcheck disable=SC2181
if [[ $? -ne 0 ]]; then
    log_success "AWSCLI not detected."
    while true; do
    read -rp "Do you want to automatically install aws cli and configure it? You will need to have a valid pair of access/secret key. You can generate them on the AWS Console IAM section (yes/no) " AWSCLIINSTALL
    case $AWSCLIINSTALL in
        yes ) $PIP3 install awscli
          log_success "AWS CLI installed. Running 'aws configure' to configure your AWS CLI environment:"
          aws configure
          ;;
        no ) exit 1;;
        * ) log_error "Please answer yes or no."
          exit 1;;
    esac
  done
fi

# Set default region while respecting existing environment, fallback to Virginia if not defined (Used by install_soca.py)
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-$(grep region <"${HOME}/.aws/config" | head -n 1 | awk '{print $3}')}
if [[ $AWS_DEFAULT_REGION == "" ]]; then
  export AWS_DEFAULT_REGION="us-east-1"
fi

log_success "======= Pre-requisites completed. Launching installer ======="

# Launch actual installer
resources/src/install_soca.py "$@"
