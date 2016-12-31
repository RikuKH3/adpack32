program adpack32;

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
  LongWord1, LongWord2, NumOfFiles, DataStart, DataEnd: LongWord;
  Word1: Word;
  Byte1: Byte;
  adpack32flag: Boolean;
  i: Integer;
  s, OutDir: String;
begin
  FileStream1:=TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyWrite); MemoryStream1:=TMemoryStream.Create; StringList1:=TStringList.Create;
  try
    FileStream1.ReadBuffer(LongWord1,4);
    if LongWord1=$41504441 then begin StringList1.Add('[ADPACK32]'); adpack32flag:=True end else begin StringList1.Add('[ACPACK32]'); adpack32flag:=False end;
    FileStream1.ReadBuffer(LongWord1,4);
    FileStream1.ReadBuffer(LongWord2,4);
    if (LongWord1<>$32334B43) or (LongWord2<>$10000) then begin Writeln('Error: Input file is not a valid ACPACK32/ADPACK32 archive file'); Readln; exit end;
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

      if adpack32flag=True then
      begin
        MemoryStream1.Position:=i*$20-6;
        MemoryStream1.ReadBuffer(Word1,2);
        StringList1.Add(s+','+IntToStr(Word1));
        MemoryStream1.ReadBuffer(DataStart,4);
      end else
      begin
        MemoryStream1.Position:=i*$20-4;
        StringList1.Add(s);
        MemoryStream1.ReadBuffer(DataStart,4);
      end;
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
    StringList1.SaveToFile(OutDir+'kururi_filelist.txt', TEncoding.UTF8);
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
  i,x,y: Integer;
  InputDir, InputFile, s: String;
  Word1: Word;
  adpack32flag: Byte;
  DataNameSJIS: ShiftjisString;
begin
  InputDir:=ExpandFileName(ParamStr(1));
  repeat if InputDir[Length(InputDir)]='\' then SetLength(InputDir, Length(InputDir)-1) until not (InputDir[Length(InputDir)]='\');
  if not (FileExists(InputDir+'\kururi_filelist.txt')) then begin Writeln('Error: '+#39+'kururi_filelist.txt'+#39+' not found in selected directory'); Readln; exit end;
  StringList1:=TStringList.Create;
  try
    StringList1.LoadFromFile(InputDir+'\kururi_filelist.txt');
    if StringList1.Count=0 then begin Writeln('Error: '+#39+'kururi_filelist.txt'+#39+' is empty'); Readln; exit end;
    s:=UpperCase(StringList1[0]);
    if (s='[ACPACK32]') or (s='[ADPACK32]') then StringList1.Delete(0);
    FileStream1:=TFileStream.Create(InputDir+'.PAK', fmCreate or fmOpenWrite or fmShareDenyWrite); MemoryStream1:=TMemoryStream.Create;
    try
      if s='[ADPACK32]' then LongWord1:=$41504441 else LongWord1:=$41504341;
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
        y:=Pos(',',StringList1[i]);
        if y>0 then begin InputFile:=Copy(StringList1[i],1,y-1); DataNameSJIS:=ShiftjisString(InputFile); adpack32flag:=2 end else begin InputFile:=StringList1[i]; DataNameSJIS:=ShiftjisString(InputFile); adpack32flag:=0 end;
        DataNameLength:=Length(DataNameSJIS);
        if DataNameLength>LongWord(27-adpack32flag) then begin Writeln('Error: '+#39+StringList1[i]+#39+' file name is too long ('+IntToStr(DataNameLength)+'/'+IntToStr(27-adpack32flag)+')'); Readln; exit end;
        MemoryStream1.WriteBuffer(DataNameSJIS[1], DataNameLength);
        for x:=1 to 28-DataNameLength-adpack32flag do MemoryStream1.WriteBuffer(ZeroByte,1);
        if adpack32flag=2 then begin Word1:=StrToInt(Copy(StringList1[i],y+1)); MemoryStream1.WriteBuffer(Word1,2) end;
        LongWord1:=FileStream1.Position;
        MemoryStream1.WriteBuffer(LongWord1,4);
        FileStream2:=TFileStream.Create(InputDir+'\'+InputFile, fmOpenRead or fmShareDenyWrite);
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
    Writeln('くるりアクティブ ADPACK32 Unpacker/Packer v1.1 by RikuKH3');
    Writeln('---------------------------------------------------------');
    if ParamCount=0 then begin Writeln('Usage: adpack32.exe <input file or folder>'); Readln; exit end;
    if Pos('.', ExtractFileName(ParamStr(1)))=0 then pack else unpack;
  except on E: Exception do begin Writeln('Error: '+E.Message); Readln; exit end end;
end.
