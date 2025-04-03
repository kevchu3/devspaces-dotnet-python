FROM registry.access.redhat.com/ubi9/ubi:9.5-1742918310

ENV HOME /home/user

USER 0

RUN dnf install -y diffutils git iproute jq less lsof man nano procps \
    perl-Digest-SHA net-tools openssh-clients rsync socat sudo time vim wget zip && \
    dnf update -y && \
    dnf clean all

RUN \
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash && \
export NVM_DIR="$HOME/.nvm" && \
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
nvm install 18.18.0
ENV VSCODE_NODEJS_RUNTIME_DIR="$HOME/.nvm/versions/node/v18.18.0/bin/"

RUN \
    # add user and configure it
    useradd -u 10001 -G wheel,root -d /home/user --shell /bin/bash -m user && \
    # Setup $PS1 for a consistent and reasonable prompt
    echo "export PS1='\W \`git branch --show-current 2>/dev/null | sed -r -e \"s@^(.+)@\(\1\) @\"\`$ '" >> /home/user/.bashrc && \
    # Set permissions on /etc/passwd and /home to allow arbitrary users to write
    chgrp -R 0 /home && \
    chmod -R g=u /etc/passwd /etc/group /home

# Install .NET
ENV DOTNET_RPM_VERSION=7.0
RUN dnf install -y dotnet-hostfxr-${DOTNET_RPM_VERSION} dotnet-runtime-${DOTNET_RPM_VERSION} dotnet-sdk-${DOTNET_RPM_VERSION}

# Install Python
# https://catalog.redhat.com/software/containers/devspaces/udi-rhel9/673f8460bbf0c33aca0fe316?container-tabs=dockerfile
ENV PYTHON_VERSION="3.11"
RUN dnf -y -q install --setopt=tsflags=nodocs \
    python3.11 python3.11-devel python3.11-setuptools python3.11-pip python3.11-wheel && \

    ########################################################################
    # Python
    ########################################################################
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
    cd /home/tooling; /usr/bin/python${PYTHON_VERSION} -m venv .venv && \
    echo "<== Create python symlinks (or display existing ones)"

USER 1001

WORKDIR /projects
