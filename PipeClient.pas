unit PipeClient;

interface
uses
  Classes, Windows,
  System.Threading, System.Diagnostics, System.SysUtils;

const
  SHUT_DOWN_MSG = 'shutdown pipe ';
  PIPE_FORMAT = '\\%s\pipe\%s'; // \\ServerName\pipe\PipeName
  PIPE_TIMEOUT = 5000;
  BUFF_SIZE = 8095;

type
  TSimState = (stRun, stTerminate);

  RPIPEMessage = record
    Size: DWORD;
    Kind: Byte;
    Count: DWORD;
    Data: array[0..BUFF_SIZE+5] of Byte;
  end;

// Named pipe client (separate process in Matlab / python / etc.)
  TPipeClient = class(TThread)
  private
    fID: Byte;
    fPipeName: String;
    fHandle: THandle;
    function TryConnectToServer(): Boolean;
    procedure SendMessage(aKind: Byte);
    procedure ReadMessage();
    procedure Log(aLog: String);
  protected
    procedure Execute(); override;
  public
    SimState: TSimState;
    constructor Create(aID: Byte; aServer, aPipe: String);
    destructor Destroy(); override;

  end;

implementation



{ TPipeClient }
constructor TPipeClient.Create(aID: Byte; aServer, aPipe: String);
begin
  inherited Create();
  FreeOnTerminate := True;
  Priority := tpLower;
  SimState := stRun;
  fID := aID;
  fHandle := INVALID_HANDLE_VALUE;
  if aServer = '' then
    fPipeName := Format(PIPE_FORMAT, ['.', aPipe])
  else
    fPipeName := Format(PIPE_FORMAT, [aServer, aPipe]);
  Log('Constructor - Pipe name: ' + fPipeName);
end;

destructor TPipeClient.Destroy();
begin
  if (fHandle <> INVALID_HANDLE_VALUE) then
    CloseHandle(fHandle);
  Log('Destructor');
  inherited Destroy();
end;


procedure TPipeClient.Log(aLog: String);
begin
  Writeln('  TPipeClient[' + IntToStr(fID) + ']: ' + aLog);
end;


function TPipeClient.TryConnectToServer(): Boolean;
begin
  Result := False;
  fHandle := CreateFile(
    PChar(fPipeName),      // pipe name
    GENERIC_READ OR GENERIC_WRITE, // read and write access
    0,              // no sharing
    nil,            // default security attributes
    OPEN_EXISTING,  // opens existing pipe
    0,              // default attributes
    0
  );
  // If handle is not valid
  if (fHandle = INVALID_HANDLE_VALUE) then
  begin
    // Exit if an error other than ERROR_PIPE_BUSY occurs
    if (GetLastError() <> ERROR_PIPE_BUSY) then
    begin
      Log('Cound not open pipe');
      Exit;
    end;
    // All pipe instances are busy, so wait for 1 seconds
    if not WaitNamedPipe(PChar(fPipeName), 1000) then
    begin
      Log('Could not open pipe for 1 sec');
    end;
  end;
  Result := (fHandle <> INVALID_HANDLE_VALUE);
end;


procedure TPipeClient.Execute();
var
  K: Integer;
begin
  Log('Execute - start');
  while (SimState <> stTerminate) do
  begin
    if (fHandle <> INVALID_HANDLE_VALUE) OR TryConnectToServer() then
    begin
      SendMessage(1);
      ReadMessage();
    end;
    Sleep(20);
  end;
  if (fHandle <> INVALID_HANDLE_VALUE) then
    SendMessage(10);
  Log('Execute - end');
end;


procedure TPipeClient.SendMessage(aKind: Byte);
var
  SendMessage: Boolean;
  Bytes: Cardinal;
  Msg: RPIPEMessage;
begin
  // Prepare outgoing message
  Msg.Kind := aKind;
  Msg.Count := 3;
  Msg.Data[0] := 10;
  Msg.Data[1] := 9;
  Msg.Data[2] := 8;
  Msg.Size := SizeOf(Msg.Size) + SizeOf(Msg.Kind) + SizeOf(Msg.Count) + Msg.Count + 3;

  // Send message
  Log('Sent message');
  SendMessage := WriteFile(
    fHandle,    // pipe handle
    Msg,        // message
    Msg.Size,   // message length
    Bytes,      // bytes written
    nil
  );

  if not SendMessage then
    Log('Message cound not be send');
end;

procedure TPipeClient.ReadMessage();
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
  end;
end;


end.
