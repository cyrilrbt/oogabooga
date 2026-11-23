// Portable assertions for the experimental handwritten JavaScript VM.
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
typedef struct {char *text;uint64_t length;void *nodes;uint64_t count;char *title;uint64_t capacity,title_length;char *css;uint64_t css_length;void *meta;void *hidden;uint64_t work;void *dom;uint64_t version;} Doc;
extern Doc *engine_parse(const char *,size_t);
extern void engine_document_free(Doc *);
extern void *engine_js_new(void *);
extern void engine_js_free(void *);
extern uintptr_t engine_js_eval(void *,const char *,size_t),engine_js_global(void *,const char *);
extern uint64_t engine_js_error(void *),engine_js_dirty(void *);
extern void engine_js_tick(void *,uint64_t),engine_js_start(void *);
extern int engine_js_event(void *,uint64_t,const char *),engine_js_prepare(void *),engine_js_same_origin(const char *,const char *);
extern void *engine_js_request_next(void *);
extern void engine_js_complete(void *,void *,int64_t,const char *,size_t);
extern uint64_t engine_dom_get_element_by_id(void *,const char *);
extern const char *engine_dom_get_attribute(void *,uint64_t,const char *);
static void run(void *vm,const char *s){engine_js_eval(vm,s,strlen(s));if(engine_js_error(vm))fprintf(stderr,"VM error %llu: %s\n",(unsigned long long)engine_js_error(vm),s);assert(!engine_js_error(vm));}
static double number(void *vm,const char *name){uintptr_t v=engine_js_global(vm,name);assert(v>3&&*(uint64_t *)v==1);return *(double *)(v+8);}
static const char *string(void *vm,const char *name){uintptr_t v=engine_js_global(vm,name);assert(v>3&&*(uint64_t *)v==2);return *(char **)(v+8);}
static void equal(void *vm,const char *name,double value){double n=number(vm,name);if(n!=value)fprintf(stderr,"%s: got %.17g expected %.17g\n",name,n,value);assert(n==value);}
int main(void){
    const char *html="<html><head><title>Before</title></head><body><p id=output class='old notice'>Before</p><button id=button>Go</button><input id=field value=initial></body></html>";
    Doc *d=engine_parse(html,strlen(html));assert(d);void *vm=engine_js_new(d->dom);assert(vm);
    run(vm,"let a=2+3*4; const text='café \\uD83C\\uDF10'; let units=text.length; let arr=[1,2,3]; arr.push(4); let obj={x:arr[2],name:text}; obj.x=5; let sum=0; for(let i=0;i<4;i++){sum+=arr[i];} let w=0; while(w<3){w++;} let check=(a===14)&&(sum===10); let short=0; false&&(short=9); true||(short=9);");
    equal(vm,"a",14);equal(vm,"sum",10);equal(vm,"w",3);equal(vm,"short",0);assert(engine_js_global(vm,"check")==3);assert(!strcmp(string(vm,"text"),"café 🌐"));equal(vm,"units",7);
    run(vm,"function make(x){return function(y){return x+y;};} const add=make(7); let answer=add(5); let arrow=(x)=>x*2; let twice=arrow(6); let zero=()=>{return 9;}; let nine=zero(); let description='count '+sum; let missing=typeof notDeclared; let keys=Object.keys(obj); let key=keys[0];");
    run(vm,"let nan=0/0;let nanSame=nan===nan;let infinityText=String(1/0);let documentSame=false;document.addEventListener('probe',e=>{documentSame=e.target===document;});");assert(engine_js_global(vm,"nanSame")==2);assert(!strcmp(string(vm,"infinityText"),"Infinity"));engine_js_event(vm,1,"probe");assert(engine_js_global(vm,"documentSame")==3);
    equal(vm,"answer",12);equal(vm,"twice",12);equal(vm,"nine",9);assert(!strcmp(string(vm,"description"),"count 10"));assert(!strcmp(string(vm,"missing"),"undefined"));assert(!strcmp(string(vm,"key"),"x"));
    run(vm,"const node=document.getElementById('output'); node.textContent='Hello '+text; node.classList.remove('old'); node.classList.add('ready'); node.style.backgroundColor='#ffffff'; node.style.color='red'; let color=node.style.color; const child=document.createElement('span'); child.id='created'; child.textContent='added'; document.body.appendChild(child); let same=node===document.querySelector('#output'); let matches=document.querySelectorAll('.notice').length;");
    assert(engine_js_global(vm,"same")==3);equal(vm,"matches",1);assert(!strcmp(string(vm,"color"),"red"));uint64_t out=engine_dom_get_element_by_id(d->dom,"output");assert(out);assert(!strcmp(engine_dom_get_attribute(d->dom,out,"class"),"notice ready"));assert(engine_dom_get_element_by_id(d->dom,"created"));assert(engine_js_dirty(vm)&1);
    run(vm,"let order=''; document.addEventListener('click',()=>{order+='C';},true); document.getElementById('button').addEventListener('click',(event)=>{order+='T';event.preventDefault();}); document.addEventListener('click',()=>{order+='B';});");
    uint64_t button=engine_dom_get_element_by_id(d->dom,"button");assert(engine_js_event(vm,button,"click"));if(strcmp(string(vm,"order"),"CTB"))fprintf(stderr,"event order %s\n",string(vm,"order"));assert(!strcmp(string(vm,"order"),"CTB"));
    run(vm,"let asyncOrder=''; Promise.resolve(2).then(x=>{asyncOrder+='P';return x+1;}).then(x=>{asyncOrder+=x;}); queueMicrotask(()=>{asyncOrder+='M';}); asyncOrder+='S'; let timed=0; let canceled=setTimeout(()=>{timed=99;},1); clearTimeout(canceled); setTimeout((x)=>{timed=x;},10,7);");
    assert(!strcmp(string(vm,"asyncOrder"),"SPM3"));engine_js_tick(vm,9);equal(vm,"timed",0);engine_js_tick(vm,10);equal(vm,"timed",7);
    run(vm,"let promiseValue=0; const pending=new Promise((resolve,reject)=>{setTimeout(()=>{resolve(11);},5);}); pending.then(x=>{promiseValue=x;}); let recovered=''; Promise.reject('no').catch(e=>{recovered=e;}); let json=JSON.parse('{\"x\": [1,true,null,\"caf\\u00e9\"]}'); let jsonValue=json.x[3];");
    assert(!strcmp(string(vm,"recovered"),"no"));assert(!strcmp(string(vm,"jsonValue"),"café"));engine_js_tick(vm,15);equal(vm,"promiseValue",11);
    run(vm,"let fetched=''; fetch('/data').then(response=>response.json()).then(data=>{fetched=data.message;});");void *request=engine_js_request_next(vm);assert(request);const char *json="{\"message\":\"from fetch\"}";engine_js_complete(vm,request,200,json,strlen(json));engine_js_tick(vm,16);assert(!strcmp(string(vm,"fetched"),"from fetch"));
    assert(engine_js_same_origin("https://example.com/a","https://EXAMPLE.com:443/b"));assert(!engine_js_same_origin("https://example.com","http://example.com"));assert(!engine_js_same_origin("https://example.com","https://example.com.evil"));assert(!engine_js_same_origin("https://example.com","https://user@example.com"));assert(engine_js_same_origin("http://[::1]:8765/a","http://[::1]:8765/b"));
    engine_js_eval(vm,"const broken = ;",16);assert(engine_js_error(vm));run(vm,"let stillWorks=3;");equal(vm,"stillWorks",3);engine_js_eval(vm,"while(true){}",13);assert(engine_js_error(vm)==3);
    engine_js_free(vm);engine_document_free(d);
    html="<html><body><p id=x>old</p><button id=b onclick=\"document.getElementById('x').textContent='clicked';return false;\">Go</button><script>var sequence='I';</script><script src='/external.js'></script><script>sequence+='F';document.addEventListener('DOMContentLoaded',()=>{sequence+='D';});</script><script type=application/ld+json>{\"inert\":true}</script></body></html>";
    d=engine_parse(html,strlen(html));assert(d);vm=engine_js_new(d->dom);assert(engine_js_prepare(vm));engine_js_start(vm);assert(!strcmp(string(vm,"sequence"),"I"));request=engine_js_request_next(vm);assert(request);const char *external="sequence+='E';";engine_js_complete(vm,request,200,external,strlen(external));assert(!strcmp(string(vm,"sequence"),"IEFD"));assert(engine_js_event(vm,engine_dom_get_element_by_id(d->dom,"b"),"click"));engine_js_free(vm);engine_document_free(d);
    html="<meta http-equiv=Content-Security-Policy content=\"script-src 'none'\"><script>var escaped=1;</script>";d=engine_parse(html,strlen(html));vm=engine_js_new(d->dom);assert(!engine_js_prepare(vm));assert(!engine_js_global(vm,"escaped"));engine_js_free(vm);engine_document_free(d);
    html="<body>Limits</body>";d=engine_parse(html,strlen(html));vm=engine_js_new(d->dom);const char *grow="let grow='x';while(true){grow=grow+grow;}";engine_js_eval(vm,grow,strlen(grow));assert(engine_js_error(vm)==3);engine_js_free(vm);
    vm=engine_js_new(d->dom);const char *deep="function recurse(){return recurse();}recurse();";engine_js_eval(vm,deep,strlen(deep));assert(engine_js_error(vm)==3);engine_js_free(vm);
    const char *bad[]={"'unterminated","let x=(;","let x={a:};","let x=[1,;","function f( {","new Unsupported();","new ;","JSON.parse('function(){}');","JSON.parse('[1,]');"};
    for(size_t i=0;i<sizeof(bad)/sizeof(*bad);i++){vm=engine_js_new(d->dom);engine_js_eval(vm,bad[i],strlen(bad[i]));assert(engine_js_error(vm));engine_js_free(vm);}engine_document_free(d);
    d=engine_parse("<body>Fuzz</body>",17);unsigned random=17;const char alphabet[]="abc012 let;{}[]()=+-*/'\".,:!<>";
    for(unsigned trial=0;trial<200;trial++){char source[49];for(unsigned j=0;j<48;j++){random=random*1664525u+1013904223u;source[j]=alphabet[random%(sizeof(alphabet)-1)];}source[48]=0;vm=engine_js_new(d->dom);engine_js_eval(vm,source,48);engine_js_free(vm);}engine_document_free(d);
    puts("PASS: assembly JS bytecode, lexical closures, control flow, objects/arrays, Unicode, DOM/classes/styles, event phases/cancellation, timers, promises/microtasks, JSON, ordered scripts, CSP policy and bounded execution");
}
