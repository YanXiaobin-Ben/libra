#!/bin/bash
# Copyright (c) The Libra Core Contributors
# SPDX-License-Identifier: Apache-2.0
# This script sets up the environment for the Libra build by installing necessary dependencies.
#
# Usage ./dev_setup.sh <options>
#   v - verbose, print all statements

# Assumptions for nix systems:
# 1 The running user is the user who will execute the builds.
# 2 .profile will be used to configure the shell
# 3 ${HOME}/bin/ is expected to be on the path - hashicorp tools/hadolint/etc.  will be installed there on linux systems.

HADOLINT_VERSION=1.17.4
SCCACHE_VERSION=0.2.13
KUBECTL_VERSION=1.18.6
TERRAFORM_VERSION=0.12.26
HELM_VERSION=3.2.4
VAULT_VERSION=1.5.0

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$SCRIPT_PATH/.."

function usage {
  echo "Usage:"
  echo "Installs or updates necessary dev tools for libra/libra."
  echo "-b batch mode, no user interactions and miminal output"
  echo "-o intall operations tooling as well: helm, terraform, hadolint, yamllint, vault, docker, kubectl, python3"
  echo "-v verbose mode"
  echo "should be called from the root folder of the libra project"
}

function install_rustup {
  BATCH_MODE=$1
  # Install Rust
  [[ $BATCH_MODE == "false" ]] && echo "Installing Rust......"
  if rustup --version &>/dev/null; then
	   [[ $BATCH_MODE == "false" ]] && echo "Rust is already installed"
  else
	  curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable
	  CARGO_ENV="$HOME/.cargo/env"
	  source "$CARGO_ENV"
  fi
}

function install_hadolint {
  if ! command -v hadolint &> /dev/null; then
    export HADOLINT=${HOME}/bin/hadolint
    curl -sL -o ${HADOLINT} "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-$(uname -s)-$(uname -m)" && chmod 700 ${HADOLINT}
  fi
  hadolint -v
}

function install_vault {
  if [[ `vault --version` != "Vault v${VAULT_VERSION}" ]]; then
    MACHINE=`uname -m`;
    if [[ $MACHINE == "x86_64" ]]; then
      MACHINE="amd64"
    fi
    TMPFILE=`mktemp`
    curl -sL -o ${TMPFILE} "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_$(uname -s | tr '[:upper:]' '[:lower:]')_${MACHINE}.zip"
    unzip -qq -d ${HOME}/bin/ ${TMPFILE}
    rm ${TMPFILE}
    chmod +x ${HOME}/bin/vault
  fi
  vault --version
}

function install_helm {
  if ! command -v helm &> /dev/null; then
    if [[ `uname -s` == "Darwin" ]]; then
      install_pkg helm brew
    else
      MACHINE=`uname -m`;
      if [[ $MACHINE == "x86_64" ]]; then
        MACHINE="amd64"
      fi
      TMPFILE=`mktemp`
      rm $TMPFILE
      mkdir -p $TMPFILE/
      curl -sL -o ${TMPFILE}/out.tar.gz "https://get.helm.sh/helm-v${HELM_VERSION}-$(uname -s | tr '[:upper:]' '[:lower:]')-${MACHINE}.tar.gz"
      tar -zxvf ${TMPFILE}/out.tar.gz -C ${TMPFILE}/
      cp ${TMPFILE}/$(uname -s | tr '[:upper:]' '[:lower:]')-${MACHINE}/helm ${HOME}/bin/helm
      rm -rf ${TMPFILE}
      chmod +x ${HOME}/bin/helm
    fi
  fi
}

function install_terraform {
  if [[ `terraform --version | head -1` != "Terraform v${TERRAFORM_VERSION}" ]]; then
    if [[ `uname -s` == "Darwin" ]]; then
      install_pkg tfenv brew
      tfenv install ${TERRAFORM_VERSION}
      tfenv use ${TERRAFORM_VERSION}
    else
      MACHINE=`uname -m`;
      if [[ $MACHINE == "x86_64" ]]; then
        MACHINE="amd64"
      fi
      TMPFILE=`mktemp`
      curl -sL -o ${TMPFILE} "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_$(uname -s | tr '[:upper:]' '[:lower:]')_${MACHINE}.zip"
      unzip -qq -d ${HOME}/bin/ ${TMPFILE}
      rm ${TMPFILE}
      chmod +x ${HOME}/bin/terraform
      terraform --version
    fi
  fi
}

function install_kubectl {
  if [[ `kubectl version client --short=true | head -1` != "Client Version: v${KUBECTL_VERSION}" ]]; then
    if [[ `uname -s` == "Darwin" ]]; then
      install_pkg kubectl brew
    else
      MACHINE=`uname -m`;
      if [[ $MACHINE == "x86_64" ]]; then
        MACHINE="amd64"
      fi
      curl -sL -o ${HOME}/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/$(uname -s | tr '[:upper:]' '[:lower:]')/${MACHINE}/kubectl"
      chmod +x ${HOME}/bin/kubectl
    fi
  fi
  kubectl version client --short=true | head -1
}

function install_awscli {
  if ! command -v aws &> /dev/null; then
    if [[ `uname -s` == "Darwin" ]]; then
      install_pkg awscli brew
    else
      MACHINE=`uname -m`;
      TMPFILE=`mktemp`
      rm $TMPFILE
      mkdir -p $TMPFILE/work/
      curl -sL -o $TMPFILE/aws.zip  "https://awscli.amazonaws.com/awscli-exe-$(uname -s | tr '[:upper:]' '[:lower:]')-${MACHINE}.zip"
      unzip -qq -d ${TMPFILE}/work/ $TMPFILE/aws.zip
      mkdir -p ${HOME}/.local/
      ${TMPFILE}/work/aws/install -i ${HOME}/.local/aws-cli -b ${HOME}/bin
      rm -rf ${TMPFILE}
    fi
  fi
  aws --version
}

function install_pkg {
  package=$1
  package_manager=$2
  pre_command=""
  if [ `whoami` != 'root' ]; then
    pre_command="sudo "
  fi
  if which $package &>/dev/null; then
    echo "$package is already installed"
  else
    echo "Installing $package."
    if [[ "$PACKAGE_MANAGER" == "yum" ]]; then
      $PRE_COMMAND yum install $package -y
    elif [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
      $PRE_COMMAND apt-get install $package -y
    elif [[ "$PACKAGE_MANAGER" == "pacman" ]]; then
      $PRE_COMMAND pacman -Syu $package --noconfirm
    elif [[ "$PACKAGE_MANAGER" == "brew" ]]; then
      brew install $package
    fi
  fi
}

function install_toolchain {
  version=$1
  if [[ "rustup show | grep $version | wc -l" == "0" ]]; then
    rustup install $version
  else
    echo "$version rust toolchain already installed"
  fi
}

function welcome_message {
cat <<EOF
Welcome to Libra!

This script will download and install the necessary dependencies needed to
build, test and inspect Libra Core. This includes:
  * Rust (and the necessary components, e.g. rust-fmt, clippy)
  * CMake
  * Clang
  * grcov
  * lcov
  * pkg-config
  * libssl-dev
  * sccache
  * if linux, gcc-powerpc-linux-gnu
If operations tools are selected, then
  * yamllint
  * python3
  * docker
  * vault
  * terraform
  * kubectl
  * helm

If you'd prefer to install these dependencies yourself, please exit this script
now with Ctrl-C.
EOF
}

BATCH_MODE=false;
VERBOSE=false;
OPERATIONS=false;

#parse args
while getopts "bvho" arg; do
  case $arg in
    b)
      BATCH_MODE="true"
      ;;
   o)
      OPERATIONS="true"
      ;;
    v)
      VERBOSE=true
      ;;
    h)
      usage;
      exit 0;
      ;;
  esac
done

if [[ $VERBOSE == "true" ]]; then
	set -x
fi

if [ ! -f rust-toolchain ]; then
	echo "Unknown location. Please run this from the libra repository. Abort."
	exit 1
fi

PACKAGE_MANAGER=
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	if which yum &>/dev/null; then
		PACKAGE_MANAGER="yum"
	elif which apt-get &>/dev/null; then
		PACKAGE_MANAGER="apt-get"
	elif which pacman &>/dev/null; then
		PACKAGE_MANAGER="pacman"
	else
		echo "Unable to find supported package manager (yum, apt-get, or pacman). Abort"
		exit 1
	fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
	if which brew &>/dev/null; then
		PACKAGE_MANAGER="brew"
	else
		echo "Missing package manager Homebrew (https://brew.sh/). Abort"
		exit 1
	fi
else
	echo "Unknown OS. Abort."
	exit 1
fi

if [[ $BATCH_MODE == "false" ]]; then
    welcome_message
    printf "Proceed with installing necessary dependencies? (y/N) > "
    read -e input
    if [[ "$input" != "y"* ]]; then
	    echo "Exiting..."
	    exit 0
    fi
fi

PRE_COMMAND=""
if [ `whoami` != 'root' ]; then
  PRE_COMMAND="sudo "
fi

mkdir -p ${HOME}/bin

if [[ $"$PACKAGE_MANAGER" == "apt-get" ]]; then
	[[ $BATCH_MODE == "false" ]] && echo "Updating apt-get......"
	$PRE_COMMAND apt-get update
fi


install_pkg cmake $PACKAGE_MANAGER
install_pkg clang $PACKAGE_MANAGER
install_pkg llvm $PACKAGE_MANAGER
install_pkg curl $PACKAGE_MANAGER
install_pkg gcc-powerpc-linux-gnu $PACKAGE_MANAGER

#need to change....
install_pkg libssl-dev $PACKAGE_MANAGER  # openssl-devel in centos
install_pkg pkg-config $PACKAGE_MANAGER  # pkgconfig in centos

install_rustup $BATCH_MODE
install_toolchain `cat ./cargo-toolchain`
install_toolchain `cat ./rust-toolchain`

# Add all the components that we need
rustup component add rustfmt
rustup component add clippy

if ! command -v grcov &> /dev/null; then
  cargo install grcov
fi

if [[ `sccache --version` != "sccache ${SCCACHE_VERSION}" ]]; then
  cargo install sccache --version=${SCCACHE_VERSION}
fi

if [[ $OPERATIONS == "true" ]]; then
  install_pkg yamllint $PACKAGE_MANAGER
  install_pkg python3 $PACKAGE_MANAGER
  install_hadolint
  install_vault
  install_helm
  install_terraform
  install_kubectl
  install_awscli
fi

[[ BATCH_MODE == "false" ]] && cargo clean

[[ BATCH_MODE == "false" ]] && cat <<EOF

Finished installing all dependencies.

You should now be able to build the project by running:
	source $HOME/.cargo/env
	cargo build
EOF



exit 0