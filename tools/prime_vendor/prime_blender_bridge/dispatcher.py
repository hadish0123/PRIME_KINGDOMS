from __future__ import annotations
import base64
from collections import deque
from datetime import datetime, timezone
import json
from pathlib import Path
import threading
import uuid
import bpy
from .safety import AllowedPaths, SafetyError, Cancelled, contracts, validate

SYSTEM_TOOLS={'list_devices','pair_blender','pair_device','unpair_device','select_device','device_status','get_job_status','cancel_job'}

class Dispatcher:
    def __init__(self,roots):
        self.paths=AllowedPaths(roots);self.contracts=contracts();self.logs=deque(maxlen=200);self.cancel_event=None;self.progress=lambda _:None
        from .operations import Operations
        from .pipeline import Pipeline
        from .prime import PrimeAssets
        self.ops=Operations(self);self.pipeline=Pipeline(self);self.prime=PrimeAssets(self)
        self.handlers={}
        for section in (self.ops,self.pipeline,self.prime):self.handlers.update(section.handlers())
        missing=set(self.contracts)-SYSTEM_TOOLS-set(self.handlers)
        if missing:raise RuntimeError('Missing real Blender handlers: '+', '.join(sorted(missing)))
    def checkpoint(self,value=None):
        if self.cancel_event and self.cancel_event.is_set():raise Cancelled()
        if value is not None:self.progress(value)
    def log(self,message):self.logs.append({'time':datetime.now(timezone.utc).isoformat(),'message':str(message)[:4096]})
    def snapshot(self):
        if not self.paths.roots:raise SafetyError('Destructive jobs require an approved directory for snapshots')
        folder=self.paths.directory(str(self.paths.roots[0]/'.prime-snapshots'),create=True)
        name=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S')+'-'+uuid.uuid4().hex[:8]+'.blend'
        output=self.paths.resolve(str(folder/name),write=True,extension={'.blend'})
        result=bpy.ops.wm.save_as_mainfile(filepath=str(output),copy=True,check_existing=False)
        if 'FINISHED' not in result:raise RuntimeError('Snapshot could not be saved; mutation was blocked')
        return str(output)
    def artifact(self,path,mime):
        p=self.paths.resolve(str(path));size=p.stat().st_size
        if size>32*1024*1024:raise SafetyError('Artifact is larger than the 32 MiB transfer limit; export remains available locally')
        return {'filename':p.name,'mime':mime,'data':base64.b64encode(p.read_bytes()).decode()}
    def execute(self,tool,args,cancel_event=None,progress=None):
        if threading.current_thread() is not threading.main_thread():raise RuntimeError('bpy must execute on Blender main thread')
        if tool not in self.handlers:raise SafetyError('Tool is not in the fixed allowlist')
        definition=self.contracts[tool];validate(definition['inputSchema'],args)
        self.cancel_event=cancel_event;self.progress=progress or (lambda _:None);self.checkpoint(0)
        self.log('Started '+tool)
        if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
        snapshot=None
        if definition['annotations']['destructiveHint']:
            if args.get('confirm') is not True:raise SafetyError('This operation requires confirm=true')
            snapshot=self.snapshot()
        result=self.handlers[tool](args)
        self.checkpoint(1)
        if not isinstance(result,dict):result={'result':result}
        if snapshot:result['snapshot']=snapshot
        self.log('Completed '+tool)
        json.dumps(result,allow_nan=False)
        if not bpy.app.background and not definition['annotations']['readOnlyHint'] and tool not in {'undo','redo'}:
            bpy.ops.ed.undo_push(message='PRIME '+tool)
        return result
