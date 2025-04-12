#!/bin/sh
#
# Copyright (c) 2019-2024 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

# Create Home directory
if [ ! -d "${HOME}" ]
then
  mkdir -p "${HOME}"
fi

#############################################################################
# Grant access to projects volume in case of non root user with sudo rights
#############################################################################
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && sudo -n true > /dev/null 2>&1; then
    sudo chown "${USER_ID}:${GROUP_ID}" /projects
fi

if [ -f "${HOME}"/.venv/bin/activate ]; then
  source "${HOME}"/.venv/bin/activate
fi

# Configure Podman builds to use vfs or fuse-overlayfs
if [ ! -d "${HOME}/.config/containers" ]; then
  mkdir -p ${HOME}/.config/containers
  if [ -c "/dev/fuse" ] && [ -f "/usr/bin/fuse-overlayfs" ]; then
    (echo '[storage]';echo 'driver = "overlay"';echo '[storage.options.overlay]';echo 'mount_program = "/usr/bin/fuse-overlayfs"') > ${HOME}/.config/containers/storage.conf
  else
    (echo '[storage]';echo 'driver = "vfs"') > "${HOME}"/.config/containers/storage.conf
  fi
fi

# Create User ID
if ! whoami &> /dev/null
then
  if [ -w /etc/passwd ]
  then
    echo "${USER_NAME:-user}:x:$(id -u):0:${USER_NAME:-user} user:${HOME}:/bin/bash" >> /etc/passwd
    echo "${USER_NAME:-user}:x:$(id -u):" >> /etc/group
  fi
fi

# Create subuid/gid entries for the user
USER=$(whoami)
START_ID=$(( $(id -u)+1 ))
echo "${USER}:${START_ID}:2147483646" > /etc/subuid
echo "${USER}:${START_ID}:2147483646" > /etc/subgid

# Configure Z shell
if [ ! -f ${HOME}/.zshrc ]
then
  (echo "HISTFILE=${HOME}/.zsh_history"; echo "HISTSIZE=1000"; echo "SAVEHIST=1000") > ${HOME}/.zshrc
  (echo "if [ -f ${PROJECT_SOURCE}/workspace.rc ]"; echo "then"; echo "  . ${PROJECT_SOURCE}/workspace.rc"; echo "fi") >> ${HOME}/.zshrc
fi

# Login to the local image registry
podman login -u $(oc whoami) -p $(oc whoami -t)  image-registry.openshift-image-registry.svc.cluster.local:5000

exec "$@"
