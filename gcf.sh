#!/bin/sh
#
# Git Config Fixer
#
# Creates a config file that will save your GitHub Personal Access Token via
# libsecret and set some other settings that align with daily use for a lower
# division computer science course.
#

backup_file ()
{
  DATE=`date +"%Y%m%d-%S"`
  FILENAME=${1}
  NEWFILENAME=${FILENAME}-${DATE}.og
  echo "Copying ${FILENAME} to ${NEWFILENAME}"
  cp "$FILENAME" "${NEWFILENAME}"
}

lab_computer_check () {
    export GCF_IS_LAB_COMPUTER="NO"
    PROMPT="Is this a lab computer? [y/n] "
    RESPONSE="${2:-"Thank you."}"
    # LOOPCNTRL=true
    # read -p "${PROMPT}" RETVAL
    # echo "You entered \"${RETVAL}\""
    while true; do
        read -p "${PROMPT}" YN
        # echo "You entered \"${RETVAL}\""
        # read -p "Is this correct? [y/n] " YN
        case $YN in
            [Yy]* ) echo "${RESPONSE}"; break;;
            [Nn]* ) unset YN; break;;
            * ) echo "Please answer y or n.";;
        esac
    done
    YN=`echo ${YN} | tr '[:upper:]' '[:lower:]'`
    if [ ${YN}"x" = "yx" ]; then
        export GCF_IS_LAB_COMPUTER="YES"
    fi
}

make_check () {
    export GCF_CAN_MAKE="NO"
    if command -v make > /dev/null 2>&1; then
        # echo "The make command could not be found"
        echo "✅ has make"
        export GCF_CAN_MAKE="YES"
    else
        echo "🚫 missing make"
    fi
}

gcc_check () {
    export GCF_CAN_GCC="NO"
    if command -v gcc > /dev/null 2>&1; then
        # echo "The gcc command could not be found"
        echo "✅ has gcc"
        export GCF_CAN_GCC="YES"
    else
        echo "🚫 missing gcc"
    fi
}

sudo_check () {
    export GCF_CAN_SUDO="NO"
    if command -v sudo > /dev/null 2>&1; then
        # echo "The gcc command could not be found"
        echo "✅ has sudo"
        export GCF_CAN_GCC="YES"
    else
        echo "🚫 missing sudo"
        return
    fi

    echo "We are going to check to see if you can run commands as root."
    echo "The root user is the administrator and sometimes you may not"
    echo "have access to programs like sudo and su which allow you to run"
    echo "commands as root."
    echo "If you are prompted for a password, type in the password"
    echo "you used to login to this computer. Remember, it won't"
    echo "print out what you type as a security precaution."
    sudo -l
    if [ $? -eq 0 ]; then
        echo
        echo "***********************"
        echo "* YOU HAVE THE POWER! *"
        echo "***********************"
        echo "You can run commands as root. Don't abuse this power."
        export GCF_CAN_SUDO="YES"
    else
        echo
        echo "Sorry, Charlie. You can't run commands as root."
    fi
}

git_libsecret_install () {
    LIBSECRETGIT="/usr/share/doc/git/contrib/credential/libsecret"
    PREREQ="git make gcc libglib2.0-dev"
    HAS_PREREQ="YES"

    echo "Checking for prerequisite packages before building libsecret…"
    for P in ${PREREQ}; do
        dpkg-query -W -f='${Package} ${Status} ${Version}\n' ${P} > /dev/null
        if [ $? -ne 0 ]; then
            HAS_PREREQ="NO"
            break
        fi
    done
    if [ ${HAS_PREREQ}"x" = "NOx" ]; then
        echo "You're missing one or more critical packages, so this program can't"
        echo "continue. Most likely, you are missing all the build tools."
        echo "To fix this problem first install the build tools and then rerun"
        echo "this script."
        echo "Try running:"
        echo "wget -q https://raw.githubusercontent.com/mshafae/tusk/main/quickinstall.sh -O- | sh"
        echo "This will install all the software you need for writing C++ programs."
        echo "Exiting…git is not configured."
        exit 1
    else
        echo "If you are prompted for a password, type in the password"
        echo "you used to login to this computer. Remember, it won't"
        echo "print out what you type as a security precaution."
        PACKAGES="libsecret-1-0 libsecret-1-dev seahorse"
        MISSING_PACKAGES="NO"
        for P in ${PACKAGES}; do
            dpkg-query -W -f='${Package} ${Status} ${Version}\n' ${P} > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                MISSING_PACKAGES="YES"
                break
            fi
        done
        if [ ${MISSING_PACKAGES}"x" = "YESx" ]; then
            sudo apt-get update
            echo "Updated your packages, let's install some packages…"    
            sudo apt-get install -y ${PACKAGES}
            if [ $? -ne 0 ]; then
                echo "There was a problem installing the needed software."
                echo "If you see a message that says:"
                echo "Could not get lock /var/lib/dpkg/lock-frontend. It is held by process…"
                echo "Then restart your computer and try running this program again."
                echo "If the problem doesn't resolve itself after restarting, ask your instructor for help."
                exit 1
            fi
        fi
        echo "Great, the packages were installed. Let's build libsecret…"
        sudo make -C ${LIBSECRETGIT}
        if [ $? -ne 0 ]; then
            echo "There was a problem building git's libsecret plugin. Exiting. Please report this to mshafae@fullerton.edu and talk to your instructor"
            exit 1
        fi
        echo "Excellent, we've got all the parts ready to go."
        git config --global credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret
    fi
    echo "Success installing libsecret!"
}

prompt_confirm_repeat () {
    # The prompt is $1 and the response after the response is accepted is
    # $2 with a default value of "Thank you."
    OUTER=true
    RESPONSE="${2:-"Thank you."}"
    while $OUTER; do
        read -p "${1}" RETVAL
        echo "You entered \"${RETVAL}\""
        while true; do
            read -p "Is this correct? [y/n] " YN
            case $YN in
                [Yy]* ) echo "${RESPONSE}"; OUTER=false; break;;
                [Nn]* ) unset YN; break;;
                * ) echo "Please answer y or n.";;
            esac
        done
    done
}

mkgitconfig () {
    GITCONFIG=${1:-"${HOME}/.gitconfig"}
    NAME="${2}"
    EMAIL="${3}"
    NOW=`date +"%Y%m%d-%S"`
    cat > ${GITCONFIG} <<EOF
# Generated with gcf.sh on ${NOW}
[user]
    name = ${NAME}
    email = ${EMAIL}
[core]
    pager = less
    #editor = nano
    editor = code --wait
[pull]
    rebase = false
[push]
    default = matching
[init]
    defaultBranch = main
[help]
    autocorrect = 20
[color]
    ui = true
EOF
}

######
# Main
######

lab_computer_check

if [ ${GCF_IS_LAB_COMPUTER}"x" = "YESx" ]; then
    echo "This script can only configure your git utility with your name and"
    echo "email address. It cannot cache (save) your PAT to your account."
    echo "When you have your own laptop or personal computer that is running"
    echo "Linux, you can re-run this program to configure git and cache (save)"
    echo "your PAT."
    # echo "This script can only be used on your personal computer like a laptop"
    # echo "or your home computer. This script cannot be used on school lab"
    # echo "computer. You will need to configure git manually using the commands:"
    # echo "git config --global user.name \"Tuffy Titan\""
    # echo "git config --global user.email \"tuffy@csu.fullerton.edu\""
    # echo "Replace \"Tuffy Titan\" with your name."
    # echo "Replace \"tuffy@csu.fullerton.edu\" with your CSUF email address."
    # exit 0
fi

GITCONFIG=${1:-"${HOME}/.gitconfig"}
echo "We are going to edit the file ${GITCONFIG} to make git work better for you."
echo "Ready, set, go!"
prompt_confirm_repeat "What is your full name? Please include your first and last name. " "Great, here's another question…"
NAME=${RETVAL}

prompt_confirm_repeat "What's your CSUF email address? " "Excellent! Almost done…"
EMAIL=${RETVAL}

if [ -e ${GITCONFIG} ]; then
    echo "The file ${GITCONFIG} exists, so we'll make a backup just in case."
    backup_file ${GITCONFIG}
fi

echo "Let's write out a new git configuration."
mkgitconfig "${GITCONFIG}" "${NAME}" "${EMAIL}"

if [ ${GCF_IS_LAB_COMPUTER}"x" = "NOx" ]; then

    echo "Let's see if we can cache your PAT…"
    gcc_check
    make_check
    sudo_check

    if [ ${GCF_CAN_GCC}"x" = "NOx" ] && [ ${GCF_CAN_MAKE}"x" = "NOx" ]; then
        echo "Could not find a compiler or Make. We can't cache your PAT."
        echo "Your git configuration was created and you can use git to"
        echo "push and pull changes from your remote repository (GitHub)."
        echo "You will have to copy and paste your PAT for now."
        echo "If this is your personal computer (not a school lab computer)"
        echo "and you encounter this message then double check to make sure"
        echo "you have installed all the tools needed for your development"
        echo "environment. Don't be shy and ask an instructor for help."
        echo "Run the command"
        echo "wget -q https://raw.githubusercontent.com/mshafae/tusk/main/quickinstall.sh -O- | sh"
        echo "to install the CPSC 120 development environment."
        echo "Then re-run this command to set up PAT caching (saving)."
        exit 1
    fi

    if [ ${GCF_CAN_SUDO}"x" = "YESx" ]; then
        echo
        echo "We're about to install some software and compile a few things."
        echo "This may take a minute."
        echo
        git_libsecret_install
    else
        echo "Since you can't run commands as root, we can't install the"
        echo "software which will save your GitHub PAT. This is a bummer."
        echo "You still have a correctly configured git client, you will"
        echo "just have to copy and paste your PAT."
        echo "Try to commit some changes to see what happens."
        exit 1
    fi

    echo "You're all set! Try using git to push or clone and see if your credentials are saved."
    echo "If you need to add or remove your GitHub password use the program named 'Passwords and Keys' and click 'Login', look for https://@github.com. Right click on it and you can edit the your saved GitHub password."
else
    echo "You're all set! Try to commit some changes to see what happens."
fi

