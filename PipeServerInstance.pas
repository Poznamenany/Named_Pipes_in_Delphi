unit PipeServerInstance;

interface
uses
  Classes, Windows;

const
  SHUT_DOWN_MSG = 'shutdown pipe ';
  PIPE_FORMAT = '\\%s\pipe\%s'; // \\ServerName\pipe\PipeName
  PIPE_TIMEOUT = 5000;
  BUFF_SIZE = 8095;

type
  TInstanceState = (isRun, isTerminate);

  RPIPEMessage = record
    Size: DWORD;
    Kind: Byte;
    Count: DWORD;
    Data: array[0..BUFF_SIZE+5] of Byte;
  end;

// Named pipe server (instance)
  TPipeServerInstance = class(TThread)
  private
    fID: Byte;
    fHandle: THandle;
    fPipeName: String;
    procedure SendMessage();
    procedure ReadMessage();
    procedure Log(aLog: String);
  protected
    procedure Execute(); override;
  public
    InstanceState: TInstanceState;

    constructor Create(aID: Byte; aPipeHandle: THandle; aPipeName: String);
    destructor Destroy; override;

    procedure ShutDownServer();
  end;

implementation

uses
  SysUtils;


{ TPipeServerInstance }
constructor TPipeServerInstance.Create(aID: Byte; aPipeHandle: THandle; aPipeName: String);
begin
  inherited Create();
  FreeOnTerminate := False;
  Priority := tpLower;
  fID := aID;
  fHandle := aPipeHandle;
  fPipeName := aPipeName;
  InstanceState := isRun;
  Log('Constructor - Pipe name: ' + fPipeName);
end;


destructor TPipeServerInstance.Destroy;
begin
  if (fHandle <> INVALID_HANDLE_VALUE) then
    ShutDownServer;
  Log('Destructor');
  inherited Destroy;
end;


procedure TPipeServerInstance.Log(aLog: String);
begin
  Writeln('    TPipeServerInstance[' + IntToStr(fID) + ']: ' + aLog);
end;


procedure TPipeServerInstance.Execute();
var
  NewMessage: Boolean;
  Written: Cardinal;
  InMsg, OutMsg: RPIPEMessage;
begin

  Log('Execute - start');
  while (InstanceState <> isTerminate) AND (fHandle <> INVALID_HANDLE_VALUE) do
    begin
      ReadMessage();
      if (InstanceState = isTerminate) then // Client send request to terminate connection (for now)
        break;
      SendMessage();
    end;
  InstanceState := isTerminate;
  Log('Execute - end');
end;


procedure TPipeServerInstance.SendMessage();
var
  SendMessage: Boolean;
  Bytes: Cardinal;
  Msg: RPIPEMessage;
begin
  // Prepare outgoing message
  Msg.Kind := 1;
  Msg.Count := 2;
  Msg.Data[0] := 3;
  Msg.Data[1] := 4;
  Msg.Size := SizeOf(Msg.Size) + SizeOf(Msg.Kind) + SizeOf(Msg.Count) + Msg.Count + 3;

  // Send message
  Log('Sent message');
  SendMessage := WriteFile(
    fHandle,   // pipe handle
    Msg,       // message
    Msg.Size,  // message length
    Bytes,     // bytes written
    nil
  );

  if not SendMessage then
    Log('Message cound not be send');
end;

procedure TPipeServerInstance.ReadMessage();
var
  MessageReceived: Boolean;
  Msg: RPIPEMessage;
begin
  MessageReceived := ReadFile(
    fHandle,   // pipe handle
    Msg,       // buffer to receive reply
    BUFF_SIZE, // size of buffer
    Msg.Size,  // number of bytes read
    nil);      // not overlapped
  if MessageReceived then
  begin
    Log('Received message: size = ' + IntToStr(Msg.Size) + '; data[0] = ' + IntToStr(Msg.Data[0]));
    if (Msg.Kind = 10) then
      InstanceState := isTerminate;
  end;
end;


procedure TPipeServerInstance.ShutDownServer();
var
  BytesRead: Cardinal;
  OutMsg, InMsg: RPIPEMessage;
  ShutDownMsg: String;
begin
  if (fHandle <> INVALID_HANDLE_VALUE) then
  begin
    // Server still has pipe opened
    DisconnectNamedPipe(fHandle);
    // Close pipe on server
    CloseHandle(fHandle);
    // Clear handle
    fHandle := INVALID_HANDLE_VALUE;
    Log('Shut down server: ' + fPipeName);
  end;
end;


end.
