#!/bin/bash

# Iniciar SSH
service ssh start

# Configurar SSH para MPI
if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
fi

# Esperar a que los nodos estén disponibles
sleep 10

# Configurar hosts conocidos
for node in node1 node2 node3 node4 node5; do
    if [ "$HOSTNAME" != "$node" ]; then
        ssh-keyscan -H $node >> /root/.ssh/known_hosts
        sshpass -p "root" ssh-copy-id -f -o StrictHostKeyChecking=no root@$node
    fi
done

# Solo el nodo1 ejecuta MPI
if [ "$HOSTNAME" = "node1" ]; then
    echo "node1 slots=1" > /app/hosts
    echo "node2 slots=1" >> /app/hosts
    echo "node3 slots=1" >> /app/hosts
    echo "node4 slots=1" >> /app/hosts
    echo "node5 slots=1" >> /app/hosts

    echo "Probando conexiones SSH..."
    for node in node2 node3 node4 node5; do
        if ssh -o BatchMode=yes root@$node echo "Conexión SSH a $node exitosa"; then
            echo "SSH a $node configurado correctamente"
        else
            echo "Fallo en SSH a $node"
            exit 1
        fi
    done

    echo "Iniciando MPI con 5 procesos..."
    mpirun --hostfile /app/hosts -np 5 \
        --mca plm_rsh_no_tree_spawn 1 \
        --mca btl_vader_single_copy_mechanism none \
        /app/clave | tee /app/output.log

    echo -e "\nRESULTADO FINAL:"
    grep -A 5 -B 2 "¡CLAVE ENCONTRADA!" /app/output.log || echo "No se encontró la clave"
else
    echo "Nodo $HOSTNAME esperando conexiones MPI..."
    tail -f /dev/null
fi
