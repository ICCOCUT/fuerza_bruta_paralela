#!/bin/bash

# Iniciar SSH
service ssh start

# Generar clave SSH si no existe
if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
fi

# Esperar configuración de red
sleep 5

# Obtener IPs de los nodos
NODE_IPS=$(getent hosts node1 node2 node3 node4 node5 | awk '{print $1}')
for ip in $NODE_IPS; do
    until ping -c1 $ip &>/dev/null; do
        echo "Esperando a $ip..."
        sleep 1
    done
    ssh-keyscan -H $ip >> /root/.ssh/known_hosts
done

# Solo el nodo1 distribuye las claves y ejecuta MPI
if [ "$HOSTNAME" = "node1" ]; then
    echo "Distribuyendo claves SSH..."
    for node in node2 node3 node4 node5; do
        sshpass -p "root" ssh-copy-id -o StrictHostKeyChecking=no root@$node
    done

    echo "node1 slots=1" > /app/hosts
    echo "node2 slots=1" >> /app/hosts
    echo "node3 slots=1" >> /app/hosts
    echo "node4 slots=1" >> /app/hosts
    echo "node5 slots=1" >> /app/hosts

    echo "Iniciando MPI..."
    mpirun --hostfile /app/hosts -np 5 /app/clave | tee /app/output.log
    echo "Resultados:"
    cat /app/output.log
else
    echo "Nodo $HOSTNAME listo"
    tail -f /dev/null
fi
