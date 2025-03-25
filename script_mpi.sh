#!/bin/bash

# Generar el archivo de hosts
echo "node1" > hosts
echo "node2" >> hosts
echo "node3" >> hosts
echo "node4" >> hosts
echo "node5" >> hosts

# Ejecutar el programa MPI
mpirun --allow-run-as-root --hostfile hosts -np 3 ./clave
