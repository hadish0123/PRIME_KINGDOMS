import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID,createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import pg from 'pg';
import { createDatabase,migrate } from '../../src/database.js';
import { gameState } from '../../src/game.js';

test('real PostgreSQL: upgrade an existing world without changing accounts, homes, residents or position',async()=>{
  assert.ok(process.env.TEST_DATABASE_URL,'A disposable database is required');
  const admin=new pg.Pool({connectionString:process.env.TEST_DATABASE_URL});
  const schema=`upgrade_${randomUUID().replaceAll('-','')}`;
  const url=new URL(process.env.TEST_DATABASE_URL);url.searchParams.set('options',`-c search_path=${schema}`);
  let pool;
  try {
    await admin.query(`CREATE SCHEMA "${schema}"`);
    pool=createDatabase({databaseUrl:url.toString(),databasePoolMax:3});
    await pool.query('CREATE TABLE schema_migrations(name text PRIMARY KEY,checksum text NOT NULL,applied_at timestamptz NOT NULL DEFAULT now())');
    for(const name of ['001_worlds.sql','002_players_villages.sql','003_movement_budget.sql']){
      const sql=await readFile(new URL(`../../migrations/${name}`,import.meta.url),'utf8');
      await pool.query(sql);
      await pool.query('INSERT INTO schema_migrations(name,checksum) VALUES($1,$2)',[name,createHash('sha256').update(sql).digest('hex')]);
    }
    const world=randomUUID(),account=randomUUID(),player=randomUUID(),village=randomUUID();
    await pool.query("INSERT INTO worlds(id,slug,name,seed) VALUES($1,'prime-world','PRIME KINGDOMS',541652784)",[world]);
    await pool.query("INSERT INTO accounts(id,email,display_name,password_hash) VALUES($1,'existing@example.com','Existing','unused-test-hash')",[account]);
    await pool.query('INSERT INTO players(id,account_id,world_id,x,y,z,yaw) VALUES($1,$2,$3,-2.14662957,43.1,12.3490549,0.12345)',[player,account,world]);
    await pool.query("INSERT INTO villages(id,world_id,owner_player_id,slot,name,x,y,z) VALUES($1,$2,$3,0,'Existing Home',0,43,0)",[village,world,player]);
    for(const [role,count] of [['soldier',8],['villager',5]])for(let n=0;n<count;n++){
      await pool.query('INSERT INTO npcs(village_id,role,ordinal,name,x,y,z) VALUES($1,$2,$3,$4,$5,43,$6)',[village,role,n,`${role} ${n}`,n*2,role==='soldier'?22:-16]);
    }
    const before={
      worlds:(await pool.query('SELECT * FROM worlds')).rows,
      accounts:(await pool.query('SELECT * FROM accounts')).rows,
      homes:(await pool.query('SELECT * FROM villages')).rows,
      residents:(await pool.query('SELECT * FROM npcs ORDER BY role,ordinal')).rows,
      position:(await pool.query('SELECT id,x,y,z,yaw FROM players')).rows,
    };
    await migrate(pool);await migrate(pool);
    assert.deepEqual((await pool.query('SELECT * FROM worlds')).rows,before.worlds);
    assert.deepEqual((await pool.query('SELECT * FROM accounts')).rows,before.accounts);
    assert.deepEqual((await pool.query('SELECT * FROM villages')).rows,before.homes);
    assert.deepEqual((await pool.query('SELECT * FROM npcs ORDER BY role,ordinal')).rows,before.residents);
    assert.deepEqual((await pool.query('SELECT id,x,y,z,yaw FROM players')).rows,before.position);
    const state=await gameState(pool,player);
    assert.equal(state.player.armyOrder,'guard');assert.equal(state.player.mount.mounted,false);
    assert.deepEqual(state.player.mount.position,{x:12,y:43.1,z:20});
    assert.equal(state.territories.owned,1);assert.equal(state.territories.cells[0].ownerPlayerId,player);
    assert.equal(state.village.soldierCount,8);assert.equal(state.village.villagerCount,5);
    assert.ok((await pool.query('SELECT count(*)::int AS n FROM schema_migrations')).rows[0].n>=6);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM kingdom_legacy_units WHERE player_id=$1',[player])).rows[0].n,8);
    assert.equal((await pool.query("SELECT level FROM kingdom_buildings WHERE player_id=$1 AND key='walls'",[player])).rows[0].level,1);
    // Reproduce an existing strategic account at the pre-0.9.3 boundary.
    // A queued defense must finish normally; a completed upgrade must survive.
    await pool.query("UPDATE kingdom_buildings SET level=0 WHERE player_id=$1 AND key='walls'",[player]);
    await pool.query("UPDATE kingdom_buildings SET level=5 WHERE player_id=$1 AND key='gatehouse'",[player]);
    await pool.query("INSERT INTO kingdom_tasks(player_id,kind,key,target_level,cost,started_at,finishes_at) VALUES($1,'building','walls',1,'{}',clock_timestamp(),clock_timestamp()+interval '1 hour')",[player]);
    const inventory=(await pool.query('SELECT * FROM kingdom_resources WHERE player_id=$1 ORDER BY resource',[player])).rows;
    const queued=(await pool.query('SELECT * FROM kingdom_tasks WHERE player_id=$1',[player])).rows;
    await pool.query("DELETE FROM schema_migrations WHERE name='011_starter_fortifications.sql'");
    await migrate(pool);
    assert.equal((await pool.query("SELECT level FROM kingdom_buildings WHERE player_id=$1 AND key='walls'",[player])).rows[0].level,0,'Migration completed an unfinished defense queue');
    assert.equal((await pool.query("SELECT level FROM kingdom_buildings WHERE player_id=$1 AND key='gatehouse'",[player])).rows[0].level,5,'Migration replaced an earned defense upgrade');
    assert.deepEqual((await pool.query('SELECT * FROM kingdom_resources WHERE player_id=$1 ORDER BY resource',[player])).rows,inventory);
    assert.deepEqual((await pool.query('SELECT * FROM kingdom_tasks WHERE player_id=$1',[player])).rows,queued);
  } finally {
    if(pool)await pool.end();
    await admin.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);await admin.end();
  }
});
