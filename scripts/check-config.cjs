const fs=require('node:fs'),vm=require('node:vm');
const guard=require('../js/clone-guard.js');
const context={window:{}};vm.runInNewContext(fs.readFileSync('js/config.js','utf8'),context);
try{guard.validate(context.window.HSN_CONFIG);console.log('Configuração do clone válida.');}catch(e){console.error(e.message);process.exitCode=1;}
