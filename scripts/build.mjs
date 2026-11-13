import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const target=path.join(root,'dist');
fs.rmSync(target,{recursive:true,force:true});fs.mkdirSync(target);
for(const name of ['index.html','configurar.html','senha.html','manifest.json','service-worker.js','.nojekyll','css','js','icons'])fs.cpSync(path.join(root,name),path.join(target,name),{recursive:true});
console.log('Aplicativo gerado em dist/. SQL, documentação, backups e funções de servidor ficam fora da publicação.');
