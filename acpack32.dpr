program acpack32;

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Windows, System.SysUtils, System.Classes;

{$SETPEFLAGS IMAGE_FILE_RELOCS_STRIPPED}

procedure unpack;
var
  FileStream1, FileStream2: TFileStream;
  StringList1: TStringList;
  MemoryStream1: TMemoryStream;
  StringBytes: TBytes;
  LongWord1, NumOfFiles, DataStart, DataEnd: LongWord;
  Int641: Int64;
  Byte1: Byte;
  i: Integer;
  s, OutDir: String;
begin
  FileStream1:=TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyWrite); MemoryStream1:=TMemoryStream.Create; StringList1:=TStringList.Create;
  try
    FileStream1.ReadBuffer(Int641,8);
    FileStream1.ReadBuffer(LongWord1,4);
    if (Int641<>$32334B4341504341) or (LongWord1<>$10000) then begin Writeln('Error: Input file is not a valid ACPACK32 archive file'); Readln; exit end;
    FileStream1.ReadBuffer(NumOfFiles,4);
    MemoryStream1.CopyFrom(FileStream1, NumOfFiles*$20);
    MemoryStream1.Position:=0;
    NumOfFiles:=NumOfFiles-1;

    OutDir:=ExpandFileName(ParamStr(1));
    OutDir:=Copy(OutDir,1,Length(OutDir)-Length(ExtractFileExt(OutDir)))+'\';
    if not (DirectoryExists(OutDir)) then CreateDir(OutDir);

    for i:=1 to NumOfFiles do
    begin
      SetLength(StringBytes,0);
      repeat
        MemoryStream1.ReadBuffer(Byte1,1);
        if not (Byte1=0) then
        begin
          SetLength(StringBytes, Length(StringBytes)+1);
          StringBytes[Length(StringBytes)-1]:=Byte1;
        end;
      until (Byte1=0);
      s:=TEncoding.GetEncoding(932).GetString(StringBytes);
      StringList1.Add(s);

      MemoryStream1.Position:=i*$20-4;
      MemoryStream1.ReadBuffer(DataStart,4);
      MemoryStream1.Position:=(i+1)*$20-4;
      MemoryStream1.ReadBuffer(DataEnd,4);
      MemoryStream1.Position:=i*$20;

      FileStream1.Position:=DataStart;
      FileStream2:=TFileStream.Create(OutDir+s, fmCreate or fmOpenWrite or fmShareDenyWrite);
      try
        FileStream2.CopyFrom(FileStream1, DataEnd-DataStart);
      finally FileStream2.Free end;
      Writeln('[',StringOfChar('0',Length(IntToStr(NumOfFiles))-Length(IntToStr(i)))+IntToStr(i)+'/'+IntToStr(NumOfFiles)+'] '+s);
    end;
    StringList1.SaveToFile(OutDir+'acpack32_filelist.txt', TEncoding.UTF8);
  finally FileStream1.Free; MemoryStream1.Free; StringList1.Free end;
end;

procedure pack;
const
  ZeroByte: Byte=0;
type
  ShiftjisString = type AnsiString(932);
var
  StringList1: TStringList;
  FileStream1, FileStream2: TFileStream;
  MemoryStream1: TMemoryStream;
  LongWord1, DataNameLength: LongWord;
  i,x: Integer;
  InputDir: String;
  DataNameSJIS: ShiftjisString;
begin
  InputDir:=ExpandFileName(ParamStr(1));
  repeat if InputDir[Length(InputDir)]='\' then SetLength(InputDir, Length(InputDir)-1) until not (InputDir[Length(InputDir)]='\');
  if not (FileExists(InputDir+'\acpack32_filelist.txt')) then begin Writeln('Error: '+#39+'acpack32_filelist.txt'+#39+' not found in selected directory'); Readln; exit end;
  StringList1:=TStringList.Create;
  try
    StringList1.LoadFromFile(InputDir+'\acpack32_filelist.txt');
    if StringList1.Count=0 then begin Writeln('Error: '+#39+'acpack32_filelist.txt'+#39+' is empty'); Readln; exit end;

    FileStream1:=TFileStream.Create(InputDir+'.PAK', fmCreate or fmOpenWrite or fmShareDenyWrite); MemoryStream1:=TMemoryStream.Create;
    try
      LongWord1:=$41504341;
      FileStream1.WriteBuffer(LongWord1,4);
      LongWord1:=$32334B43;
      FileStream1.WriteBuffer(LongWord1,4);
      LongWord1:=$10000;
      FileStream1.WriteBuffer(LongWord1,4);
      LongWord1:=StringList1.Count+1;
      FileStream1.WriteBuffer(LongWord1,4);
      FileStream1.Size:=LongWord1*$20+$10;

      for i:=0 to StringList1.Count-1 do
      begin
        DataNameSJIS:=ShiftjisString(StringList1[i]);
        DataNameLength:=Length(DataNameSJIS);
        if DataNameLength>$27 then begin Writeln('Error: '+#39+StringList1[i]+#39+' file name is too long ('+IntToStr(DataNameLength)+'/27)'); Readln; exit end;
        MemoryStream1.WriteBuffer(DataNameSJIS[1], DataNameLength);
        for x:=1 to 28-DataNameLength do MemoryStream1.WriteBuffer(ZeroByte,1);
        LongWord1:=FileStream1.Position;
        MemoryStream1.WriteBuffer(LongWord1,4);
        FileStream2:=TFileStream.Create(InputDir+'\'+StringList1[i], fmOpenRead or fmShareDenyWrite);
        try
          FileStream1.CopyFrom(FileStream2,FileStream2.Size);
        finally FileStream2.Free end;
        Writeln('[',StringOfChar('0',Length(IntToStr(StringList1.Count))-Length(IntToStr(i+1)))+IntToStr(i+1)+'/'+IntToStr(StringList1.Count)+'] '+StringList1[i]);
      end;
      for i:=1 to 28 do MemoryStream1.WriteBuffer(ZeroByte,1);
      LongWord1:=FileStream1.Size;
      MemoryStream1.WriteBuffer(LongWord1,4);

      MemoryStream1.Position:=0;
      FileStream1.Position:=$10;
      FileStream1.CopyFrom(MemoryStream1, MemoryStream1.Size);
    finally FileStream1.Free; MemoryStream1.Free end;
  finally StringList1.Free end;
end;

begin
  try
    Writeln('くるりアクティブ ACPACK32 Unpacker/Packer v1.0 by RikuKH3');
    Writeln('---------------------------------------------------------');
    if ParamCount=0 then begin Writeln('Usage: acpack32.exe <input file or folder>'); Readln; exit end;
    if Pos('.', ExtractFileName(ParamStr(1)))=0 then pack else unpack;
  except on E: Exception do begin Writeln('Error: '+E.Message); Readln; exit end end;
end.
