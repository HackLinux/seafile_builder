#!/usr/bin/env bash

# Copyright (C) 2014 Paul Steinlechner <paul.steinlechner[AT]pylonlabs.at>
# This software is distributed under the terms of the GNU GPL version 3.

name="SFBuilder"
version=0.0.0
author="Paul Steinlechner"
license="GPLv3"
make_stack=('libsearpc' 'ccnet' 'seafile' 'seafile-client')
make_amount=${#make_stack[@]}

function check_priveleges(){
if [[ $EUID -ne 0 ]]; then
    sudo echo &>/dev/null
    if [ $? != 0 ]
    then
        issue_exit "while obtaining root privileges. This script must be run as root"
    else
        printf "\v\n\t\e[32m%10s" "==> root privileges are set"
    fi
fi
}

function prepare(){

printf "\n\e[39m\n %s\n %s\n %s\n %s\n %s" "SFBuilder [GIT].Seafile Build Script for GIT Repository" "Name: $name" "Version: $version" "Author: $author" "License: $license"

printf "\v\n\e[33m %s" "==> Preparing build environment. "
check_priveleges
install_packages

tmpdir="/tmp/seafile_git_latest_build"

if [ -d $tmpdir ]
then
    rm -rf $tmpdir/*
    if [ $? != 0 ]
    then
        issue_exit "cleaning up"
    else
        printf "\v\n\t\e[31m%10s" "==> $tmpdir already existing"
        printf "\v\n\t\e[32m%10s" "==> Cleaned up $tmpdir/*"
    fi
else
    mkdir -p $tmpdir
    printf "\v\n\t\e[32m%10s" "==> created"
fi
# changing working directory
cd $tmpdir
}

function install_packages(){
os=$(lsb_release  -a | grep -i Distributor | awk '{ print $3}')
shopt -s nocasematch
case $os in 
    openSUSE) printf "\v\n\t\e[33m%s" "==> You are using opensuse"
        package_stack="libjansson-devel libuuid-devel libevent-devel vala fuse-devel"
        package_manager="zypper --non-interactive install";;
    Fedora) printf "\v\n\t\e[33m%s" "==> You are using Fedora"
        package_stack="vala vala-compat wget gcc libevent-devel openssl-devel gtk2-devel libuuid-devel sqlite-devel jansson-devel intltool cmake qt-devel fuse-devel"
        package_manager="yum install -y";;
    *) echo "Sorry $os is not supported"
        printf "\v\n\t\e[31m%10s" "==> Your OS is not supported: $os"
        issue_exit "installing needed devel packages $package_stack"
esac

sudo $package_manager $package_stack &>/dev/null
        if [ $? != 0 ]
        then
            issue_exit "installing needed devel packages $package_stack"
        else
            printf "\v\n\t\t\e[32m%10s" "==> all needed packages are installed"
        fi
}

function get_git_repos(){

printf "\n\v\e[33m %s" "==> Starting to clone repositories from git"
printf "\n\n\e[32m %15s %20s %20s" Name Task Progress 

dl_counter=1

git_repo='haiwen'
for dl in "${make_stack[@]}"
do
    printf "\n\e[39m %15s %20s %20s" "$dl" "cloning" "$dl_counter / $make_amount"
    git clone https://github.com/$git_repo/$dl &>/dev/null 
    if [ $? != 0 ]
    then
        issue_exit "Cloning Git Repos"
    fi
    dl_counter=$(($dl_counter + 1))
done
printf "\n\n\t\e[32m%s\n" "==> Downloading finished"
}

function build(){
export PREFIX=/usr
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export PATH="$PREFIX/bin:$PATH"


build_counter=1

printf "\n\v\e[33m %s\n" "==> Starting to build" 
printf "\n\e[32m %15s %20s %20s" Name Task Progress 

for make_task in "${make_stack[@]}"
do
    cd $make_task
    if [[ "$make_task" != "seafile-client" ]]
    then
        printf "\n\e[39m %15s %20s %20s" "$make_task" "autogen.sh" "$build_counter / $make_amount"
        ./autogen.sh &>/dev/null
        if [ $? != 0 ]
        then
            issue_exit "autogen.sh $make_task"
        fi
        printf "\n\e[39m %15s %20s %20s" "$make_task" "configure.sh" "$build_counter / $make_amount"
        ./configure --prefix=$PREFIX &>/dev/null
        if [ $? != 0 ]
        then
            issue_exit "configure $make_task"
        fi
        
    else
        printf "\n\e[39m %15s %20s %20s" "$make_task" "cmake" "$build_counter / $make_amount"
        cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX . &>/dev/null
        if [ $? != 0 ]
        then
            issue_exit "cmake $make_task"
        fi
    fi

    printf "\n\e[39m %15s %20s %20s" "$make_task" "make" "$build_counter / $make_amount"
    make &>/dev/null
        if [ $? != 0 ]
        then
            issue_exit "make $make_task"
        fi

    printf "\n\e[39m %15s %20s %20s" "$make_task" "make install" "$build_counter / $make_amount"
    sudo make install 1>/dev/null
        if [ $? != 0 ]
        then
            issue_exit "make install $make_task"
        fi

    cd ..
    build_counter=$(($build_counter + 1))
done
printf "\n\n\t\e[32m%s\n\e[39m" "==> Building and installing finished"
}

function issue_exit(){
    printf "\v\n\t\e[91m%s\v\n\e[39m" "==> Some errors occured while $1. Exiting"
    exit 1
}

prepare
get_git_repos
build
