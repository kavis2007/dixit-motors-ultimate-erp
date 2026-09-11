import os, json
from datetime import datetime, timezone
from typing import Any
from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import create_engine, String, Text, DateTime
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, Session
from dotenv import load_dotenv

load_dotenv()
SYNC_KEY=os.getenv('DIXIT_SYNC_KEY','CHANGE_THIS_TO_A_LONG_RANDOM_KEY')
DB_URL=os.getenv('DIXIT_DATABASE_URL','sqlite:///./dixit_ultimate.db')
connect_args={'check_same_thread':False} if DB_URL.startswith('sqlite') else {}
engine=create_engine(DB_URL, connect_args=connect_args)

class Base(DeclarativeBase): pass
class DeviceRecord(Base):
    __tablename__='devices'
    device_id: Mapped[str]=mapped_column(String(160),primary_key=True)
    device_name: Mapped[str]=mapped_column(String(160))
    user_name: Mapped[str]=mapped_column(String(160),default='Dixit User')
    status: Mapped[str]=mapped_column(String(32),default='active',index=True)
    last_seen: Mapped[datetime]=mapped_column(DateTime(timezone=True),index=True)
    created_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=lambda: datetime.now(timezone.utc))

class SyncRecord(Base):
    __tablename__='sync_records'
    id: Mapped[str]=mapped_column(String(160),primary_key=True)
    module: Mapped[str]=mapped_column(String(80),index=True)
    updated_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),index=True)
    data: Mapped[str]=mapped_column(Text)
    deleted: Mapped[int]=mapped_column(default=0)
Base.metadata.create_all(engine)

# Safe startup migration for the already-created Render PostgreSQL devices table.
# Existing records/data are preserved; only missing columns are added.
if not DB_URL.startswith('sqlite'):
    from sqlalchemy import text, inspect
    existing = {c['name'] for c in inspect(engine).get_columns('devices')}
    for col, definition in [
        ('user_name', "VARCHAR(160) DEFAULT 'Dixit User'"),
        ('status', "VARCHAR(32) DEFAULT 'active'"),
        ('created_at', "TIMESTAMP WITH TIME ZONE"),
    ]:
        if col not in existing:
            with engine.begin() as conn:
                conn.execute(text(f"ALTER TABLE devices ADD COLUMN {col} {definition}"))
    with engine.begin() as conn:
        conn.execute(text("UPDATE devices SET status='active' WHERE status IS NULL"))
        conn.execute(text("UPDATE devices SET user_name='Dixit User' WHERE user_name IS NULL"))
        conn.execute(text("UPDATE devices SET created_at=last_seen WHERE created_at IS NULL"))


app=FastAPI(title='Dixit Motors Management App API',version='1.0.0')
app.add_middleware(CORSMiddleware,allow_origins=['*'],allow_credentials=True,allow_methods=['*'],allow_headers=['*'])

class SyncItem(BaseModel):
    module: str
    id: str
    updated_at: str
    data: dict[str,Any]=Field(default_factory=dict)
    deleted: bool=False
class PushBody(BaseModel):
    records: list[SyncItem]=Field(default_factory=list)
    device_id: str|None=None

@app.get('/')
def root(): return {'service':'Dixit Motors Management App','ok':True}
@app.get('/health')
def health(): return {'ok':True,'service':'Dixit Motors Management App','server_time':datetime.now(timezone.utc).isoformat()}

class DeviceRegister(BaseModel):
    device_id: str
    device_name: str
    user_name: str = 'Dixit User'

@app.post('/api/devices/register')
def device_register(body: DeviceRegister, x_sync_key: str|None=Header(default=None,alias='X-Sync-Key')):
    auth(x_sync_key)
    now=datetime.now(timezone.utc)
    with Session(engine) as db:
        row=db.get(DeviceRecord, body.device_id)
        if row:
            if row.status == 'blocked':
                raise HTTPException(403,'DEVICE_BLOCKED')
            row.device_name=body.device_name
            row.user_name=body.user_name
            row.last_seen=now
        else:
            row=DeviceRecord(device_id=body.device_id,device_name=body.device_name,user_name=body.user_name,status='active',last_seen=now,created_at=now)
            db.add(row)
        db.commit()
    return {'ok':True,'device_id':body.device_id,'status':row.status}

class DeviceHeartbeat(BaseModel):
    device_id: str
    device_name: str

@app.post('/api/devices/heartbeat')
def device_heartbeat(body: DeviceHeartbeat, x_sync_key: str|None=Header(default=None,alias='X-Sync-Key')):
    auth(x_sync_key)
    now=datetime.now(timezone.utc)
    with Session(engine) as db:
        row=db.get(DeviceRecord, body.device_id)
        if row:
            if row.status == 'blocked':
                raise HTTPException(403,'DEVICE_BLOCKED')
            row.device_name=body.device_name
            row.last_seen=now
        else:
            db.add(DeviceRecord(device_id=body.device_id,device_name=body.device_name,user_name='Dixit User',status='active',last_seen=now,created_at=now))
        db.commit()
    return {'ok':True,'device_id':body.device_id,'last_seen':now.isoformat()}

@app.get('/api/devices')
def devices(x_sync_key: str|None=Header(default=None,alias='X-Sync-Key')):
    auth(x_sync_key)
    with Session(engine) as db:
        rows=db.query(DeviceRecord).order_by(DeviceRecord.last_seen.desc()).all()
        return {'ok':True,'devices':[{'device_id':r.device_id,'device_name':r.device_name,'user_name':getattr(r,'user_name','Dixit User'),'status':getattr(r,'status','active') or 'active','last_seen':r.last_seen.isoformat()} for r in rows]}

class DeviceAction(BaseModel):
    device_id: str

def _set_device_status(device_id: str, status: str, key: str|None):
    auth(key)
    with Session(engine) as db:
        row=db.get(DeviceRecord,device_id)
        if not row: raise HTTPException(404,'Device not found')
        row.status=status
        db.commit()
        return {'ok':True,'device_id':device_id,'status':status}

@app.post('/api/devices/block')
def block_device(body: DeviceAction, x_sync_key: str|None=Header(default=None,alias='X-Sync-Key')):
    return _set_device_status(body.device_id,'blocked',x_sync_key)

@app.post('/api/devices/unblock')
def unblock_device(body: DeviceAction, x_sync_key: str|None=Header(default=None,alias='X-Sync-Key')):
    return _set_device_status(body.device_id,'active',x_sync_key)

def check_device_allowed(device_id: str, db: Session):
    row=db.get(DeviceRecord,device_id)
    if row and row.status == 'blocked':
        raise HTTPException(403,'DEVICE_BLOCKED')

def auth(key: str|None):
    if not key or key != SYNC_KEY: raise HTTPException(401,'Invalid sync key')

def parse_dt(s:str):
    return datetime.fromisoformat(s.replace('Z','+00:00'))

@app.post('/api/sync/push')
def push(body:PushBody,x_sync_key:str|None=Header(default=None,alias='X-Sync-Key')):
    auth(x_sync_key); changed=0
    with Session(engine) as db:
        if body.device_id: check_device_allowed(body.device_id, db)
        for item in body.records:
            dt=parse_dt(item.updated_at)
            old=db.get(SyncRecord,item.id)
            if old and old.updated_at and old.updated_at >= dt: continue
            if old:
                old.module=item.module; old.updated_at=dt; old.data=json.dumps(item.data,ensure_ascii=False); old.deleted=1 if item.deleted else 0
            else:
                db.add(SyncRecord(id=item.id,module=item.module,updated_at=dt,data=json.dumps(item.data,ensure_ascii=False),deleted=1 if item.deleted else 0))
            changed+=1
        db.commit()
    return {'ok':True,'changed':changed}

@app.get('/api/sync/pull')
def pull(since:str|None=None,x_sync_key:str|None=Header(default=None,alias='X-Sync-Key')):
    auth(x_sync_key); since_dt=parse_dt(since) if since else datetime.fromtimestamp(0,timezone.utc)
    with Session(engine) as db:
        if device_id: check_device_allowed(device_id, db)
        rows=db.query(SyncRecord).filter(SyncRecord.updated_at>since_dt).order_by(SyncRecord.updated_at.asc()).all()
        out=[]
        for r in rows:
            out.append({'module':r.module,'id':r.id,'updated_at':r.updated_at.isoformat(),'data':json.loads(r.data),'deleted':bool(r.deleted)})
    return {'ok':True,'records':out,'server_time':datetime.now(timezone.utc).isoformat()}


@app.get('/api/backup/export')
def backup_export(x_sync_key: str|None=Header(default=None,alias='X-Sync-Key')):
    auth(x_sync_key)
    with Session(engine) as db:
        rows=db.query(SyncRecord).order_by(SyncRecord.updated_at.asc()).all()
        return {'ok':True,'server_time':datetime.now(timezone.utc).isoformat(),
                'records':[{'module':r.module,'id':r.id,'updated_at':r.updated_at.isoformat(),'data':json.loads(r.data),'deleted':bool(r.deleted)} for r in rows]}

@app.post('/api/backup/restore')
def backup_restore(body:PushBody,x_sync_key: str|None=Header(default=None,alias='X-Sync-Key')):
    auth(x_sync_key); changed=0
    with Session(engine) as db:
        if body.device_id: check_device_allowed(body.device_id, db)
        for item in body.records:
            dt=parse_dt(item.updated_at)
            old=db.get(SyncRecord,item.id)
            if old and old.updated_at >= dt: continue
            if old:
                old.module=item.module; old.updated_at=dt; old.data=json.dumps(item.data,ensure_ascii=False); old.deleted=1 if item.deleted else 0
            else:
                db.add(SyncRecord(id=item.id,module=item.module,updated_at=dt,data=json.dumps(item.data,ensure_ascii=False),deleted=1 if item.deleted else 0))
            changed += 1
        db.commit()
    return {'ok':True,'changed':changed}
