unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, ComCtrls, Buttons, TAGraph, TASeries, TATypes, TAChartUtils,
  LazSerial, fphttpclient, fpjson, jsonparser;

type
  { TFormPrincipal }
  TFormPrincipal = class(TForm)
    // Componentes del sistema serial, reloj y barra de estado
    PuertoSerial: TLazSerial;
    RelojTimer: TTimer;
    BarraEstado: TStatusBar;

    // Paneles contenedores para organizar la pantalla
    PanelSuperior: TPanel;
    PanelIzquierdo: TPanel;
    PanelGraficos: TPanel;
    PanelSeries: TPanel;
    PanelControlesSeries: TPanel;
    PanelHisto: TPanel;

    // Conectividad y envio
    ChkConectarSerial: TCheckBox;
    ChkEnviarFlask: TCheckBox;

    // Filtro por estacion ambiental UMA
    GrupoUma: TGroupBox;
    RbUma1: TRadioButton;
    RbUma2: TRadioButton;
    RbUma3: TRadioButton;
    RbUma4: TRadioButton;
    RbUma5: TRadioButton;

    // Indicadores numericos grandes de temperatura y humedad
    GrupoTemperatura: TGroupBox;
    LblTemperatura: TLabel;
    GrupoHumedad: TGroupBox;
    LblHumedad: TLabel;

    // Botones de accion para capturas y limpieza
    GrupoAcciones: TGroupBox;
    BtnGuardarSeries: TBitBtn;
    BtnGuardarHisto: TBitBtn;
    BtnLimpiar: TBitBtn;
    BtnSalir: TBitBtn;

    // Grafico de lineas temporales para material particulado
    GraficoSeries: TChart;
    SerieMP1: TLineSeries;
    SerieMP25: TLineSeries;
    SerieMP10: TLineSeries;

    // Selector de etiquetas de texto sobre las curvas
    GrupoEtiquetasMP: TGroupBox;
    RbVerMP1: TRadioButton;
    RbVerMP25: TRadioButton;
    RbVerMP10: TRadioButton;

    // Grafico de barras para histograma de diametros
    GraficoHistograma: TChart;
    SerieBarras: TBarSeries;

    // Eventos visuales y de control
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure PuertoSerialRxData(Sender: TObject);
    procedure RelojTimerTimer(Sender: TObject);
    procedure ChkConectarSerialChange(Sender: TObject);
    procedure CambiarEstacionUma(Sender: TObject);
    procedure CambiarEtiquetasMP(Sender: TObject);
    procedure BtnGuardarSeriesClick(Sender: TObject);
    procedure BtnGuardarHistoClick(Sender: TObject);
    procedure BtnLimpiarClick(Sender: TObject);
    procedure BtnSalirClick(Sender: TObject);

  private
    procedure InicializarMemorias;
    procedure ActualizarEtiquetasMP;
    procedure DibujarEstacionActual;
    procedure EnviarDatosFlask(datos_trama: array of Integer);
    procedure DibujarFondoGrafico(ASender: TChart; ACanvas: TCanvas; const ARect: TRect);
    procedure DibujarFondoHistograma(ASender: TChart; ACanvas: TCanvas; const ARect: TRect);

  public

  end;

var
  FormPrincipal: TFormPrincipal;

  // Imagenes y bitmaps pre-renderizados en cache para cero consumo de CPU
  imagen_fondo_grafico: TPicture;
  bitmap_fondo_cache: TBitmap;
  imagen_fondo_histograma: TPicture;
  bitmap_fondo_histo_cache: TBitmap;

  // Guardamos el historial por separado para cada una de las 5 estaciones UMA
  // Asi al cambiar de UMA 1 a UMA 2 y volver, no se borran los datos anteriores
  historial_mp1: array[1..5, 0..10] of Integer;
  historial_mp25: array[1..5, 0..10] of Integer;
  historial_mp10: array[1..5, 0..10] of Integer;
  valores_histograma: array[1..5, 0..5] of Integer;
  ultima_temp: array[1..5] of Integer;
  ultima_hum: array[1..5] of Integer;
  ultima_trama: array[1..5] of String;
  tiene_datos: array[1..5] of Boolean;

  // Colores y etiquetas de las 6 barras del histograma
  colores_barras: array[0..5] of TColor;
  etiquetas_diametros: array[0..5] of String;

  // Estacion actual seleccionada en pantalla (1 a 5)
  uma_seleccionada: Integer;

implementation

{$R *.lfm}

{ TFormPrincipal }

// Inicializa las variables, colores y aspecto visual al abrir el programa
procedure TFormPrincipal.FormCreate(Sender: TObject);
var
  carpeta_base: String;
begin
  uma_seleccionada := 1;

  // Cargamos la imagen de paisaje para el fondo del grafico y preparamos el bitmap de cache
  carpeta_base := ExtractFilePath(ParamStr(0));
  imagen_fondo_grafico := TPicture.Create;
  bitmap_fondo_cache := TBitmap.Create;
  if FileExists(carpeta_base + 'fondo_grafico.jpg') then
    imagen_fondo_grafico.LoadFromFile(carpeta_base + 'fondo_grafico.jpg');

  // Solo asociamos el fondo al grafico de series (no a los paneles, para mantener 60 FPS)
  GraficoSeries.OnAfterDrawBackWall := @DibujarFondoGrafico;

  // Cargamos la imagen del espacio exterior detras del histograma
  imagen_fondo_histograma := TPicture.Create;
  bitmap_fondo_histo_cache := TBitmap.Create;
  if FileExists(carpeta_base + 'fondo_histograma.jpg') then
    imagen_fondo_histograma.LoadFromFile(carpeta_base + 'fondo_histograma.jpg');

  // Asociamos el fondo cosmico al histograma
  GraficoHistograma.OnAfterDrawBackWall := @DibujarFondoHistograma;

  // Aseguramos que las casillas nazcan desmarcadas al abrir la ventana
  ChkConectarSerial.Checked := False;
  ChkEnviarFlask.Checked := False;

  // Nombres de los 6 diametros de particulas segun la pauta
  etiquetas_diametros[0] := '0.3um';
  etiquetas_diametros[1] := '0.5um';
  etiquetas_diametros[2] := '1.0um';
  etiquetas_diametros[3] := '2.5um';
  etiquetas_diametros[4] := '5.0um';
  etiquetas_diametros[5] := '10um';

  // Colores de las 6 barras iguales al estilo de la pauta
  colores_barras[0] := $002020E0; // Rojo
  colores_barras[1] := $0000B030; // Verde
  colores_barras[2] := $00D03000; // Azul intenso
  colores_barras[3] := $002070F0; // Naranjo
  colores_barras[4] := $0030C020; // Verde claro
  colores_barras[5] := $00E8C870; // Celeste

  // Configuramos fondo celeste suave en los graficos y escalas fijas para que no salten
  GraficoSeries.BackColor := $00FAE6C8;
  GraficoSeries.Color := $00E4D0B8;
  GraficoSeries.Legend.Visible := True;
  GraficoSeries.Extent.YMin := 0;
  GraficoSeries.Extent.YMax := 110;
  GraficoSeries.Extent.UseYMin := True;
  GraficoSeries.Extent.UseYMax := True;

  GraficoHistograma.BackColor := $00FAE6C8;
  GraficoHistograma.Color := $00E4D0B8;
  GraficoHistograma.BottomAxis.Marks.Source := SerieBarras.ListSource;
  GraficoHistograma.BottomAxis.Marks.Style := smsLabel;
  GraficoHistograma.Extent.YMin := 0;
  GraficoHistograma.Extent.YMax := 11200;
  GraficoHistograma.Extent.UseYMin := True;
  GraficoHistograma.Extent.UseYMax := True;

  // Estilo de las etiquetas numericas sobre las curvas (fondo rojo con letra blanca como en el PDF)
  SerieMP1.Marks.LabelBrush.Color := $002828D8;
  SerieMP1.Marks.LabelFont.Color := clWhite;
  SerieMP1.Marks.LabelFont.Style := [fsBold];

  SerieMP25.Marks.LabelBrush.Color := $002828D8;
  SerieMP25.Marks.LabelFont.Color := clWhite;
  SerieMP25.Marks.LabelFont.Style := [fsBold];

  SerieMP10.Marks.LabelBrush.Color := $002828D8;
  SerieMP10.Marks.LabelFont.Color := clWhite;
  SerieMP10.Marks.LabelFont.Style := [fsBold];

  // Etiquetas amarillas sobre las barras del histograma igual que en el PDF
  SerieBarras.Marks.LabelBrush.Color := $0066FFFF;
  SerieBarras.Marks.LabelFont.Color := clBlack;
  SerieBarras.Marks.LabelFont.Style := [fsBold];

  // Reiniciamos los arreglos y dibujamos el estado inicial
  InicializarMemorias;
  DibujarEstacionActual;

  // Mostramos la fecha y hora inicial con el formato exacto del PDF
  BarraEstado.Panels[0].Text := 'Fecha : ' + FormatDateTime('dd-mm-yyyy', Now) + ' - Hora : ' + FormatDateTime('hh:nn:ss', Now);
  BarraEstado.Panels[1].Text := 'Data : Esperando conexion en COM2 (Marca "COM On/Off")';
end;

// Cierra el puerto serial y libera las imagenes de memoria al salir
procedure TFormPrincipal.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if PuertoSerial.Active then
    PuertoSerial.Close;
  FreeAndNil(bitmap_fondo_cache);
  FreeAndNil(imagen_fondo_grafico);
  FreeAndNil(bitmap_fondo_histo_cache);
  FreeAndNil(imagen_fondo_histograma);
end;

// Dibuja el paisaje ambiental usando cache en memoria (0 ms de sobrecarga de CPU)
procedure TFormPrincipal.DibujarFondoGrafico(ASender: TChart; ACanvas: TCanvas; const ARect: TRect);
var
  ancho, alto: Integer;
begin
  if not Assigned(imagen_fondo_grafico) or (imagen_fondo_grafico.Width = 0) then
    Exit;

  ancho := ARect.Right - ARect.Left;
  alto := ARect.Bottom - ARect.Top;
  if (ancho <= 0) or (alto <= 0) then
    Exit;

  // Solo re-escalamos si cambio de tamano el grafico; de lo contrario es una copia instantanea
  if (bitmap_fondo_cache.Width <> ancho) or (bitmap_fondo_cache.Height <> alto) then
  begin
    bitmap_fondo_cache.SetSize(ancho, alto);
    bitmap_fondo_cache.Canvas.StretchDraw(Rect(0, 0, ancho, alto), imagen_fondo_grafico.Graphic);
  end;

  ACanvas.Draw(ARect.Left, ARect.Top, bitmap_fondo_cache);
end;

// Dibuja el fondo del espacio detras del histograma con tematica cosmica a las 3 AM
procedure TFormPrincipal.DibujarFondoHistograma(ASender: TChart; ACanvas: TCanvas; const ARect: TRect);
var
  ancho, alto: Integer;
begin
  if not Assigned(imagen_fondo_histograma) or (imagen_fondo_histograma.Width = 0) then
    Exit;

  ancho := ARect.Right - ARect.Left;
  alto := ARect.Bottom - ARect.Top;
  if (ancho <= 0) or (alto <= 0) then
    Exit;

  if (bitmap_fondo_histo_cache.Width <> ancho) or (bitmap_fondo_histo_cache.Height <> alto) then
  begin
    bitmap_fondo_histo_cache.SetSize(ancho, alto);
    bitmap_fondo_histo_cache.Canvas.StretchDraw(Rect(0, 0, ancho, alto), imagen_fondo_histograma.Graphic);
  end;

  ACanvas.Draw(ARect.Left, ARect.Top, bitmap_fondo_histo_cache);
end;

// Actualiza el reloj del sistema cada segundo en la barra inferior
procedure TFormPrincipal.RelojTimerTimer(Sender: TObject);
begin
  BarraEstado.Panels[0].Text := 'Fecha : ' + FormatDateTime('dd-mm-yyyy', Now) + ' - Hora : ' + FormatDateTime('hh:nn:ss', Now);
end;

// Conecta o desconecta el puerto COM2 cuando el usuario marca la casilla
procedure TFormPrincipal.ChkConectarSerialChange(Sender: TObject);
begin
  if ChkConectarSerial.Checked then
  begin
    try
      PuertoSerial.Device := 'COM2';
      PuertoSerial.BaudRate := br__9600;
      PuertoSerial.Open;
      BarraEstado.Panels[1].Text := 'Data : Puerto COM2 conectado a 9600-8N1. Escuchando tramas...';
    except
      on E: Exception do
      begin
        ChkConectarSerial.Checked := False;
        ShowMessage('Error al abrir el puerto COM2: ' + E.Message + sLineBreak +
                    'Verifica que VSPE tenga el Connector en COM2 encendido.');
        BarraEstado.Panels[1].Text := 'Data : Fallo al abrir puerto COM2.';
      end;
    end;
  end
  else
  begin
    if PuertoSerial.Active then
      PuertoSerial.Close;
    BarraEstado.Panels[1].Text := 'Data : Puerto COM2 desconectado.';
  end;
end;

// Al cambiar de RadioButton (UMA 1 a 5), mostramos los datos guardados de esa UMA sin borrarlos
procedure TFormPrincipal.CambiarEstacionUma(Sender: TObject);
begin
  if (Sender is TRadioButton) and TRadioButton(Sender).Checked then
  begin
    uma_seleccionada := TComponent(Sender).Tag;
    DibujarEstacionActual;
  end;
end;

// Muestra los cuadros con valores solo en la curva elegida y cuando ya existan datos reales
procedure TFormPrincipal.ActualizarEtiquetasMP;
var
  mostrar: Boolean;
begin
  mostrar := tiene_datos[uma_seleccionada];
  SerieMP1.Marks.Visible := mostrar and RbVerMP1.Checked;
  SerieMP25.Marks.Visible := mostrar and RbVerMP25.Checked;
  SerieMP10.Marks.Visible := mostrar and RbVerMP10.Checked;
  SerieBarras.Marks.Visible := mostrar;
end;

// Evento al cambiar los RadioButtons MP 01, MP 25 o MP 10
procedure TFormPrincipal.CambiarEtiquetasMP(Sender: TObject);
begin
  ActualizarEtiquetasMP;
end;

// Pone en cero las memorias de las 5 estaciones UMA
procedure TFormPrincipal.InicializarMemorias;
var
  u, i: Integer;
begin
  for u := 1 to 5 do
  begin
    tiene_datos[u] := False;
    ultima_temp[u] := 0;
    ultima_hum[u] := 0;
    ultima_trama[u] := '';

    for i := 0 to 10 do
    begin
      historial_mp1[u, i] := 0;
      historial_mp25[u, i] := 0;
      historial_mp10[u, i] := 0;
    end;

    for i := 0 to 5 do
      valores_histograma[u, i] := 0;
  end;
end;

// Redibuja en pantalla las curvas, barras e indicadores de la UMA seleccionada
procedure TFormPrincipal.DibujarEstacionActual;
var
  i: Integer;
begin
  ActualizarEtiquetasMP;

  SerieMP1.Clear;
  SerieMP25.Clear;
  SerieMP10.Clear;
  for i := 0 to 10 do
  begin
    SerieMP1.AddXY(i, historial_mp1[uma_seleccionada, i]);
    SerieMP25.AddXY(i, historial_mp25[uma_seleccionada, i]);
    SerieMP10.AddXY(i, historial_mp10[uma_seleccionada, i]);
  end;

  SerieBarras.Clear;
  for i := 0 to 5 do
  begin
    SerieBarras.AddXY(
      i,
      valores_histograma[uma_seleccionada, i],
      etiquetas_diametros[i],
      colores_barras[i]
    );
  end;

  LblTemperatura.Caption := IntToStr(ultima_temp[uma_seleccionada]);
  LblHumedad.Caption := IntToStr(ultima_hum[uma_seleccionada]);

  if ultima_trama[uma_seleccionada] <> '' then
    BarraEstado.Panels[1].Text := 'Data : ' + ultima_trama[uma_seleccionada]
  else if PuertoSerial.Active then
    BarraEstado.Panels[1].Text := 'Data : Esperando trama de UMA ' + IntToStr(uma_seleccionada) + '...';
end;

// Arma el objeto JSON y lo envia por POST al servidor Flask en el puerto 7070
procedure TFormPrincipal.EnviarDatosFlask(datos_trama: array of Integer);
var
  cliente_http: TFPHTTPClient;
  objeto_json: TJSONObject;
  flujo_cuerpo: TRawByteStringStream;
  texto_json: String;
begin
  // Armamos el JSON con los 12 datos de la estacion para enviarlo al servidor Flask
  objeto_json := TJSONObject.Create;
  try
    objeto_json.Add('id_uma', datos_trama[0]);
    objeto_json.Add('mp1_0', datos_trama[1]);
    objeto_json.Add('mp2_5', datos_trama[2]);
    objeto_json.Add('mp10', datos_trama[3]);
    objeto_json.Add('part_03', datos_trama[4]);
    objeto_json.Add('part_05', datos_trama[5]);
    objeto_json.Add('part_10', datos_trama[6]);
    objeto_json.Add('part_25', datos_trama[7]);
    objeto_json.Add('part_50', datos_trama[8]);
    objeto_json.Add('part_100', datos_trama[9]);
    objeto_json.Add('temperatura', datos_trama[10]);
    objeto_json.Add('humedad', datos_trama[11]);
    texto_json := objeto_json.AsJSON;
  finally
    objeto_json.Free;
  end;

  cliente_http := TFPHTTPClient.Create(nil);
  flujo_cuerpo := TRawByteStringStream.Create(texto_json);
  try
    try
      cliente_http.AddHeader('Content-Type', 'application/json');
      cliente_http.RequestBody := flujo_cuerpo;
      cliente_http.Post('http://127.0.0.1:7070/data');
    except
      on E: Exception do
      begin
        // Si Flask no esta encendido evitamos que la interfaz se caiga
        BarraEstado.Panels[1].Text := 'Data : ' + ultima_trama[uma_seleccionada] + ' (Flask desconectado)';
      end;
    end;
  finally
    flujo_cuerpo.Free;
    cliente_http.RequestBody := nil;
    cliente_http.Free;
  end;
end;

// Evento que se dispara cada vez que llegan datos por el puerto serial COM2
procedure TFormPrincipal.PuertoSerialRxData(Sender: TObject);
var
  texto_serial: String;
  lista_lineas: TStringList;
  elementos_linea: TStringList;
  linea_actual: String;
  datos_trama: array[0..11] of Integer;
  i, j, valor, uma_recibida: Integer;
  trama_valida: Boolean;
begin
  texto_serial := Trim(PuertoSerial.ReadData);
  if texto_serial = '' then
    Exit;

  lista_lineas := TStringList.Create;
  elementos_linea := TStringList.Create;
  try
    lista_lineas.Text := texto_serial;

    for i := 0 to lista_lineas.Count - 1 do
    begin
      linea_actual := Trim(lista_lineas[i]);
      if linea_actual = '' then
        Continue;

      elementos_linea.Clear;
      elementos_linea.StrictDelimiter := True;
      elementos_linea.Delimiter := ',';
      elementos_linea.DelimitedText := linea_actual;

      // Validamos que vengan los 12 valores enteros separados por coma
      if elementos_linea.Count = 12 then
      begin
        trama_valida := True;
        for j := 0 to 11 do
        begin
          if TryStrToInt(Trim(elementos_linea[j]), valor) then
            datos_trama[j] := valor
          else
          begin
            trama_valida := False;
            Break;
          end;
        end;

        uma_recibida := datos_trama[0];
        if trama_valida and (uma_recibida >= 1) and (uma_recibida <= 5) then
        begin
          // Si aun no tenia datos esta UMA, llenamos los puntos iniciales con su primera lectura
          // para que la curva no parta desde cero artificialmente
          if not tiene_datos[uma_recibida] then
          begin
            for j := 0 to 9 do
            begin
              historial_mp1[uma_recibida, j] := datos_trama[1];
              historial_mp25[uma_recibida, j] := datos_trama[2];
              historial_mp10[uma_recibida, j] := datos_trama[3];
            end;
            tiene_datos[uma_recibida] := True;
          end
          else
          begin
            // Desplazamos los datos anteriores una posicion a la izquierda (Scrolling Left)
            for j := 0 to 9 do
            begin
              historial_mp1[uma_recibida, j] := historial_mp1[uma_recibida, j + 1];
              historial_mp25[uma_recibida, j] := historial_mp25[uma_recibida, j + 1];
              historial_mp10[uma_recibida, j] := historial_mp10[uma_recibida, j + 1];
            end;
          end;

          // Colocamos los nuevos valores en la ultima posicion (muestra 10)
          historial_mp1[uma_recibida, 10] := datos_trama[1];
          historial_mp25[uma_recibida, 10] := datos_trama[2];
          historial_mp10[uma_recibida, 10] := datos_trama[3];

          // Guardamos el histograma, temperatura, humedad y texto de la trama de esta UMA
          for j := 0 to 5 do
            valores_histograma[uma_recibida, j] := datos_trama[4 + j];

          ultima_temp[uma_recibida] := datos_trama[10];
          ultima_hum[uma_recibida] := datos_trama[11];
          ultima_trama[uma_recibida] := linea_actual;

          // Si la casilla Enviar esta marcada, mandamos la trama al servidor Flask
          if ChkEnviarFlask.Checked then
            EnviarDatosFlask(datos_trama);

          // Si la trama recibida corresponde a la UMA que estamos viendo, actualizamos la pantalla
          if uma_recibida = uma_seleccionada then
            DibujarEstacionActual;
        end;
      end;
    end;
  finally
    elementos_linea.Free;
    lista_lineas.Free;
  end;
end;

// Guarda una captura en formato PNG del grafico de lineas sin congelar la ventana
procedure TFormPrincipal.BtnGuardarSeriesClick(Sender: TObject);
var
  carpeta_capturas: String;
  nombre_archivo: String;
begin
  carpeta_capturas := ExtractFilePath(ParamStr(0)) + 'capturas' + DirectorySeparator;
  ForceDirectories(carpeta_capturas);

  nombre_archivo := 'grafico_series_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.png';
  try
    GraficoSeries.SaveToFile(TPortableNetworkGraphic, carpeta_capturas + nombre_archivo);
    BarraEstado.Panels[1].Text := 'Captura guardada en: capturas\' + nombre_archivo;
  except
    on E: Exception do
      ShowMessage('Error al guardar la captura: ' + E.Message);
  end;
end;

// Guarda una captura en formato PNG del grafico de histograma sin congelar la ventana
procedure TFormPrincipal.BtnGuardarHistoClick(Sender: TObject);
var
  carpeta_capturas: String;
  nombre_archivo: String;
begin
  carpeta_capturas := ExtractFilePath(ParamStr(0)) + 'capturas' + DirectorySeparator;
  ForceDirectories(carpeta_capturas);

  nombre_archivo := 'grafico_histograma_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.png';
  try
    GraficoHistograma.SaveToFile(TPortableNetworkGraphic, carpeta_capturas + nombre_archivo);
    BarraEstado.Panels[1].Text := 'Captura guardada en: capturas\' + nombre_archivo;
  except
    on E: Exception do
      ShowMessage('Error al guardar la captura: ' + E.Message);
  end;
end;

// Boton para reiniciar las memorias y dejar ambos graficos en cero
procedure TFormPrincipal.BtnLimpiarClick(Sender: TObject);
begin
  InicializarMemorias;
  DibujarEstacionActual;
  BarraEstado.Panels[1].Text := 'Data : Historial de graficos reiniciado.';
end;

// Cierra la aplicacion asegurando el cierre del puerto serial
procedure TFormPrincipal.BtnSalirClick(Sender: TObject);
begin
  if PuertoSerial.Active then
    PuertoSerial.Close;
  Close;
end;

end.
