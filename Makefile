CC = mpicc
CFLAGS = -Wall -O3 -fopenmp
TARGET = clave

all: $(TARGET)

$(TARGET): clave.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGET)
