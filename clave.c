#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <omp.h>
#include <mpi.h>

// Configuración
#define MAX_LENGTH 6
#define REAL_PASSWORD "abcdef"  // CAMBIAR POR CLAVE REAL
#define CHAR_SET "abcdefghijklmnopqrstuvwxyz0123456789"

// Variables globales
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
                printf("Proceso: %d/%d\nHilo: %d\nClave: %s\n", 
                      rank+1, size, omp_get_thread_num(), guess);
                printf("=======================\n");
                fflush(stdout);
                
                // Notificar a otros procesos
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
    
    // Verificar si hay mensajes entrantes
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
    
    double start = MPI_Wtime();
    printf("Nodo %d/%d iniciado\n", rank+1, size);
    
    // Dividir el trabajo
    int charset_len = strlen(CHAR_SET);
    int chars_por_nodo = charset_len / size;
    int inicio = rank * chars_por_nodo;
    int fin = (rank == size - 1) ? charset_len : inicio + chars_por_nodo;
    
    printf("Nodo %d procesando caracteres %c-%c\n", 
          rank, CHAR_SET[inicio], CHAR_SET[fin-1]);
    
    char guess[MAX_LENGTH + 1] = {0};
    
    // Cada nodo procesa su rango de caracteres
    for (int i = inicio; i < fin && !clave_encontrada; i++) {
        guess[0] = CHAR_SET[i];
        generar_combinaciones(guess, 1, MAX_LENGTH, rank, size);
    }
    
    double end = MPI_Wtime();
    printf("Nodo %d terminó en %.2f segundos\n", rank, end-start);
    
    // Sincronización final
    MPI_Barrier(MPI_COMM_WORLD);
    
    if (rank == 0) {
        if (clave_encontrada) {
            printf("\nRESULTADO FINAL:\nClave encontrada: %s\n", clave_resultado);
        } else {
            printf("\nRESULTADO FINAL:\nNo se encontró la clave\n");
        }
    }
    
    MPI_Finalize();
    return 0;
}
