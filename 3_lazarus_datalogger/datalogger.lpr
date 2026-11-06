program datalogger;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces,
  Forms, main, tachartlazaruspkg, LazSerialPort;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title := 'DataLogger - Monitoreo Ambiental';
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TFormPrincipal, FormPrincipal);
  Application.Run;
end.
