import os
import sqlite3
from datetime import datetime
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from flask import Flask, request, jsonify, render_template, send_file

app = Flask(__name__)

# Rutas dinámicas para la base de datos y la imagen estática
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ruta_bd = os.path.join(BASE_DIR, "datos_ambientales.db")
carpeta_static = os.path.join(BASE_DIR, "static")
RUTA_GRAFICO = os.path.join(carpeta_static, "grafico.png")

# Nos aseguramos de que la carpeta static exista
os.makedirs(carpeta_static, exist_ok=True)

# Funcion para abrir conexion con la base de datos sqlite
def conectar_bd():
    conexion = sqlite3.connect(ruta_bd)
    # Usamos sqlite3.Row para poder acceder a los campos por su nombre de columna
    conexion.row_factory = sqlite3.Row
    return conexion

# Crea la tabla de mediciones si no existe en la base de datos
def inicializar_bd():
    conexion = conectar_bd()
    cursor = conexion.cursor()
    # Activamos el modo WAL para mejorar concurrencia entre lecturas y escrituras
    cursor.execute("PRAGMA journal_mode=WAL;")
    cursor.execute(
        "CREATE TABLE IF NOT EXISTS mediciones ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "fecha_hora TEXT NOT NULL, "
        "id_uma INTEGER NOT NULL, "
        "mp1_0 INTEGER NOT NULL, "
        "mp2_5 INTEGER NOT NULL, "
        "mp10 INTEGER NOT NULL, "
        "part_03 INTEGER NOT NULL, "
        "part_05 INTEGER NOT NULL, "
        "part_10 INTEGER NOT NULL, "
        "part_25 INTEGER NOT NULL, "
        "part_50 INTEGER NOT NULL, "
        "part_100 INTEGER NOT NULL, "
        "temperatura INTEGER NOT NULL, "
        "humedad INTEGER NOT NULL"
        ");"
    )
    conexion.commit()
    conexion.close()

# Genera el grafico de 3 subplots usando matplotlib y lo guarda en static/grafico.png
def generar_grafico(uma_seleccionada=None, limite=20):
    conexion = conectar_bd()
    cursor = conexion.cursor()

    # Consultamos las ultimas mediciones segun si hay filtro por UMA o no
    if uma_seleccionada is not None:
        cursor.execute(
            "SELECT * FROM mediciones WHERE id_uma = ? ORDER BY id DESC LIMIT ?",
            (uma_seleccionada, limite)
        )
    else:
        cursor.execute(
            "SELECT * FROM mediciones ORDER BY id DESC LIMIT ?",
            (limite,)
        )

    filas = cursor.fetchall()
    conexion.close()

    registros = [dict(fila) for fila in filas]
    # Invertimos la lista para que el tiempo avance de izquierda a derecha
    registros.reverse()

    plt.style.use('bmh')
    fig = plt.figure(figsize=(11, 9))

    # Si no hay mediciones todavia, mostramos un mensaje informativo
    if not registros:
        plt.text(0.5, 0.5, "Aun no hay mediciones registradas en la base de datos", ha='center', va='center', fontsize=13)
        plt.axis('off')
        plt.tight_layout()
        plt.savefig(RUTA_GRAFICO, dpi=100)
        plt.close(fig)
        return

    # Extraemos las horas en formato corto HH:MM:SS para el eje horizontal
    horas = [r["fecha_hora"].split(" ")[-1] for r in registros]
    posiciones_x = list(range(len(registros)))
    valores_mp1 = [r["mp1_0"] for r in registros]
    valores_mp25 = [r["mp2_5"] for r in registros]
    valores_mp10 = [r["mp10"] for r in registros]
    valores_temp = [r["temperatura"] for r in registros]
    valores_hum = [r["humedad"] for r in registros]

    # Subplot 1: Series temporales de material particulado
    plt.subplot(3, 1, 1)
    plt.plot(posiciones_x, valores_mp1, label="MP 1.0", marker='o', color='#2563eb', linewidth=1.8)
    plt.plot(posiciones_x, valores_mp25, label="MP 2.5", marker='s', color='#10b981', linewidth=1.8)
    plt.plot(posiciones_x, valores_mp10, label="MP 10", marker='^', color='#ef4444', linewidth=1.8)

    if uma_seleccionada is not None:
        plt.title(f"Material Particulado en el Tiempo (Estacion UMA {uma_seleccionada})", fontsize=11)
    else:
        plt.title("Material Particulado en el Tiempo (Todas las Estaciones)", fontsize=11)

    plt.ylabel("ug/m3")
    plt.xticks(posiciones_x, horas, rotation=25, fontsize=8)
    plt.legend(loc="upper right")

    # Subplot 2: Histograma de partículas por tamaño para la última medición
    plt.subplot(3, 1, 2)
    ultimo = registros[-1]
    tamanos = ["0.3 um", "0.5 um", "1.0 um", "2.5 um", "5.0 um", "10.0 um"]
    conteos = [
        ultimo["part_03"],
        ultimo["part_05"],
        ultimo["part_10"],
        ultimo["part_25"],
        ultimo["part_50"],
        ultimo["part_100"]
    ]
    colores = ["#3b82f6", "#06b6d4", "#10b981", "#f59e0b", "#f97316", "#ef4444"]
    barras = plt.bar(tamanos, conteos, color=colores, width=0.55)

    for barra, valor in zip(barras, conteos):
        plt.text(barra.get_x() + barra.get_width() / 2.0, valor + (max(conteos) * 0.02 + 5), str(valor), ha='center', va='bottom', fontsize=9)

    plt.ylim(0, max(conteos) * 1.2 + 100)
    plt.title(f"Distribucion de Particulas por Diametro (Ultima medicion UMA {ultimo['id_uma']})", fontsize=11)
    plt.ylabel("Cantidad")

    # Subplot 3: Evolución de temperatura y humedad en el tiempo
    plt.subplot(3, 1, 3)
    plt.plot(posiciones_x, valores_temp, label="Temperatura (C)", marker='o', color='#f59e0b', linewidth=1.8)
    plt.plot(posiciones_x, valores_hum, label="Humedad (%)", marker='s', color='#06b6d4', linewidth=1.8)
    plt.title("Temperatura y Humedad Relativa en el Tiempo", fontsize=11)
    plt.ylabel("Valor")
    plt.xlabel("Hora de medicion")
    plt.xticks(posiciones_x, horas, rotation=25, fontsize=8)
    plt.legend(loc="upper right")

    plt.tight_layout()
    plt.savefig(RUTA_GRAFICO, dpi=100)
    plt.close(fig)

# Ruta principal para recibir mediciones por POST o consultarlas por GET
@app.route('/data', methods=['POST', 'GET'])
def manejar_data():
    if request.method == 'POST':
        datos = request.get_json()
        if not datos:
            return jsonify({"error": "No se recibieron datos JSON validos"}), 400

        # Obtenemos la fecha y hora actual en formato texto
        fecha_hora = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        conexion = conectar_bd()
        cursor = conexion.cursor()
        cursor.execute(
            "INSERT INTO mediciones ("
            "fecha_hora, id_uma, mp1_0, mp2_5, mp10, "
            "part_03, part_05, part_10, part_25, part_50, part_100, "
            "temperatura, humedad"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                fecha_hora,
                datos.get('id_uma'),
                datos.get('mp1_0'),
                datos.get('mp2_5'),
                datos.get('mp10'),
                datos.get('part_03'),
                datos.get('part_05'),
                datos.get('part_10'),
                datos.get('part_25'),
                datos.get('part_50'),
                datos.get('part_100'),
                datos.get('temperatura'),
                datos.get('humedad')
            )
        )
        id_insertado = cursor.lastrowid
        conexion.commit()
        conexion.close()

        # Mensaje simple en consola para verificar que llego la medicion
        print(f"Medicion recibida de UMA {datos.get('id_uma')}: PM2.5={datos.get('mp2_5')}, Temp={datos.get('temperatura')}C, Hum={datos.get('humedad')}% (ID: {id_insertado})")

        return jsonify({
            "estado": "Todo OK",
            "id": id_insertado,
            "fecha_hora": fecha_hora
        }), 201

    # Si la peticion es GET, consultamos las mediciones guardadas
    uma_parametro = request.args.get('uma', type=int)
    limite = request.args.get('limite', default=50, type=int)

    conexion = conectar_bd()
    cursor = conexion.cursor()

    if uma_parametro is not None:
        cursor.execute(
            "SELECT * FROM mediciones WHERE id_uma = ? ORDER BY id DESC LIMIT ?",
            (uma_parametro, limite)
        )
    else:
        cursor.execute(
            "SELECT * FROM mediciones ORDER BY id DESC LIMIT ?",
            (limite,)
        )

    filas = cursor.fetchall()
    conexion.close()

    # Convertimos cada fila de sqlite a un diccionario comun de python
    lista_mediciones = [dict(fila) for fila in filas]
    return jsonify(lista_mediciones)

# Ruta para obtener la ultima medicion registrada en la base de datos
@app.route('/data/ultimo', methods=['GET'])
def obtener_ultimo():
    uma_parametro = request.args.get('uma', type=int)

    conexion = conectar_bd()
    cursor = conexion.cursor()

    if uma_parametro is not None:
        cursor.execute(
            "SELECT * FROM mediciones WHERE id_uma = ? ORDER BY id DESC LIMIT 1",
            (uma_parametro,)
        )
    else:
        cursor.execute(
            "SELECT * FROM mediciones ORDER BY id DESC LIMIT 1"
        )

    fila = cursor.fetchone()
    conexion.close()

    if fila is None:
        return jsonify({"mensaje": "No hay mediciones registradas"}), 404

    return jsonify(dict(fila))

# Ruta para consultar las mediciones de una estacion UMA especifica
@app.route('/data/uma/<int:id_uma>', methods=['GET'])
def obtener_por_uma(id_uma):
    limite = request.args.get('limite', default=50, type=int)

    conexion = conectar_bd()
    cursor = conexion.cursor()
    cursor.execute(
        "SELECT * FROM mediciones WHERE id_uma = ? ORDER BY id DESC LIMIT ?",
        (id_uma, limite)
    )
    filas = cursor.fetchall()
    conexion.close()

    lista_mediciones = [dict(fila) for fila in filas]
    return jsonify(lista_mediciones)

# Ruta para devolver la imagen png del grafico de matplotlib
@app.route("/grafico.png", methods=["GET"])
def servir_grafico():
    uma = request.args.get("uma", type=int)
    limite = request.args.get("limite", default=20, type=int)
    generar_grafico(uma, limite)
    return send_file(RUTA_GRAFICO, mimetype="image/png")

# Ruta principal con la pagina web de visualizacion
@app.route("/", methods=["GET"])
def pagina_principal():
    uma = request.args.get("uma", type=int)

    conexion = conectar_bd()
    cursor = conexion.cursor()

    # Obtenemos el total de registros almacenados
    cursor.execute("SELECT COUNT(*) FROM mediciones")
    total_registros = cursor.fetchone()[0]

    # Obtenemos la medicion mas reciente (filtrada por UMA si corresponde)
    if uma is not None:
        cursor.execute(
            "SELECT * FROM mediciones WHERE id_uma = ? ORDER BY id DESC LIMIT 1",
            (uma,)
        )
    else:
        cursor.execute("SELECT * FROM mediciones ORDER BY id DESC LIMIT 1")

    fila = cursor.fetchone()
    conexion.close()

    ultimo = dict(fila) if fila else None

    return render_template("index.html", ultimo=ultimo, uma_actual=uma, total_registros=total_registros)

if __name__ == '__main__':
    # Creamos la tabla al arrancar la aplicacion
    inicializar_bd()
    print("Iniciando servidor Flask en http://127.0.0.1:7070...")
    app.run(host='0.0.0.0', port=7070, debug=True)
