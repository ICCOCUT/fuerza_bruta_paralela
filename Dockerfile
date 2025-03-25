FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    build-essential \
    openmpi-bin \
    libopenmpi-dev \
    openssh-server \
    sshpass \
    iputils-ping \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Configurar SSH sin restricciones
RUN mkdir -p /var/run/sshd && \
    echo 'root:root' | chpasswd && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd && \
    echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config && \
    echo "UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config 2>/dev/null

# Preparar entorno MPI
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

WORKDIR /app
COPY . /app/

RUN make && \
    chmod +x /app/start.sh

ENV OMPI_ALLOW_RUN_AS_ROOT=1
ENV OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
ENV OMPI_MCA_plm_rsh_no_tree_spawn=1
ENV OMPI_MCA_btl_vader_single_copy_mechanism=none

EXPOSE 22
CMD ["/app/start.sh"]
