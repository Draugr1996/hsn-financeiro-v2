// Regressão para a falha real 23514: legado marcado pago com valor zero.
import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';import assert from 'node:assert/strict';
const root=new URL('../',import.meta.url),fixture=fs.readFileSync(new URL('tests/sql-integration.mjs',root),'utf8').match(/await pg.exec\(`([\s\S]*?)`\);/)[1];
const sql=fs.readFileSync(process.env.HSN_MIGRATION_UNDER_TEST||new URL('sql/HSN-10-integridade-financeira.sql',root),'utf8');
const uid='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222';
const ids={zero:'8f313a7d-9d38-4be5-a408-610930b39bac',valid:'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',missing:'cccccccc-cccc-4ccc-8ccc-cccccccccccc',receivable:'dddddddd-dddd-4ddd-8ddd-dddddddddddd'};
const pg=new PGlite(),tests=[];
const q=async(s,args=[]) => (await pg.query(s,args)).rows;
async function test(name,fn){await fn();tests.push(name);console.log('PASS',name);}
try{
await pg.exec(fixture);await pg.exec(`set request.jwt.claim.sub='${uid}'`);
// A estimativa é positiva de propósito: actual_amount=0 NÃO autoriza inventar saída de 500.
await pg.query(`insert into payables(id,owner_id,title,actual_amount,estimated_amount,payment_status,paid_date,due_date,competence) values
 ($1,$4,'Conta legada zero',0,500,'paid','2026-10-22','2026-10-22','2026-10-01'),
 ($2,$4,'Conta legada positiva',150,200,'paid','2026-10-22','2026-10-22','2026-10-01'),
 ($3,$4,'Conta legada sem valor',null,null,'paid','2026-10-22','2026-10-22','2026-10-01')`,[ids.zero,ids.valid,ids.missing,uid]);
await pg.query(`insert into sicoob_collections(id,owner_id,company,reference,due_date,amount,status) values($1,$2,'Legado zero','LEG-ZERO','2026-10-22',0,'paid')`,[ids.receivable,uid]);
const original=(await q('select id,to_jsonb(p) data from payables p order by id'));
if(process.env.HSN_EXPECT_OLD_FAILURE){
 let error;try{await pg.exec(sql);}catch(e){error=e;}
 assert.ok(error);assert.equal(error.code,'23514');assert.match(error.message,/hsn10_events_amount_check/);await pg.exec('rollback');
 assert.deepEqual(await q('select id,to_jsonb(p) data from payables p order by id'),original);
 assert.equal((await q("select to_regclass('public.hsn10_events') name"))[0].name,null);
 console.log('REPRODUZIDO: erro 23514 no legado zero; ROLLBACK preserva os registros de origem.');
}else{
await test('Migração conclui com conta paga zero e sem valor',async()=>{await pg.exec(sql);assert.equal((await q('select version from hsn10_migrations'))[0].version,10);});
await test('Conta zero mantém valor, status e data, sem usar estimativa positiva como pagamento',async()=>{const r=(await q('select * from payables where id=$1',[ids.zero]))[0];assert.equal(Number(r.actual_amount),0);assert.equal(Number(r.estimated_amount),500);assert.equal(r.payment_status,'paid');assert.equal(Number(r.paid_amount),0);assert.equal(r.paid_date.toISOString().slice(0,10),'2026-10-22');assert.equal((await q('select count(*)::int n from hsn10_events where target_id=$1',[ids.zero]))[0].n,0);});
await test('Conta sem valor e recebível zero não criam baixas fictícias',async()=>{assert.equal((await q('select count(*)::int n from hsn10_events where target_id=any($1::uuid[])',[[ids.missing,ids.receivable]]))[0].n,0);});
await test('Baixa positiva continua migrando com o valor real',async()=>{const r=(await q('select * from hsn10_events where target_id=$1',[ids.valid]))[0];assert.equal(Number(r.amount),150);assert.equal(r.legacy,true);});
await test('Registros sem baixa positiva ficam sinalizados com os valores originais',async()=>{const rows=await q("select * from hsn10_audit where action='MIGRATION_REVIEW' order by record_id");assert.equal(rows.length,3);const zero=rows.find(r=>r.record_id===ids.zero);assert.equal(zero.before_data.actual_amount,0);assert.equal(zero.before_data.estimated_amount,500);assert.deepEqual(zero.before_data,zero.after_data);});
await test('Backup mantém exatamente os registros anteriores à migração',async()=>{for(const r of original){const saved=(await q("select data from hsn10_backup where table_name='payables' and record_id=$1",[r.id]))[0];assert.deepEqual(saved.data,r.data);}});
await test('Reexecutar não duplica abertura, aviso ou valores',async()=>{const before=await q('select count(*)::int n,sum(amount) amount from hsn10_events');await pg.exec(sql);assert.deepEqual(await q('select count(*)::int n,sum(amount) amount from hsn10_events'),before);assert.equal((await q("select count(*)::int n from hsn10_audit where action='MIGRATION_REVIEW'"))[0].n,3);});
await test('Restrição de valor positivo permanece ativa para novas baixas',async()=>{let code;try{await pg.query("insert into hsn10_events(owner_id,kind,target_id,amount,reference,reason,request_id) values($1,'payable',$2,0,'TESTE','Não deve aceitar zero',gen_random_uuid())",[uid,ids.zero]);}catch(e){code=e.code;}assert.equal(code,'23514');});
await test('Aviso de migração respeita isolamento por proprietário',async()=>{await pg.exec(`set role authenticated;set request.jwt.claim.sub='${other}'`);assert.equal((await q("select count(*)::int n from hsn10_audit where action='MIGRATION_REVIEW'"))[0].n,0);await pg.exec(`reset role;set request.jwt.claim.sub='${uid}'`);});
fs.writeFileSync(new URL('docs/migration-legacy-results.json',root),JSON.stringify({passed:tests.length,tests},null,2)+'\n');
}
}finally{await pg.close();}
