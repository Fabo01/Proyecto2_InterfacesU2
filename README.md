# Proyecto #2 (Unidad II) - Interfaces Gráficas (INFO1128)

Sistema de monitoreo ambiental (**DataLogger**) para 5 estaciones (**UMA 1 a UMA 5**) implementado con **Lazarus Object Pascal**, **Python (Simulador Serial RS-232)**, **Flask (API REST)**, **SQLite3** y **Matplotlib**.

---

## Estructura del Proyecto

```text
Proyecto2_InterfacesU2/
├── 1_servidor_flask/
│   ├── servidor.py               # Servidor Flask (Puerto 7070), SQLite y Matplotlib (3 Subplots)
│   ├── static/                   # Carpeta donde se guarda grafico.png
│   └── templates/
│       └── index.html            # Vista web con grafica Matplotlib y enlaces a consultas JSON
├── 2_simulador_serial/
│   └── simulador_serial.py       # Simulador de tramas ambientales por puerto COM2 (9600-8N1)
├── 3_lazarus_datalogger/
│   ├── datalogger.lpr            # Archivo principal del proyecto Lazarus
│   ├── datalogger.lpi            # Configuracion de paquetes (LazSerialPort, TAChartLazarusPkg, LCL)
│   ├── main.pas                  # Logica de recepcion serial, Scrolling Left y envio HTTP POST JSON
│   ├── main.lfm                  # Diseno del formulario principal
│   ├── fondo_grafico.jpg         # Imagen de paisaje ambiental para el grafico de series
│   └── capturas/                 # Carpeta donde se guardan las capturas PNG de los graficos
├── informe_defensa.tex           # Guia general de arquitectura, flujo de datos y preguntas de defensa
├── informe_interfaces_visual.tex # Guia enfocada 100% en Interfaces Graficas (como se pinta en Lazarus y Matplotlib)
└── requirements.txt              # Librerias de Python necesarias
```

---

## Instalación en el Notebook (1 sola vez)

1. Tener instalado **Python 3**, **Git**, **VSPE (Virtual Serial Port Emulator)** y **Lazarus IDE (Win64)** con el paquete **`LazSerial`** instalado desde *Paquete -> Online Package Manager ...*.
2. Clonar el repositorio e instalar las librerías de Python:
   ```bash
   git clone https://github.com/<TU_USUARIO>/Proyecto2_InterfacesU2.git
   cd Proyecto2_InterfacesU2
   pip install -r requirements.txt
   ```

---

## Cómo Ejecutar el Proyecto Paso a Paso

1. **Puerto Virtual (VSPE):**
   - Abrir **VSPE**, crear un dispositivo **`Connector`** en el puerto **`COM2`** y darle a **Play**.

2. **Interfaz Gráfica (Lazarus):**
   - Abrir `3_lazarus_datalogger/datalogger.lpi` en Lazarus IDE y presionar **F9**.
   - En la ventana del DataLogger, marcar las casillas **`COM On/Off`** y **`Envía a Flask`**.

3. **Servidor Flask + SQLite + Matplotlib (Terminal 1):**
   ```bash
   cd 1_servidor_flask
   python servidor.py
   ```

4. **Simulador Serial Python (Terminal 2):**
   ```bash
   cd 2_simulador_serial
   python simulador_serial.py
   ```

5. **Visualización en el Navegador Web:**
   - **Gráfica Matplotlib (3 Subplots) y Panel:** `http://127.0.0.1:7070/`
   - **Consultas JSON directas (API REST):**
     - `http://127.0.0.1:7070/data`
     - `http://127.0.0.1:7070/data/ultimo`
     - `http://127.0.0.1:7070/data/uma/1` (del `1` al `5`)
