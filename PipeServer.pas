unit PipeServer;

interface
uses
  Classes, Windows, System.Generics.Collections,
  PipeServerInstance;

const
  PIPE_FORMAT = '\\%s\pipe\%s'; // \\ServerName\pipe\PipeName
  PIPE_TIMEOUT = 5000;
  BUFSIZE = 10000;

type

// Named pipe server
  TPipeServer = class
  private
    fPipeName: String;
    fInstances: TObjectList<TPipeServerInstance>;
    procedure Log(aLog: String);
  public
    constructor Create(aServerAddress, aPipeName: String);
    destructor Destroy; override;

    function SearchForClient(aClientID: Byte): Boolean;
    procedure TerminateInstances();
  end;

implementation

uses
  SysUtils;


{ TPipeServer }
constructor TPipeServer.Create(aServerAddress, aPipeName: String);
begin
  inherited Create;
  fInstances := TObjectList<TPipeServerInstance>.Create();
  // Create pipe path
  if (aServerAddress = '') then // Default case
    fPipeName := Format(PIPE_FORMAT, ['.', aPipeName])
  else
    fPipeName := Format(PIPE_FORMAT, [aServerAddress, aPipeName]);
  Log('  TPipeServer: name = '+fPipeName);
end;


destructor TPipeServer.Destroy;
begin
  FreeAndNil(fInstances);
  Log('  TPipeServer: termination of '+fPipeName);
  inherited Destroy;
end;


procedure TPipeServer.Log(aLog: String);
begin
  Writeln(aLog);
end;


function TPipeServer.SearchForClient(aClientID: Byte): Boolean;
var
  Handle: THandle;
begin
  Result := False;
  // Check whether pipe does exist
  if WaitNamedPipe(PChar(fPipeName), 100) then // 100 [ms]
    raise Exception.Create('Pipe exists.');
  // Create the pipe
  Handle := CreateNamedPipe(
    PChar(fPipeName),                                   // Pipe name
    PIPE_ACCESS_DUPLEX,                                 // Read/write access
    PIPE_TYPE_BYTE OR PIPE_READMODE_BYTE OR PIPE_WAIT,  // Message-type pipe; message read mode OR blocking mode //PIPE_NOWAIT
    PIPE_UNLIMITED_INSTANCES,                           // Unlimited instances
    BUFSIZE,                                            // Output buffer size
    BUFSIZE,                                            // Input buffer size
    0,                                                  // Client time-out 50 [ms] default
    nil                                                 // Default security attributes
  );

  // Check if pipe was created
  if Handle = INVALID_HANDLE_VALUE then
    raise Exception.Create('Could not create PIPE - invalid handle');
  Sleep(100);
  // Check if new client is connected
  if not ConnectNamedPipe(Handle, nil) AND (GetLastError() = ERROR_PIPE_CONNECTED) then
  begin
    Log('  TPipeServer: Client connected, create instance');
    fInstances.Add( TPipeServerInstance.Create(aClientID, Handle,fPipeName) );
    Result := True;
  end
  else
  begin
    Log('  TPipeServer: Connection failed, error = '+IntToStr(GetLastError()));

    CloseHandle(Handle);
  end;
end;



procedure TPipeServer.TerminateInstances();
var
  K: Integer;
begin
  for K := 0 to fInstances.Count - 1 do
    if (fInstances[K] <> nil) then
      fInstances[K].InstanceState := isTerminate;
end;



end.
