"""Fetch only needed members of the official Godot export template ZIP via HTTP ranges."""
import io
import os
from pathlib import Path
import urllib.request
import zipfile

URL='https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz'
SIZE=1255918323
DEST=Path(os.environ['APPDATA'])/'Godot/export_templates/4.6.3.stable'
DEST.mkdir(parents=True,exist_ok=True)

class RemoteZip(io.RawIOBase):
    def __init__(self):self.pos=0;self.url=URL
    def seekable(self):return True
    def readable(self):return True
    def tell(self):return self.pos
    def seek(self,offset,whence=0):
        self.pos=offset if whence==0 else self.pos+offset if whence==1 else SIZE+offset
        return self.pos
    def read(self,count=-1):
        if count<0:count=SIZE-self.pos
        count=min(count,SIZE-self.pos)
        if count<=0:return b''
        req=urllib.request.Request(self.url,headers={'Range':f'bytes={self.pos}-{self.pos+count-1}','User-Agent':'Godot-sample-setup'})
        with urllib.request.urlopen(req,timeout=120) as response:
            if response.status!=206:raise RuntimeError('Server did not support partial download; no full archive downloaded')
            self.url=response.url
            data=response.read()
        if len(data)!=count:raise RuntimeError(f'Partial download length mismatch: {len(data)} != {count}')
        self.pos+=len(data)
        return data

with zipfile.ZipFile(RemoteZip()) as archive:
    names=archive.namelist()
    print('AVAILABLE',','.join(n for n in names if 'web_' in n or 'windows_release_x86_64' in n),flush=True)
    for name in names:
        basename=Path(name).name
        if basename in {'web_release.zip','web_debug.zip','web_nothreads_release.zip','web_nothreads_debug.zip','windows_release_x86_64.exe','version.txt'}:
            output=DEST/basename
            if output.exists() and output.stat().st_size==archive.getinfo(name).file_size:continue
            print('FETCH',name,archive.getinfo(name).file_size,flush=True)
            data=archive.read(name)
            output.write_bytes(data)
            print('SAVED',output,len(data),flush=True)
