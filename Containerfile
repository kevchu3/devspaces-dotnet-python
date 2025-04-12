# FROM registry.access.redhat.com/ubi9-minimal
FROM quay.io/fedora/fedora:41

ARG USER_HOME_DIR="/home/user"
ARG WORK_DIR="/projects"
ARG INSTALL_PACKAGES="procps-ng openssl git tar gzip zip xz unzip which shadow-utils bash bash-completion zsh vi wget jq gh podman buildah skopeo podman-docker glibc-devel zlib-devel gcc libffi-devel libstdc++-devel gcc-c++ glibc-langpack-en ca-certificates python3-pip python3-devel fuse-overlayfs util-linux vim-minimal vim-enhanced"

ENV HOME=${USER_HOME_DIR} \
    KUBECONFIG=/home/user/.kube/config \
    BUILDAH_ISOLATION=chroot \
    PATH="/home/user/.local/bin:${PATH:-/bin:/usr/bin}"

COPY --chown=0:0 tools/entrypoint.sh /

RUN microdnf install -y ${INSTALL_PACKAGES}; \
  microdnf update -y ; \
  microdnf clean all ; \
  mkdir -p /usr/local/bin ; \
  mkdir -p ${WORK_DIR} ; \
  pip3 install -U podman-compose ; \
  pip3 install -U cekit ; \
  mkdir -p /home/user/.local/share ; \
  mkdir -p /home/user/.local/bin ; \
  chgrp -R 0 /home ; \
  chmod -R g=u /home ${WORK_DIR} ; \
  chmod +x /entrypoint.sh ; \
  chown 0:0 /etc/passwd ; \
  chown 0:0 /etc/group ; \
  chmod g=u /etc/passwd /etc/group ; \
  # Setup for rootless podman
  setcap cap_setuid+ep /usr/bin/newuidmap ; \
  setcap cap_setgid+ep /usr/bin/newgidmap ; \
  touch /etc/subgid /etc/subuid ; \
  chown 0:0 /etc/subgid ; \
  chown 0:0 /etc/subuid ; \
  chmod -R g=u /etc/subuid /etc/subgid ; \
  # Create Sym Links for OpenShift CLI (Assumed to be retrieved by an init-container)
  ln -s /projects/bin/oc /usr/local/bin/oc ; \
  ln -s /projects/bin/kubectl /usr/local/bin/kubectl

# Install .NET
ENV DOTNET_RPM_VERSION=9.0
RUN dnf install -y dotnet-hostfxr-${DOTNET_RPM_VERSION} dotnet-runtime-${DOTNET_RPM_VERSION} dotnet-sdk-${DOTNET_RPM_VERSION}

# Install oc cli
ENV OC_BINARY=openshift-client-linux

RUN wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.17/${OC_BINARY}.tar.gz && \
    gzip -dvf ${OC_BINARY}.tar.gz && tar -xvf ${OC_BINARY}.tar && \
    chmod 755 oc && mv oc /usr/bin/ && /bin/rm -rf ${OC_BINARY}.tar kubectl README.md

# Install Python
# https://catalog.redhat.com/software/containers/devspaces/udi-rhel9/673f8460bbf0c33aca0fe316?container-tabs=dockerfile
ENV PYTHON_VERSION="3.13"
RUN dnf -y -q install --setopt=tsflags=nodocs \
    python${PYTHON_VERSION} python${PYTHON_VERSION}-devel python${PYTHON_VERSION}-setuptools python${PYTHON_VERSION}-pip python${PYTHON_VERSION}-wheel && \

    python${PYTHON_VERSION} -m pip install --user --no-cache-dir --upgrade pip setuptools pytest flake8 virtualenv yq && \
    # python/pip/flake8/yq symlinks
    echo "Create python symlinks (or display existing ones) ==>" && \
    echo -e "#/usr/bin/bash\n/usr/bin/python${PYTHON_VERSION} -m pip \$*" | sed -r -e "s@#@#\!@" > /usr/bin/pip && \
    echo -e "#/usr/bin/bash\n/usr/bin/python${PYTHON_VERSION} -m pip \$*" | sed -r -e "s@#@#\!@" > /usr/bin/pip${PYTHON_VERSION} && \
    echo -e "#/usr/bin/bash\n/usr/bin/python${PYTHON_VERSION} -m flake8 \$*" | sed -r -e "s@#@#\!@" > /usr/bin/flake8 && \
    echo -e "#/usr/bin/bash\n/usr/bin/python${PYTHON_VERSION} -m flake8 \$*" | sed -r -e "s@#@#\!@" > /usr/bin/flake8${PYTHON_VERSION} && \
    echo -e "#/usr/bin/bash\n/usr/bin/python${PYTHON_VERSION} -m pytest \$*" | sed -r -e "s@#@#\!@" > /usr/bin/pytest && \
    echo -e "#/usr/bin/bash\n/usr/bin/python${PYTHON_VERSION} -m pytest \$*" | sed -r -e "s@#@#\!@" > /usr/bin/pytest${PYTHON_VERSION} && \
    echo -e "#/usr/bin/bash\n/usr/bin/python${PYTHON_VERSION} -m yq \$*" | sed -r -e "s@#@#\!@" > /usr/bin/yq && \
    chmod +x /usr/bin/pip* /usr/bin/py* /usr/bin/yq && \
    SL=/usr/local/bin/python; if [[ ! -f ${SL} ]] && [[ ! -L ${SL} ]]; then ln -s /usr/bin/python${PYTHON_VERSION} ${SL}; else ls -la ${SL}; fi && \
    SL=/usr/local/bin/pip; if [[ ! -f ${SL} ]] && [[ ! -L ${SL} ]]; then ln -s /usr/bin/pip${PYTHON_VERSION} ${SL}; else ls -la ${SL}; fi && \
    SL=/usr/local/bin/flake8; if [[ ! -f ${SL} ]] && [[ ! -L ${SL} ]]; then ln -s /usr/bin/flake8${PYTHON_VERSION} ${SL}; else ls -la ${SL}; fi && \
    SL=/usr/local/bin/pytest; if [[ ! -f ${SL} ]] && [[ ! -L ${SL} ]]; then ln -s /usr/bin/pytest${PYTHON_VERSION} ${SL}; else ls -la ${SL}; fi && \
    SL=/usr/local/bin/yq; if [[ ! -f ${SL} ]] && [[ ! -L ${SL} ]]; then ln -s /usr/bin/yq ${SL}; else ls -la ${SL}; fi && \
    chmod +x /usr/local/bin/* && \
    echo -n "/usr/local/bin/python: "; /usr/local/bin/python -V && \
    echo -n "/usr/local/bin/pip: ";    /usr/local/bin/pip -V && \
    echo -n "/usr/local/bin/flake8: "; /usr/local/bin/flake8 --version && \
    echo -n "/usr/local/bin/pytest: "; /usr/local/bin/pytest --version && \
    echo -n "/usr/local/bin/yq:     "; /usr/local/bin/yq --version && \
    # set up ~/.venv
    cd $HOME; /usr/bin/python${PYTHON_VERSION} -m venv .venv && \
    echo "python basic install:"; python -V; \
    echo -n "pip:    "; pip -V; \
    echo -n "flake8: "; flake8 --version | tr "\n" "," | sed -r -e "s@,\$@\n@"; \
    echo -n "pytest: "; pytest --version; \
    echo -n "jq:     "; jq --version; \
    echo -n "yq:     "; yq --version; \
    echo "========" && \
    echo "python venv install:"; source $HOME/.venv/bin/activate && python -V; \
    echo -n "pip:    "; pip -V; \
    echo -n "flake8: "; flake8 --version | tr "\n" "," | sed -r -e "s@,\$@\n@"; \
    echo -n "pytest: "; pytest --version; \
    echo -n "jq:     "; jq --version; \
    echo -n "yq:     "; yq --version; \
    echo "========"

# Install oc completion
RUN oc completion bash > oc_bash_completion && \
    mv oc_bash_completion /etc/bash_completion.d/ && \
    cp /etc/skel/.bashrc $USER_HOME_DIR/.bashrc

# A last pass to make sure that an arbitrary user can write in $HOME
RUN chgrp -R 0 /home && chmod -R g=u /home

USER 1001

WORKDIR ${WORK_DIR}
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "tail", "-f", "/dev/null" ]
