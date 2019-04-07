program NamedPipe;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  PipeServer in 'PipeServer.pas',
  PipeServerInstance in 'PipeServerInstance.pas',
  PipeClient in 'PipeClient.pas';

const
  SERVER_PATH = ''; // Empty for local server
  SERVER_NAME = 'KP_TestServer'; // Server name
  NL = {$IFDEF LINUX} AnsiChar(#10) {$ENDIF}
       {$IFDEF MSWINDOWS} AnsiString(#13#10) {$ENDIF}; // New line in command window
var
  Client1,Client2: TPipeClient;
  Server: TPipeServer;
  K: Integer;
begin

  // Create server (after program init; main class)
  try
    Writeln('Load app, create Pipe server: ');
    Server := TPipeServer.Create(SERVER_PATH, SERVER_NAME);
  except
    on E: Exception do
    begin
      Writeln(E.Message);
    end;
  end;

  // This loop represents life of KP program
  for K := 0 to 300 do
  begin

    // 1. game mission (just few ticks to simulate multiple game during 1 app run)
    //{
    if (K = 99) then // Mission is loaded in this tick
    begin
      Writeln(NL + 'Create Pipe client (ExtAI of game 1): ');
      Client1 := TPipeClient.Create(1, SERVER_PATH, SERVER_NAME);
      Writeln(NL + 'Search for client:');
      Server.SearchForClient(1);
    end;
    if (K > 100) AND (K < 105) then // Mission is running in these ticks
    begin
      if (K = 101) then
        Writeln(NL + 'Start mission:');
      Sleep(10); // Do some calculation
    end;
    if (K = 105) then // Mission is terminated in this tick
    begin
      Writeln(NL + 'End mission:');
      Client1.SimState := stTerminate;
      Server.TerminateInstances();
    end;
    //}


    // 2. game mission (2 Clients)
    {
    if (K = 199) then // Mission is loaded in this tick
    begin
      Writeln(NL + 'Create Pipe client 1: ');
      Client1 := TPipeClient.Create(1, SERVER_PATH, SERVER_NAME);
      Writeln(NL + 'Search for client 1:');
      Server.SearchForClient(1);
      Sleep(10); // Let threads to create connection
      Writeln(NL + 'Create Pipe client 2: ');
      Client2 := TPipeClient.Create(2, SERVER_PATH, SERVER_NAME);
      Writeln(NL + 'Search for client 2:');
      Server.SearchForClient(2);
    end;
    if (K > 200) AND (K < 203) then // Mission is running in these ticks
    begin
      if (K = 201) then
        Writeln(NL + 'Start mission:');
      Sleep(10); // Do some calculation
    end;
    if (K = 204) then // Mission is terminated in this tick
    begin
      Writeln(NL + 'End mission:');
      Client1.SimState := stTerminate;
      Client2.SimState := stTerminate;
      Server.TerminateInstances();
    end;
    //}

    Sleep(1); // Do other calculations
  end;
  Server.Free; // Game (KP) was closed

  Writeln('Terminate app');
  ReadLn;
end.

