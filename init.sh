#!/bin/bash

echo "==============================="
echo "Proyecto Programacion Paralela"
echo "==============================="

# Solicitar la clave al usuario
read -p "Ingrese la clave a buscar (solo caracteres alfanuméricos): " CLAVE

# Validar la entrada
if [[ ! "$CLAVE" =~ ^[a-zA-Z0-9]+$ ]]; then
    echo "Error: La clave solo puede contener caracteres alfanuméricos."
    exit 1
fi

# Crear el archivo clave.c con la clave proporcionada
cat >clave.c <<EOF
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <omp.h>
#include <mpi.h>

#define MAX_LENGTH ${#CLAVE}
#define REAL_PASSWORD "$CLAVE"
#define CHAR_SET "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

int clave_encontrada = 0;
char clave_resultado[MAX_LENGTH + 1] = {0};

void probar_clave(const char *guess, int rank, int size) {
    if (strcmp(guess, REAL_PASSWORD) == 0) {
        #pragma omp critical
        {
            if (!clave_encontrada) {
                clave_encontrada = 1;
                strncpy(clave_resultado, guess, MAX_LENGTH);
                printf("\n=== CLAVE ENCONTRADA ===\n");
                printf("Proceso: %d/%d\nClave: %s\n", rank+1, size, guess);
                printf("=======================\n");
                fflush(stdout);
                
                int flag = 1;
                for (int i = 0; i < size; i++) {
                    if (i != rank) {
                        MPI_Send(&flag, 1, MPI_INT, i, 0, MPI_COMM_WORLD);
                    }
                }
            }
        }
    }
}

void generar_combinaciones(char *guess, int pos, int max_len, int rank, int size) {
    if (clave_encontrada) return;
    
    int flag;
    MPI_Status status;
    MPI_Iprobe(MPI_ANY_SOURCE, 0, MPI_COMM_WORLD, &flag, &status);
    if (flag) {
        MPI_Recv(&flag, 1, MPI_INT, status.MPI_SOURCE, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        clave_encontrada = 1;
        return;
    }
    
    char *charset = CHAR_SET;
    int charset_len = strlen(charset);
    
    #pragma omp parallel for
    for (int i = 0; i < charset_len; i++) {
        if (clave_encontrada) continue;
        
        guess[pos] = charset[i];
        guess[pos+1] = '\0';
        probar_clave(guess, rank, size);
        
        if (pos < max_len - 1) {
            generar_combinaciones(guess, pos + 1, max_len, rank, size);
        }
    }
}

int main(int argc, char **argv) {
    int rank, size;
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    
    printf("Nodo %d/%d iniciado\n", rank+1, size);
    
    char guess[MAX_LENGTH + 1] = {0};
    int charset_len = strlen(CHAR_SET);
    int chars_por_nodo = charset_len / size;
    int inicio = rank * chars_por_nodo;
    int fin = (rank == size - 1) ? charset_len : inicio + chars_por_nodo;
    
    #pragma omp parallel
    {
        #pragma omp single
        {
            for (int i = inicio; i < fin && !clave_encontrada; i++) {
                guess[0] = CHAR_SET[i];
                generar_combinaciones(guess, 1, MAX_LENGTH, rank, size);
            }
        }
    }
    
    MPI_Finalize();
    return 0;
}
EOF

echo "Detienendo los contenedores anteriores..."
sudo docker stop $(sudo docker ps -aq) &>/dev/null

echo "Eliminando los contenedores anteriores..."
sudo docker rm $(sudo docker ps -aq) &>/dev/null

echo "Eliminando nodos creados anteriormente..."
sudo docker-compose down &>/dev/null

echo "Eliminando las imagenes,contenedores,redes de docker"
sudo docker system prune -a &>/dev/null

# Construir y ejecutar
echo "Construyendo contenedores..."
sudo docker-compose build &>/dev/null

echo "Iniciando cluster..."
sudo docker-compose up -d

echo "Ejecutando búsqueda de la clave..."
sudo docker logs -f fuerza_bruta_paralela_node1_1 # | awk '/Iniciando/ {flag=1; next} flag'
