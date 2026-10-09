"""Fail-closed filesystem and dispatch boundaries. No eval, exec or Python tool."""
from __future__ import annotations
import json
import math
import os
from pathlib import Path, PureWindowsPath

class SafetyError(ValueError): pass
class Cancelled(Exception): pass

class AllowedPaths:
    def __init__(self, roots):
        self.roots = [Path(p).expanduser().resolve(strict=True) for p in roots if p]
        if any(not p.is_dir() for p in self.roots): raise SafetyError('Approved roots must exist and be directories')

    def resolve(self, value, write=False, overwrite=False, extension=None):
        if not isinstance(value,str) or not value or '\x00' in value: raise SafetyError('Invalid path')
        normalized=value.replace('\\','/')
        if '..' in normalized.split('/') or value.startswith(('\\\\','//')): raise SafetyError('Path traversal and network shares are denied')
        if os.name=='nt' and ':' in value[2:]: raise SafetyError('Alternate data streams are denied')
        if os.name!='nt' and (PureWindowsPath(value).drive or '\\' in value): raise SafetyError('Foreign Windows path is denied')
        p=Path(value).expanduser()
        if not self.roots: raise SafetyError('Configure an approved directory in PRIME addon preferences first')
        if not p.is_absolute(): p=self.roots[0]/p
        p=p.resolve(strict=not write)
        if not any(p.is_relative_to(root) for root in self.roots): raise SafetyError('Path is outside approved directories')
        if extension and p.suffix.lower() not in extension: raise SafetyError('Unexpected file extension')
        if write:
            if p.exists() and not overwrite: raise SafetyError('File exists; overwrite=true is required')
            parent=p.parent.resolve(strict=True)
            if not any(parent.is_relative_to(root) for root in self.roots): raise SafetyError('Parent directory is outside approved roots')
        elif not p.is_file(): raise SafetyError('Expected a file')
        return p

    def directory(self,value,create=False):
        if not isinstance(value,str) or '..' in value.replace('\\','/').split('/') or '\x00' in value: raise SafetyError('Invalid directory')
        p=Path(value).expanduser()
        if not p.is_absolute(): p=self.roots[0]/p if self.roots else p
        p=p.resolve()
        if not self.roots or not any(p.is_relative_to(r) for r in self.roots): raise SafetyError('Directory outside approved roots')
        if create: p.mkdir(parents=True,exist_ok=True)
        if not p.is_dir(): raise SafetyError('Directory does not exist')
        return p

def validate(schema,value,path='arguments'):
    t=schema.get('type')
    if t=='object':
        if not isinstance(value,dict): raise SafetyError(path+' must be an object')
        for key in schema.get('required',[]):
            if key not in value: raise SafetyError(path+'.'+key+' is required')
        for key,v in value.items():
            if key not in schema.get('properties',{}):
                if not schema.get('additionalProperties',True): raise SafetyError(path+'.'+key+' is not permitted')
            else: validate(schema['properties'][key],v,path+'.'+key)
    elif t=='array':
        if not isinstance(value,list) or len(value)<schema.get('minItems',0) or len(value)>schema.get('maxItems',500): raise SafetyError(path+' invalid length')
        for v in value: validate(schema['items'],v,path+'[]')
    elif t=='string':
        if not isinstance(value,str) or len(value)<schema.get('minLength',0) or len(value)>schema.get('maxLength',1024): raise SafetyError(path+' invalid string')
    elif t in ('number','integer'):
        if isinstance(value,bool) or not isinstance(value,(float,int)) or not math.isfinite(value) or (t=='integer' and not isinstance(value,int)) or value<schema.get('minimum',-math.inf) or value>schema.get('maximum',math.inf): raise SafetyError(path+' out of range')
    elif t=='boolean' and not isinstance(value,bool): raise SafetyError(path+' must be boolean')
    if 'enum' in schema and value not in schema['enum']: raise SafetyError(path+' invalid option')

def contracts():
    return {t['name']:t for t in json.loads(Path(__file__).with_name('catalog.json').read_text(encoding='utf-8'))}
