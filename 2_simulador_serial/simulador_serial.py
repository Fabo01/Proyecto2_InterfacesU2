import sys
import time
import random
import serial

# Guardamos los valores anteriores de cada estacion (UMA 1 a 5)
# para que las mediciones cambien de forma gradual y realista
estado_estaciones = {}

for uma in range(1, 6):
    estado_estaciones[uma] = {
        "mp1_0": random.randint(20, 70),
        "mp2_5": random.randint(25, 80),
        "mp10": random.randint(30, 85),
        "part_03": random.randint(2000, 8000),
        "part_05": random.randint(1500, 7500),
        "part_10": random.randint(1000, 7000),
        "part_25": random.randint(1000, 6500),
        "part_50": random.randint(800, 6000),
        "part_100": random.randint(500, 5500),
        "temperatura": random.randint(12, 24),
        "humedad": random.randint(35, 60)
    }

# Aplica una variacion suave manteniendo el valor dentro del rango permitido
def variar_valor(valor_actual, cambio_maximo, minimo, maximo):
    nuevo = valor_actual + random.randint(-cambio_maximo, cambio_maximo)
    if nuevo < minimo:
        nuevo = minimo + random.randint(1, cambio_maximo)
    elif nuevo > maximo:
        nuevo = maximo - random.randint(1, cambio_maximo)
    return nuevo

# Genera los 12 valores enteros de la trama ambiental para una estacion UMA
def generar_trama(id_uma):
    datos = estado_estaciones[id_uma]

    # Material particulado en ug/m3 (rango de la pauta: 5 a 100)
    datos["mp1_0"] = variar_valor(datos["mp1_0"], 8, 5, 100)
    datos["mp2_5"] = variar_valor(datos["mp2_5"], 8, 5, 100)
    datos["mp10"] = variar_valor(datos["mp10"], 8, 5, 100)

    # Conteo de particulas por diametro (rango de la pauta: 10 a 10000)
    datos["part_03"] = variar_valor(datos["part_03"], 600, 10, 10000)
    datos["part_05"] = variar_valor(datos["part_05"], 600, 10, 10000)
    datos["part_10"] = variar_valor(datos["part_10"], 600, 10, 10000)
    datos["part_25"] = variar_valor(datos["part_25"], 600, 10, 10000)
    datos["part_50"] = variar_valor(datos["part_50"], 600, 10, 10000)
    datos["part_100"] = variar_valor(datos["part_100"], 600, 10, 10000)

    # Temperatura (5 a 30 C) y humedad relativa (20 a 70 %)
    datos["temperatura"] = variar_valor(datos["temperatura"], 1, 5, 30)
    datos["humedad"] = variar_valor(datos["humedad"], 2, 20, 70)

    # Unimos los 12 valores separados por comas para enviarlos por el puerto serial
    return (
        f"{id_uma},{datos['mp1_0']},{datos['mp2_5']},{datos['mp10']},"
        f"{datos['part_03']},{datos['part_05']},{datos['part_10']},"
        f"{datos['part_25']},{datos['part_50']},{datos['part_100']},"
        f"{datos['temperatura']},{datos['humedad']}"
    )

if __name__ == "__main__":
    # Usamos COM2 por defecto o el puerto que pasemos por consola
    nombre_puerto = "COM2"
    if len(sys.argv) > 1:
        nombre_puerto = sys.argv[1]

    # Intentamos abrir el puerto serial
    try:
        puerto = serial.Serial(nombre_puerto, baudrate=9600, timeout=1)
        print(f"Conectado al puerto {nombre_puerto} a 9600 baudios.")
        print("Iniciando envio de tramas hacia Lazarus (Presiona Ctrl+C para salir)...")
    except Exception as error:
        print(f"Error al conectar con {nombre_puerto}: {error}")
        print("Verifica que el puerto virtual este creado y activo en VSPE.")
        sys.exit(1)

    try:
        # Ciclo infinito enviando datos continuos rotando entre las 5 UMA
        while True:
            for id_uma in range(1, 6):
                trama = generar_trama(id_uma)
                # Convertimos el texto a bytes con salto de linea para que lo reciba Lazarus
                puerto.write((trama + "\r\n").encode("utf-8"))
                print(f"Trama enviada UMA {id_uma}: {trama}")
                time.sleep(0.3)

    except KeyboardInterrupt:
        print("\nDeteniendo el simulador serial...")
    finally:
        if "puerto" in locals() and puerto.is_open:
            puerto.close()
            print("Puerto serial cerrado de forma limpia.")
