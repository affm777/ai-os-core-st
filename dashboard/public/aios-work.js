/* AIOS — Seiten: Dashboard, Projekte, Inbox + Todo-API */
(function(A){
"use strict";
var $=A.$,esc=A.esc,nf=A.nf,el=A.el,toast=A.toast,copyText=A.copyText,stateNote=A.stateNote,noteEl=A.noteEl,daysLabel=A.daysLabel,ampelCls=A.ampelCls;

function projects(){var pf=A.DATA&&A.DATA.portfolio&&A.DATA.portfolio.data;return(pf&&pf.projects)||[];}
function projBySlug(slug){return projects().filter(function(p){return p.slug===slug;})[0];}
function migrateFixFor(slug){
  var chk=A.DATA&&A.DATA["system-check"];var cs=(chk&&chk.data&&chk.data.checks)||[];
  var c=cs.filter(function(x){return x.name==="STATE.md: "+slug&&x.fix;})[0];
  return(c&&c.fix)||("Stelle die Status-Datei (STATE.md) von "+slug+" verlustfrei auf die aktuelle Template-Struktur um: Backup anlegen, Inhalte erhalten, danach Diff zeigen.");
}
A.projBySlug=projBySlug;
/* Einheitliche, ehrliche Aktiv-Definition: ein Projekt ist aktiv, wenn es
   mindestens eine echte Sitzung in 7 Tagen hatte — NICHT nur, weil die STATE.md
   frisch berührt wurde. Wird von Kachel, Projekte-Liste, Seitenkarte und Aufgaben-Seite gleich benutzt.
   Ein manueller Override (manual_status: "aktiv"|"ruhend") sticht die Automatik. */
function isActive(p){
  var mo=p&&p.manual_status;
  if(mo==="aktiv")return true;
  if(mo==="ruhend")return false;
  return((p&&p.sessions_7d)||0)>0;
}
A.isActive=isActive;
/* Manueller Aktiv/Ruhend-Override setzen (status: "aktiv"|"ruhend"|"auto"). */
function setProjStatus(slug,status){
  if(A.IS_DEMO){var p=projBySlug(slug);if(p)p.manual_status=(status==="auto"?null:status);rerender();toast("Demo: Status auf „"+status+"“ gesetzt.");return;}
  A.apiPost("/api/project/status",{project:slug,status:status}).then(function(r){if(!r.ok){toast(todoErr(r.data),true);return;}A.DATA.portfolio=r.data.portfolio;rerender();toast(status==="auto"?"Status folgt wieder der Automatik.":"Projekt auf „"+status+"“ gesetzt.");}).catch(function(){toast("Netzwerkfehler beim Setzen des Status.",true);});
}
A.setProjStatus=setProjStatus;
/* Manuelle Projekt-Reihenfolge speichern (Drag & Drop im Aufgaben-Tab). */
function setOrder(order){
  if(A.IS_DEMO){if(A.DATA.portfolio&&A.DATA.portfolio.data)A.DATA.portfolio.data.order=order;rerender();toast("Demo: Reihenfolge gemerkt.");return;}
  A.apiPost("/api/project/order",{order:order}).then(function(r){if(!r.ok){toast(todoErr(r.data),true);return;}A.DATA.portfolio=r.data.portfolio;rerender();toast("Reihenfolge gespeichert.");}).catch(function(){toast("Netzwerkfehler beim Speichern der Reihenfolge.",true);});
}
/* Fertige Claude-Anweisung: verstreute Todos verlustfrei nach ### Pending Todos ziehen. */
function scatterFixFor(slug){
  var p=projBySlug(slug);var n=(p&&p.todos_outside_section)||0;
  return "In der Status-Datei (STATE.md) von "+slug+" stehen "+n+" Aufgaben (- [ ]) außerhalb der Sektion \"### Pending Todos\" und werden im Dashboard nicht erfasst. Verschiebe diese Checkbox-Zeilen verlustfrei nach \"### Pending Todos\" (passenden #### Themen-Cluster wählen oder neu anlegen), ohne andere Inhalte, Reihenfolge oder Formulierungen zu ändern. Lege vorher ein Backup an und zeige danach einen Diff.";
}
/* Postfach-Zahlen aus der tatsächlich gezogenen inbox.json ableiten, damit Dashboard
   und Inbox-Seite denselben Stand zeigen (heute.json.mail wird nur als Fallback genutzt). */
function mailCounts(){
  var ib=A.DATA.inbox&&A.DATA.inbox.data;
  if(ib&&ib.items){
    var m={handeln:0,warten:0,kenntnis:0,top:[]};
    ib.items.forEach(function(i){if(i.source==="vault")return;if(m[i.prio]!=null)m[i.prio]++;if(i.prio==="handeln"&&i.titel&&m.top.length<3)m.top.push(i.titel);});
    return m;
  }
  var h=A.DATA.heute&&A.DATA.heute.data;
  return(h&&h.mail)||{handeln:0,warten:0,kenntnis:0,top:[]};
}
A.mailCounts=mailCounts;

/* ---------- Todo-API ---------- */
function todoErr(d){var m={"missing-fields":"Fehlende Angaben.","unknown-project":"Projekt unbekannt.","state-missing":"Keine Status-Datei gefunden.","not-template-conform":"Die Status-Datei ist noch im alten Format.","hash-not-found":"Zeile nicht mehr gefunden (evtl. bereits geändert).","no-backup":"Kein Rückgängig-Stand in dieser Sitzung."};return(d&&m[d.error])||(d&&d.detail)||"Aktion fehlgeschlagen.";}
function localToggle(slug,hash,checked){var p=projBySlug(slug);if(p)(p.pending_todos||[]).forEach(function(t){if(t.hash===hash)t.checked=checked;});}
function localRemove(slug,hash){var p=projBySlug(slug);if(p)p.pending_todos=(p.pending_todos||[]).filter(function(t){return t.hash!==hash;});}
function rerender(){A.renderPage();}
function toggleTodo(slug,hash,cb){
  if(A.IS_DEMO){localToggle(slug,hash,cb.checked);rerender();toast("Demo: Status lokal umgeschaltet.");return;}
  cb.disabled=true;var prev=!cb.checked;
  A.apiPost("/api/todo/toggle",{project:slug,line_hash:hash}).then(function(r){if(!r.ok){cb.checked=prev;cb.disabled=false;toast(todoErr(r.data),true);return;}A.DATA.portfolio=r.data.portfolio;rerender();toast("Gespeichert · Rückgängig möglich.");}).catch(function(){cb.checked=prev;cb.disabled=false;toast("Netzwerkfehler beim Speichern.",true);});
}
function removeTodo(slug,hash,li){
  li.classList.add("removing");
  if(A.IS_DEMO){setTimeout(function(){localRemove(slug,hash);rerender();toast("Demo: Punkt lokal entfernt.");},220);return;}
  A.apiPost("/api/todo/remove",{project:slug,line_hash:hash}).then(function(r){if(!r.ok){li.classList.remove("removing");toast(todoErr(r.data),true);return;}A.DATA.portfolio=r.data.portfolio;rerender();toast("Entfernt · Rückgängig möglich.");}).catch(function(){li.classList.remove("removing");toast("Netzwerkfehler beim Entfernen.",true);});
}
function undoTodo(slug){
  if(A.IS_DEMO){toast("Demo-Modus: kein Server verbunden — nichts wiederherzustellen.");return;}
  A.apiPost("/api/todo/undo",{project:slug}).then(function(r){if(!r.ok){toast(todoErr(r.data),true);return;}A.DATA.portfolio=r.data.portfolio;rerender();toast("Wiederhergestellt.");}).catch(function(){toast("Netzwerkfehler beim Rückgängigmachen.",true);});
}
function todoListHtml(todos,limit){
  var h='<ul class="todos">';
  todos.slice(0,limit||todos.length).forEach(function(t){
    var dl=t.deadline?'<span class="dl mono">'+esc(fmtDl(t.deadline))+"</span>":"";
    h+='<li'+(t.checked?' class="done"':"")+'><input type="checkbox" class="chk" '+(t.checked?"checked":"")+' data-hash="'+esc(t.hash)+'"/><span class="txt">'+esc(t.text)+dl+'</span><button class="rm" data-hash="'+esc(t.hash)+'" title="Entfernen">✕</button></li>';});
  return h+"</ul>";
}
/* Todos nach Themen-Cluster (aus den ####/**Fett**-Blöcken der STATE.md) gruppiert.
   Ohne Cluster in der Datei faellt die Ansicht auf eine flache Liste zurueck. */
function clusteredTodosHtml(todos){
  var order=[],groups={};
  (todos||[]).forEach(function(t){var k=(t.cluster!=null&&t.cluster!=="")?t.cluster:"__none";if(!(k in groups)){groups[k]=[];order.push(k);}groups[k].push(t);});
  var realClusters=order.filter(function(k){return k!=="__none";});
  if(!realClusters.length)return todoListHtml(todos);
  var h="";
  order.forEach(function(k){
    var list=groups[k];
    var openN=list.filter(function(t){return!t.checked;}).length;
    if(k!=="__none")h+='<div class="tg-cluster"><span class="tg-cluster-nm">'+esc(k)+'</span><span class="tg-cluster-cnt">'+(openN?openN+" offen":"erledigt")+'</span></div>';
    h+=todoListHtml(list);
  });
  return h;
}
function fmtDl(d){var today=new Date().toISOString().slice(0,10);if(d===today)return"heute fällig";return"fällig "+new Date(d).toLocaleDateString("de-DE",{day:"2-digit",month:"2-digit"});}
function wireTodos(root,slug){
  root.querySelectorAll(".chk").forEach(function(cb){cb.addEventListener("change",function(){toggleTodo(slug,cb.getAttribute("data-hash"),cb);});});
  root.querySelectorAll(".rm").forEach(function(btn){btn.addEventListener("click",function(){
    var li=btn.closest("li");if(li.querySelector(".confirm"))return;
    var cf=el("div","confirm");cf.innerHTML='Wirklich entfernen? <button class="yes">Ja</button><button class="no">Abbrechen</button>';li.appendChild(cf);
    cf.querySelector(".yes").addEventListener("click",function(){cf.remove();removeTodo(slug,btn.getAttribute("data-hash"),li);});
    cf.querySelector(".no").addEventListener("click",function(){cf.remove();});
  });});
}

/* ---------- Dashboard ---------- */
function dueTodos(){
  var out=[];var today=new Date().toISOString().slice(0,10);
  projects().forEach(function(p){(p.pending_todos||[]).forEach(function(t){if(!t.checked&&t.deadline&&t.deadline<=today)out.push({p:p.slug,t:t});});});
  return out;
}
function calStatus(){
  var h=A.DATA.heute&&A.DATA.heute.data;
  var kal=(h&&Array.isArray(h.kalender))?h.kalender:[];
  var src=(h&&h.sources)||{};
  var privPulled=!!src.privat_calendar;   // privater Kalender wurde ueber /aios-dashboard gezogen?
  var errored=Object.keys(src).some(function(k){var s=src[k]&&src[k].status;return s&&s!=="ok"&&s!=="unavailable";});
  if(kal.length)return{ok:true,error:false,pulled:privPulled,events:kal};
  return{ok:false,error:errored,pulled:privPulled,events:[]};
}
function renderKpis(){
  // Kacheln oben
  var strip=$("kpiStrip");strip.innerHTML="";
  var ps=projects();
  var act=ps.filter(isActive).length;
  var openT=0;ps.forEach(function(p){(p.pending_todos||[]).forEach(function(t){if(!t.checked)openT++;});});
  var cs=calStatus();
  function tile(href,n,l,s,alert){var t=el(href?"a":"div","ktile"+(alert?" alert":""));if(href)t.href=href;t.innerHTML='<div class="n">'+n+'</div><div class="l">'+l+'</div>'+(s?'<div class="s">'+s+"</div>":"");strip.appendChild(t);}
  var due=dueTodos().length;
  tile("#/projekte",nf(act),"Aktive Projekte","mit Sitzungen · 7 Tage");
  tile("#/aufgaben",nf(openT),"Offene Aufgaben",due?("davon "+due+" heute fällig"):"aus den Status-Dateien",due>0);
  var handeln=mailCounts().handeln||0;
  tile("#/inbox",nf(handeln),"Postfach",handeln===1?"braucht eine Antwort von dir":"brauchen eine Antwort von dir",handeln>0);
  var calSub=cs.events.length?("nächster um "+cs.events[0].zeit+" Uhr"):(cs.error?"Quelle prüfen":(!cs.pulled?"privat noch nicht gezogen":"frei"));
  tile(null,nf(cs.events.length),"Termine heute",calSub,cs.error);
  // Rail: nur Second-Brain-Zahlen
  var rail=$("kpiRail");rail.innerHTML='<div class="rail-title">Second Brain</div>';
  var vaultSec=A.DATA["vault-stats"];
  var note=stateNote(vaultSec,"Kennzahlen");
  var v=(vaultSec&&vaultSec.data)||{};var bt=v.by_type||{};
  function kpi(n,l,s){var d=el("div","kpi");d.innerHTML='<div class="n">'+n+'</div><div class="meta"><div class="l">'+l+'</div>'+(s?'<div class="s">'+s+"</div>":"")+"</div>";rail.appendChild(d);}
  if(note||v.available===false){rail.appendChild(noteEl(note||{cls:"missing",text:"Vault-Statistik nicht verfügbar.",fix:""}));return;}
  kpi("+"+nf(v.new_last_30_days||0),"Neue Notizen","letzte 30 Tage");
  kpi(nf(bt.decision||0),"Decisions","festgehaltene Entscheidungen");
  kpi(nf(bt.learning||0),"Learnings","gesammelte Erkenntnisse");
  kpi(nf(v.inbox_count||0),"Inbox unsortiert","wird nachts einsortiert");
}
/* Fällige Deals aus dem Vertriebsmodul, überfällige zuerst dann nach Fälligkeit. */
function dueDeals(){
  var sd=A.DATA.sales&&A.DATA.sales.data;var deals=(sd&&Array.isArray(sd.deals))?sd.deals:[];
  var today=new Date().toISOString().slice(0,10);
  var out=deals.filter(function(d){return d.due&&d.due<=today;});
  out.sort(function(a,b){if(!!a.overdue!==!!b.overdue)return a.overdue?-1:1;return(a.due||"").localeCompare(b.due||"");});
  return out;
}
function renderFocus(){
  var list=$("focusList");list.innerHTML="";
  var data=A.DATA,pts=[];
  var h=data.heute&&data.heute.data;
  dueTodos().slice(0,2).forEach(function(x){pts.push({tone:"fail",kick:"Aufgabe · "+x.p,lead:x.t.text,sub:fmtDl(x.t.deadline)+" · aus der Status-Datei von "+x.p});});
  var mc=mailCounts();
  if(mc.handeln>0)pts.push({tone:"warn",kick:"Postfach",lead:mc.handeln===1?"Eine Mail wartet auf deine Antwort":mc.handeln+" Mails warten auf deine Antwort",sub:(mc.top||[]).slice(0,2).join(" · ")});
  dueDeals().slice(0,2).forEach(function(d){pts.push({tone:d.overdue?"fail":"warn",kick:(d.overdue?"Überfällig · Deal":"Heute fällig · Deal"),lead:d.next_step||d.name,sub:d.name+(d.company?" · "+d.company:"")});});
  if(h){
    // h.deals kann statt eines Arrays ein Objekt wie {available:false,hint:...} sein
    // (fehlende Pipeline-Quelle) — ohne Array.isArray-Absicherung wirft .filter hier einen TypeError.
    (Array.isArray(h.deals)?h.deals:[]).filter(function(d){return d.faellig;}).slice(0,1).forEach(function(d){pts.push({tone:"warn",kick:"Heute fällig",lead:d.next_step,sub:d.name});});
    if(Array.isArray(h.kalender)&&h.kalender.length)pts.push({tone:"ok",kick:"Kalender",lead:"Nächster Termin um "+h.kalender[0].zeit+" Uhr",sub:h.kalender[0].titel});
  }
  var chk=data["system-check"];
  if(chk&&chk.present&&chk.data){
    var g=A.groupIssues(chk.data.checks);
    var fails=g.issues.filter(function(i){return i.tone==="fail";});
    if(fails.length)pts.push({tone:"fail",kick:"System",lead:fails[0].title,sub:"Details auf der System-Seite"});
  }
  var order={fail:0,warn:1,ok:2};pts.sort(function(a,b){return order[a.tone]-order[b.tone];});
  pts=pts.slice(0,5);
  if(!pts.length)list.innerHTML='<div class="quiet" style="padding:18px 4px">Ruhiger Tag — nichts Dringendes. Das Tages-Briefing befüllt diese Liste jeden Morgen.</div>';
  pts.forEach(function(p,i){
    var row=el("div","focus-item tone-"+p.tone);
    row.innerHTML='<div class="num">'+(i+1)+'</div><div><div class="kick"><span class="dot '+p.tone+'"></span>'+esc(p.kick)+'</div><div class="lead">'+esc(p.lead)+'</div>'+(p.sub?'<div class="sub">'+esc(p.sub)+"</div>":"")+"</div>";
    list.appendChild(row);
  });
}
/* Nächster geplanter Content-Slot aus den Entwürfen (frühester Termin zuerst). */
function nextContentSlot(drafts){
  var withSlot=(drafts||[]).filter(function(d){return d.slot;}).slice().sort(function(a,b){return a.slot<b.slot?-1:a.slot>b.slot?1:0;});
  return withSlot[0]||null;
}
function fmtSlot(s){
  var m=/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}:\d{2})/.exec(s||"");
  return m?(m[3]+"."+m[2]+". "+m[4]+" Uhr"):s;
}
/* Rechte Spalte "Das Wichtigste für heute": vier gleich gestaltete Module
   (Postfach, Termine, Content, Aktivste Projekte). Content nur wenn das
   Branding-Modul eingerichtet ist. */
function renderDashSide(){
  var side=$("sideStack");side.innerHTML="";
  side.classList.add("heute-mods");
  var todayWrap=side.parentElement;if(todayWrap)todayWrap.classList.add("heute-grid");

  var cMail=el("div","side-card heute-mod"),mail=mailCounts();
  cMail.innerHTML='<h4>Postfach <a class="goto" href="#/inbox">öffnen →</a></h4>';
  cMail.appendChild(el("div","mailrow handeln",'<span class="c mono">'+(mail.handeln||0)+'</span><span>'+((mail.handeln||0)===1?"braucht eine Antwort von dir":"brauchen eine Antwort von dir")+"</span>"));
  cMail.appendChild(el("div","mailrow warten",'<span class="c mono">'+(mail.warten||0)+'</span><span>warten auf andere</span>'));
  cMail.appendChild(el("div","mailrow kenntnis",'<span class="c mono">'+(mail.kenntnis||0)+'</span><span>nur zur Kenntnis</span>'));
  side.appendChild(cMail);

  var cCal=el("div","side-card heute-mod","<h4>Termine heute</h4>");
  var noteHeute=stateNote(A.DATA.heute,"Tagesdaten","Privater Kalender wird über /aios-dashboard aktualisiert (Connector), Zweitkonto-Kalender bei jedem Aktualisieren.");
  if(noteHeute)cCal.appendChild(noteEl(noteHeute));
  else{
    var cs=calStatus();
    if(cs.events.length)cs.events.forEach(function(k){cCal.appendChild(el("div","appt",'<span class="t mono">'+esc(k.zeit||"—")+'</span><span>'+esc(k.titel)+"</span>"+(k.konto?'<span class="src">'+esc(k.konto)+"</span>":"")));});
    else if(cs.error)cCal.appendChild(el("div","quiet","Kalender-Quelle nicht erreichbar — Zweitkonto prüfen, privat über /aios-dashboard neu ziehen."));
    else if(!cs.pulled)cCal.appendChild(el("div","quiet","Privater Kalender noch nicht gezogen — über /aios-dashboard aktualisieren."));
    else cCal.appendChild(el("div","quiet","Keine Termine — freier Tag zum Arbeiten."));
    cCal.appendChild(el("div","side-note","Privater Kalender wird über /aios-dashboard aktualisiert (Connector), Zweitkonto-Kalender bei jedem Aktualisieren."));
  }
  side.appendChild(cCal);

  var brSec=A.DATA.branding,brData=(brSec&&brSec.data)||{};
  if(brSec&&brSec.present&&brData.available!==false){
    var draftsArr=(brData.pipeline&&brData.pipeline.drafts)||[];
    var slotItem=nextContentSlot(draftsArr);
    var cContent=el("div","side-card heute-mod");
    cContent.innerHTML='<h4>Content <a class="goto" href="#/content">öffnen →</a></h4>';
    cContent.appendChild(el("div","mailrow",'<span class="c mono">'+draftsArr.length+'</span><span>Entwurf'+(draftsArr.length===1?"":"e")+' in der Pipeline</span>'));
    if(slotItem)cContent.appendChild(el("div","appt",'<span class="t mono">'+esc(fmtSlot(slotItem.slot))+'</span><span>nächster geplanter Slot</span>'));
    else cContent.appendChild(el("div","quiet","Kein Slot geplant."));
    side.appendChild(cContent);
  }

  var c3=el("div","side-card heute-mod",'<h4>Aktivste Projekte <a class="goto" href="#/projekte">alle →</a></h4>');
  // Echte Aktivität: nach tatsächlichen Sitzungen (7 Tage) ranken, nicht nach STATE.md-mtime.
  var worked=projects().filter(function(p){return(p.sessions_7d||0)>0;}).sort(function(a,b){return(b.sessions_7d||0)-(a.sessions_7d||0);});
  var act=(worked.length?worked:projects().filter(function(p){return p.ampel!=="rot";}).sort(function(a,b){return(a.days_since_change||0)-(b.days_since_change||0);})).slice(0,3);
  if(!act.length)c3.appendChild(el("div","quiet","Keine aktiven Projekte."));
  act.forEach(function(p){
    var open=(p.pending_todos||[]).filter(function(t){return!t.checked;});
    var sub,cls="mp-sub";
    if(!p.template_conform){sub=p.state_path?"Abweichendes Format":"Keine Status-Datei";cls="mp-sub fmtwarn";}          // erklaert, warum keine Aufgaben
    else if((p.sessions_7d||0)>0){sub=p.sessions_7d+" Sitzung"+(p.sessions_7d===1?"":"en")+" · 7 Tage";}
    else{sub=open.length?esc(open[0].text):"nichts offen";}
    var showCount=p.template_conform&&open.length;
    // Rote Zahl = Anzahl offener Aufgaben dieses Projekts — jetzt mit sichtbarem Label + Title.
    var cnt=showCount?'<span class="mp-count-wrap" title="'+open.length+' offene Aufgabe'+(open.length===1?"":"n")+'"><span class="mp-count">'+open.length+'</span><span class="mp-count-lbl">offen</span></span>':"";
    var r=el("a","mini-proj");r.href="#/projekte/"+encodeURIComponent(p.slug);
    r.innerHTML='<span class="dot '+(isActive(p)?"active":"dormant")+'"></span><span class="mp-body"><span class="mp-name">'+esc(p.slug)+'</span><span class="'+cls+'">'+sub+'</span></span>'+cnt;
    c3.appendChild(r);
  });
  side.appendChild(c3);
}
function renderSysline(){
  var box=$("sysLine");
  var chk=A.DATA["system-check"];
  var note=stateNote(chk,"System-Check");
  if(note){box.innerHTML='<span class="dot dormant"></span><span>System-Status unbekannt — Daten noch nicht eingesammelt.</span><a class="goto" href="#/system">Details →</a>';return;}
  var open=A.groupIssues(chk.data.checks).issues.filter(function(i){return!A.isRead(A.issueKey(i));});
  var hasFail=open.some(function(i){return i.tone==="fail";});
  var txt=hasFail?"Etwas braucht deine Aufmerksamkeit.":(open.length?"Dein System läuft — "+(open.length===1?"ein Hinweis":open.length+" Hinweise")+", nichts Dringendes.":"Dein System läuft rund.");
  box.innerHTML='<span class="dot '+(hasFail?"fail":(open.length?"warn":"ok"))+'"></span><span class="sysline-txt">'+esc(txt)+'</span><span class="sysline-sub">'+chk.data.checks.length+' Punkte automatisch geprüft</span><a class="goto" href="#/system">Details →</a>';
}
A.pages=A.pages||{};
A.pages.dashboard=function(){renderKpis();A.renderBrain(A.DATA["vault-stats"]);renderFocus();renderDashSide();renderSysline();};

/* ---------- Projekte ---------- */
var curProj=null;
A.pages.projekte=function(arg){
  curProj=arg||null;
  $("projList").style.display=curProj?"none":"block";
  $("projDetail").style.display=curProj?"block":"none";
  if(curProj)renderProjDetail(curProj);else renderProjList();
};
function renderProjList(){
  var grid=$("projGrid"),rest=$("restList"),rows=$("restRows"),cnt=$("projCount"),strip=$("projStrip");
  strip.innerHTML="";
  var note=stateNote(A.DATA.portfolio,"Projekte");
  if(note){grid.innerHTML="";var c=el("div","card");c.style.gridColumn="1/-1";c.appendChild(noteEl(note));grid.appendChild(c);rest.style.display="none";cnt.textContent="";return;}
  var ps=projects();
  function actSort(a,b){var d=(b.sessions_7d||0)-(a.sessions_7d||0);return d!==0?d:(a.days_since_change||0)-(b.days_since_change||0);}
  var act=ps.filter(isActive).sort(actSort);
  var ruht=ps.filter(function(p){return!isActive(p);}).sort(function(a,b){return(a.days_since_change||0)-(b.days_since_change||0);});
  var openT=0;ps.forEach(function(p){(p.pending_todos||[]).forEach(function(t){if(!t.checked)openT++;});});
  function tile(n,l,s,alert){var t=el("div","ktile"+(alert?" alert":""));t.innerHTML='<div class="n">'+n+'</div><div class="l">'+l+'</div>'+(s?'<div class="s">'+s+"</div>":"");strip.appendChild(t);}
  tile(nf(act.length),"Aktiv","mit Sitzungen · 7 Tage");
  tile(nf(ruht.length),"Ruhend","keine Sitzungen · 7 Tage");
  tile(nf(openT),"Offene Aufgaben","aus den Status-Dateien");
  tile(nf(A.dueTodos().length),"Heute fällig","mit Deadline",A.dueTodos().length>0);
  cnt.textContent=act.length+" aktiv · "+ruht.length+" ruhend";
  grid.innerHTML="";
  if(!ps.length)grid.innerHTML='<div class="card" style="grid-column:1/-1"><div class="state-note missing"><span class="sym fail">✕</span><span>Keine Projekte gefunden.<span class="fixhint">Erstes Projekt über /new-project anlegen, dann erscheint es hier automatisch.</span></span></div></div>';
  act.forEach(function(p){
    var card=el("a","proj");card.href="#/projekte/"+encodeURIComponent(p.slug);
    var open=(p.pending_todos||[]).filter(function(t){return!t.checked;}).length;
    var sess=p.sessions_7d||0;
    var h='<div class="proj-head"><h3><span class="dot '+(isActive(p)?"active":"dormant")+'"></span><span class="nm">'+esc(p.slug)+'</span></h3><span class="when">'+esc(daysLabel(p))+'</span></div>';
    if(!p.template_conform)h+='<div class="proj-note">'+(p.state_path?"Status-Datei im alten Format — Aufgaben erscheinen nach der Umstellung.":"Noch keine Status-Datei. Aufgaben erscheinen, sobald eine angelegt ist.")+'</div>';
    else{
      var next=(p.pending_todos||[]).filter(function(t){return!t.checked;})[0];
      h+=next?'<div class="proj-next"><span class="nx">Nächster Schritt</span>'+esc(next.text)+"</div>":'<div class="proj-note ok">Keine offenen Aufgaben ✓</div>';
    }
    // Ehrliches Aktivitäts-Signal: frische Status-Datei, aber keine echten Sitzungen
    if(sess===0&&(p.days_since_change!=null&&p.days_since_change<4))h+='<div class="proj-note" style="padding:2px 0 0;color:var(--muted)">Status-Datei kürzlich berührt, aber keine Sitzungen in 7 Tagen.</div>';
    var manualTag=p.manual_status==="aktiv"?'<span class="manual-tag" title="Manuell auf aktiv gesetzt">manuell</span>':"";
    h+='<div class="proj-foot"><span class="opencount">'+(sess>0?sess+" Sitzung"+(sess===1?"":"en")+" · 7T":(p.template_conform?(open?open+" offen":"alles erledigt"):"—"))+manualTag+'</span><span class="foot-right"><button class="statustog" data-to="ruhend" title="Auf ruhend setzen — verschwindet aus „In Arbeit“">auf ruhend</button><span class="openlink">Öffnen →</span></span></div>';
    card.innerHTML=h;
    var stb=card.querySelector(".statustog");if(stb)stb.addEventListener("click",function(e){e.preventDefault();e.stopPropagation();setProjStatus(p.slug,"ruhend");});
    grid.appendChild(card);
  });
  if(ruht.length){
    rest.style.display="block";rows.innerHTML="";
    ruht.forEach(function(p){
      var open=(p.pending_todos||[]).filter(function(t){return!t.checked;}).length;
      var r=el("a","rest-row");r.href="#/projekte/"+encodeURIComponent(p.slug);
      var right=p.template_conform?(open?'<span class="chip">'+open+" offen</span>":'<span class="chip">nichts offen</span>'):('<span class="chip old">'+(p.state_path?"altes Format":"keine Status-Datei")+'</span>');
      var manualTag=p.manual_status==="ruhend"?'<span class="manual-tag" title="Manuell auf ruhend gesetzt">manuell</span>':"";
      r.innerHTML='<span class="dot dormant"></span><span class="nm">'+esc(p.slug)+'</span><span class="when">'+esc(daysLabel(p))+"</span>"+manualTag+right+'<button class="statustog" data-to="aktiv" title="Wieder als aktiv führen">aktivieren</button><span class="openlink">→</span>';
      var atb=r.querySelector(".statustog");if(atb)atb.addEventListener("click",function(e){e.preventDefault();e.stopPropagation();setProjStatus(p.slug,"aktiv");});
      rows.appendChild(r);
    });
  }else rest.style.display="none";
}
function renderProjDetail(slug){
  var box=$("projDetail");
  var p=projBySlug(slug);
  if(!p){box.innerHTML='<a class="back" href="#/projekte">← Alle Projekte</a><div class="card" style="margin-top:16px"><div class="state-note">Projekt nicht gefunden.</div></div>';return;}
  var open=(p.pending_todos||[]).filter(function(t){return!t.checked;}).length;
  var mo=p.manual_status;
  /* Gleiches Chip-Muster wie die Filter auf Inbox, Skills und Content: eine Reihe
     runder Buttons, der aktive traegt .on. */
  function segBtn(val,lbl,tip){var on=(val==="auto")?!mo:(mo===val);return '<button class="chip-btn'+(on?" on":"")+'" data-status="'+val+'" title="'+esc(tip)+'">'+lbl+'</button>';}
  var seg='<div class="chips" role="group" aria-label="Aktiv/Ruhend">'+segBtn("auto","Auto","Folgt automatisch den Sitzungen der letzten 7 Tage")+segBtn("aktiv","Aktiv","Immer als aktiv führen")+segBtn("ruhend","Ruhend","Als ruhend führen")+'</div>';
  var h='<a class="back" href="#/projekte">← Alle Projekte</a>'+
    '<div class="pd-head"><h2><span class="dot '+(isActive(p)?"active":"dormant")+'"></span>'+esc(p.slug)+'</h2><span class="when">'+esc(daysLabel(p))+'</span><div class="pd-actions">'+seg+'</div></div>';
  if((p.todos_outside_section||0)>0){
    h+='<div class="card scatter-note" style="margin-bottom:16px"><div class="scatter-h"><span class="dot warn"></span><b>'+p.todos_outside_section+' Aufgabe'+(p.todos_outside_section===1?"":"n")+' außerhalb der Liste</b></div><p class="scatter-p">Diese Punkte stehen in der Status-Datei außerhalb von <span class="mono">### Pending Todos</span> und erscheinen daher nicht in der Liste unten. Claude zieht sie verlustfrei rein.</p><button class="mini primary" data-scatterfix>Einsortieren lassen</button> <span class="mini-hint">kopiert die fertige Anweisung für Claude</span></div>';
  }
  if(!p.template_conform){
    if(p.state_path){
      h+='<div class="card"><div class="proj-note" style="padding:4px 0 12px">Die Status-Datei dieses Projekts nutzt noch ein altes Format — Aufgaben können erst nach der Umstellung angezeigt und abgehakt werden. Claude stellt sie automatisch um, ohne Datenverlust.</div><button class="mini primary" data-migrate>Umstellung an Claude übergeben</button> <span class="mini-hint">kopiert die fertige Anweisung — in Claude einfügen, Enter, fertig</span></div>';
    }else{
      h+='<div class="card"><div class="proj-note" style="padding:4px 0 12px">Für dieses Projekt gibt es noch keine Status-Datei (STATE.md). Aufgaben erscheinen hier, sobald eine angelegt ist.</div></div>';
    }
  }else{
    var td=p.pending_todos||[];
    var openN=td.filter(function(x){return!x.checked;}).length;
    h+='<div class="card"><div class="pd-sub">'+(td.length?openN+" von "+td.length+" Aufgaben offen":"Keine Aufgaben in der Status-Datei.")+'<span class="undo" style="display:inline-block;margin-left:auto">↩ Rückgängig</span></div>'+(td.length?clusteredTodosHtml(td):"")+"</div>";
  }
  box.innerHTML=h;
  wireTodos(box,slug);
  var mig=box.querySelector("[data-migrate]");if(mig)mig.addEventListener("click",function(){copyText(migrateFixFor(slug),mig);toast("Anweisung kopiert — in Claude einfügen und starten.");});
  var scf=box.querySelector("[data-scatterfix]");if(scf)scf.addEventListener("click",function(){copyText(scatterFixFor(slug),scf);toast("Anweisung kopiert — in Claude einfügen und starten.");});
  box.querySelectorAll(".pd-actions .chip-btn").forEach(function(b){b.addEventListener("click",function(){setProjStatus(slug,b.getAttribute("data-status"));});});
  var undo=box.querySelector(".undo");if(undo)undo.addEventListener("click",function(){undoTodo(slug);});
}

/* ---------- Aufgaben ---------- */
/* Native HTML5-Drag&Drop, keine Fremd-Lib: der Griff (⠿) ist draggable, die
   Gruppe wird live umsortiert, beim Loslassen wird die Reihenfolge gespeichert. */
function getDragAfter(container,y){
  var els=Array.prototype.slice.call(container.querySelectorAll(".tg:not(.dragging)"));
  var closest={offset:-Infinity,el:null};
  els.forEach(function(child){var box=child.getBoundingClientRect();var offset=y-box.top-box.height/2;if(offset<0&&offset>closest.offset){closest={offset:offset,el:child};}});
  return closest.el;
}
function wireDnd(tgList){
  var dragging=null;
  tgList.querySelectorAll(".draghandle").forEach(function(hd){
    var g=hd.closest(".tg");
    hd.addEventListener("dragstart",function(e){dragging=g;g.classList.add("dragging");try{e.dataTransfer.effectAllowed="move";e.dataTransfer.setData("text/plain",g.getAttribute("data-slug")||"");}catch(_){}});
    hd.addEventListener("dragend",function(){if(!dragging)return;dragging.classList.remove("dragging");dragging=null;var ord=Array.prototype.slice.call(tgList.querySelectorAll(".tg")).map(function(x){return x.getAttribute("data-slug");});setOrder(ord);});
  });
  tgList.addEventListener("dragover",function(e){if(!dragging)return;e.preventDefault();var after=getDragAfter(tgList,e.clientY);if(after==null)tgList.appendChild(dragging);else tgList.insertBefore(dragging,after);});
}
var openGroups=null;
A.pages.aufgaben=function(arg){
  var wrap=$("tasksWrap");wrap.innerHTML="";
  var note=stateNote(A.DATA.portfolio,"Aufgaben");
  if(note){var c=el("div","card");c.appendChild(noteEl(note));wrap.appendChild(c);return;}
  var ps=projects();
  var order=(A.DATA.portfolio&&A.DATA.portfolio.data&&A.DATA.portfolio.data.order)||[];
  var withTasks=ps.filter(function(p){return p.template_conform&&(p.pending_todos||[]).length;});
  // Gespeicherte manuelle Reihenfolge (Drag & Drop) zuerst, sonst nach Aktualität.
  withTasks.sort(function(a,b){
    var ra=a.manual_status==="ruhend"?1:0,rb=b.manual_status==="ruhend"?1:0;
    if(ra!==rb)return ra-rb;
    var ia=order.indexOf(a.slug),ib=order.indexOf(b.slug);
    if(ia!==-1||ib!==-1){if(ia===-1)return 1;if(ib===-1)return -1;return ia-ib;}
    return(a.days_since_change||0)-(b.days_since_change||0);
  });
  var oldFmt=ps.filter(function(p){return!p.template_conform;});
  // Fällig heute
  var due=dueTodos();
  if(due.length){
    var ds=el("div","due-sec");
    ds.appendChild(el("div","ib-title",'<span class="dot fail"></span>Heute fällig · '+due.length));
    var dc=el("div","card");
    var ul=el("ul","todos");
    due.forEach(function(x){
      var li=el("li",null,'<input type="checkbox" class="chk" data-hash="'+esc(x.t.hash)+'" data-slug="'+esc(x.p)+'"/><span class="txt">'+esc(x.t.text)+'<span class="due-proj">'+esc(x.p)+'</span><span class="dl mono">'+esc(fmtDl(x.t.deadline))+"</span></span>");
      li.querySelector(".chk").addEventListener("change",function(){toggleTodo(x.p,x.t.hash,this);});
      ul.appendChild(li);
    });
    dc.appendChild(ul);ds.appendChild(dc);wrap.appendChild(ds);
  }
  // Hinweis: offene Aufgaben außerhalb der ### Pending Todos Sektion (stiller Fehler).
  var scattered=ps.filter(function(p){return p.template_conform&&(p.todos_outside_section||0)>0;});
  if(scattered.length){
    var sc=el("div","scatter-note card");
    var scRows=scattered.map(function(p){return '<div class="scatter-row"><span class="nm">'+esc(p.slug)+'</span><span class="cnt">'+p.todos_outside_section+' außerhalb</span><button class="mini primary" data-scatter="'+esc(p.slug)+'">Einsortieren lassen</button></div>';}).join("");
    sc.innerHTML='<div class="scatter-h"><span class="dot warn"></span><b>Aufgaben außerhalb der erfassten Liste</b></div><p class="scatter-p">In '+(scattered.length===1?"einem Projekt stehen":scattered.length+" Projekten stehen")+' offene Punkte (<span class="mono">- [ ]</span>) außerhalb der Sektion <span class="mono">### Pending Todos</span> und tauchen hier nicht auf. Claude zieht sie verlustfrei in die Liste.</p><div class="scatter-list">'+scRows+'</div>';
    wrap.appendChild(sc);
    sc.querySelectorAll("[data-scatter]").forEach(function(b){b.addEventListener("click",function(){copyText(scatterFixFor(b.getAttribute("data-scatter")),b);toast("Anweisung kopiert — in Claude einfügen und starten.");});});
  }
  // Gruppen je Projekt (per Drag & Drop am Griff sortierbar)
  if(openGroups===null){openGroups={};withTasks.forEach(function(p,i){openGroups[p.slug]=i===0||(p.pending_todos||[]).some(function(t){return!t.checked&&t.deadline;});});}
  if(arg)openGroups[arg]=true;
  wrap.appendChild(el("div","ib-title",'<span class="dot active"></span>Nach Projekt · '+withTasks.length+'<span class="dnd-hint">am Griff ⠿ ziehen zum Sortieren</span>'));
  var tgList=el("div","tg-list");
  withTasks.forEach(function(p){
    var open=(p.pending_todos||[]).filter(function(t){return!t.checked;}).length;
    var clustered=(p.pending_todos||[]).some(function(t){return t.cluster;});
    var clusterHint=clustered?'<span class="tg-clusters-flag">Themen-Cluster</span>':"";
    var scatterFlag=(p.todos_outside_section||0)>0?'<span class="tg-scatter-flag" title="Aufgaben außerhalb der erfassten Liste">'+p.todos_outside_section+' außerhalb</span>':"";
    var g=el("div","tg"+(openGroups[p.slug]?" open":""));
    g.setAttribute("data-slug",p.slug);
    var ruhendTag=p.manual_status==="ruhend"?'<span class="manual-tag" title="Manuell auf ruhend gesetzt">manuell</span>':"";
    g.innerHTML='<div class="tg-head"><span class="draghandle" draggable="true" title="Ziehen zum Sortieren">⠿</span><span class="arr">▶</span><span class="nm"><span class="dot '+(isActive(p)?"active":"dormant")+'"></span>'+esc(p.slug)+ruhendTag+'</span><span class="cnt">'+(open?open+" offen":"alles erledigt")+" · "+esc(daysLabel(p))+clusterHint+scatterFlag+'</span></div><div class="tg-body">'+clusteredTodosHtml(p.pending_todos||[])+'<div class="tg-foot"><a href="#/projekte/'+encodeURIComponent(p.slug)+'">Zum Projekt →</a><span class="undo" style="margin-left:auto">↩ Rückgängig</span></div></div>';
    g.querySelector(".tg-head").addEventListener("click",function(ev){if(ev.target.closest(".draghandle"))return;openGroups[p.slug]=!openGroups[p.slug];g.classList.toggle("open",openGroups[p.slug]);});
    var body=g.querySelector(".tg-body");
    wireTodos(body,p.slug);
    body.querySelector(".undo").addEventListener("click",function(){undoTodo(p.slug);});
    tgList.appendChild(g);
  });
  wrap.appendChild(tgList);
  wireDnd(tgList);
  if(oldFmt.length){
    // Zwei getrennte Faelle (V12): "altes Format" nur bei vorhandener, nicht
    // konformer Status-Datei; ohne Datei gibt es nichts umzustellen.
    var fmtProjs=oldFmt.filter(function(p){return p.state_path;});
    var noFile=oldFmt.filter(function(p){return!p.state_path;});
    var parts=[];
    if(fmtProjs.length)parts.push(fmtProjs.length+" Projekt"+(fmtProjs.length===1?" führt seine":"e führen ihre")+" Status-Datei noch im alten Format ("+fmtProjs.map(function(p){return esc(p.slug);}).join(", ")+"), die Aufgaben erscheinen hier nach der Umstellung");
    if(noFile.length)parts.push(noFile.length+" Projekt"+(noFile.length===1?" hat":"e haben")+" noch keine Status-Datei ("+noFile.map(function(p){return esc(p.slug);}).join(", ")+"), Aufgaben erscheinen, sobald eine angelegt ist");
    var hint=el("div","hint-line",parts.join(". ")+". Details auf der <a href=\"#/system\">Zustand-Seite</a>.");
    wrap.appendChild(hint);
  }
};

/* ---------- Inbox ---------- */
var inboxFilter="alle";
var SRC={gmail:{label:"Gmail"},slack:{label:"Slack"},fathom:{label:"Fathom"},vault:{label:"Second Brain"}};
/* Konto-Key aus dem von-Suffix nach dem letzten "·" ("· privat" = Hauptkonto,
   jedes andere Suffix, z. B. "· gws", "· zweitkonto" = Zweitkonto). Nutzerneutral:
   kein Konto-Name ist hardcodiert. */
function accountOf(i){
  if(i.source!=="gmail")return null;
  var v=i.von||"";
  var idx=v.lastIndexOf("·");
  var suf=idx===-1?"":v.slice(idx+1).trim().toLowerCase();
  return(suf&&suf!=="privat")?suf:"privat";
}
/* Konto-Label aus A.DATA.inbox.data.accounts ableiten: erster Eintrag = Hauptkonto,
   zweiter = Zweitkonto (unabhängig davon, wie das Suffix im "von"-Feld heißt). */
function acctLabel(key){
  var accs=(A.DATA.inbox&&A.DATA.inbox.data&&A.DATA.inbox.data.accounts)||[];
  if(key==="privat")return(accs[0]&&accs[0].label)||"Gmail privat";
  return(accs[1]&&accs[1].label)||"Gmail (Zweitkonto)";
}
function srcLabel(i){var a=accountOf(i);if(a)return acctLabel(a);return(SRC[i.source]||{label:i.source}).label;}
function itemKey(i){var a=accountOf(i);return a?a:i.source;}
function actLabel(i){
  if(i.aktion.indexOf("/")===0)return"Jetzt einsortieren lassen";
  if(i.source==="gmail")return"Antwort entwerfen";
  return"An Claude übergeben";
}
A.pages.inbox=function(){
  var wrap=$("inboxWrap");wrap.innerHTML="";
  var note=stateNote(A.DATA.inbox,"Inbox","Der „Aktualisieren“-Knopf holt nur Zweitkonto + Systemdaten (headless, ohne Tokens). Frisches privates Postfach kommt über /aios-dashboard in einer Session.");
  if(note){wrap.appendChild(function(){var c=el("div","card");c.appendChild(noteEl(note));return c;}());return;}
  var items=(A.DATA.inbox.data&&A.DATA.inbox.data.items)||[];
  var accounts=(A.DATA.inbox.data&&A.DATA.inbox.data.accounts)||[];
  // Frische + Konto-Status (privat/Zweitkonto getrennt, Auth-Fehler sichtbar)
  var meta=el("div","ib-meta");
  var stand=A.DATA.inbox.updated_at?new Date(A.DATA.inbox.updated_at).toLocaleTimeString("de-DE",{hour:"2-digit",minute:"2-digit"}):null;
  var parts=[];
  if(stand)parts.push('<span class="ib-stand">Stand '+esc(stand)+" Uhr</span>");
  accounts.forEach(function(a){
    var err=a.status&&a.status!=="ok";
    parts.push('<span class="ib-acc'+(err?" err":"")+'">'+esc(a.label||a.email)+": "+(err?"Quelle nicht erreichbar":(a.unread||0)+" ungelesen")+"</span>");
  });
  if(parts.length){meta.innerHTML=parts.join('<span class="ib-dot">·</span>');wrap.appendChild(meta);}
  if(accounts.some(function(a){return a.status&&a.status!=="ok";}))
    wrap.appendChild(el("div","ib-hint","Ein Konto ließ sich nicht abrufen. Privates Postfach über <b>/aios-dashboard</b> neu ziehen (braucht aktive claude.ai-Anmeldung)."));
  wrap.appendChild(el("div","ib-note","Der „Aktualisieren“-Knopf holt nur Zweitkonto + Systemdaten (headless, ohne Tokens). Frisches <b>privates</b> Postfach kommt über <b>/aios-dashboard</b> in einer Session."));
  var chips=el("div","chips");
  // Gmail-Konto-Keys aus den tatsächlichen Items ableiten (Hauptkonto zuerst), statt fest zu verdrahten.
  var gmailKeys=[];
  items.forEach(function(i){if(i.source==="gmail"){var k=itemKey(i);if(gmailKeys.indexOf(k)===-1)gmailKeys.push(k);}});
  gmailKeys.sort(function(a,b){return(a==="privat"?0:1)-(b==="privat"?0:1);});
  var keys=["alle"].concat(gmailKeys)
    .concat(Object.keys(SRC).filter(function(s){return s!=="gmail"&&items.some(function(i){return i.source===s;});}));
  keys.forEach(function(s){
    var n=s==="alle"?items.length:items.filter(function(i){return itemKey(i)===s;}).length;
    var lbl=s==="alle"?"Alle":(gmailKeys.indexOf(s)!==-1?acctLabel(s):(SRC[s]||{label:s}).label);
    var b=el("button","chip-btn"+(inboxFilter===s?" on":""),lbl+' <span class="mono">'+n+"</span>");
    b.addEventListener("click",function(){inboxFilter=s;A.pages.inbox();});
    chips.appendChild(b);
  });
  wrap.appendChild(chips);
  var show=items.filter(function(i){return inboxFilter==="alle"||itemKey(i)===inboxFilter;});
  var groups=[["handeln","Brauchen deine Handlung"],["warten","Warten auf andere"],["kenntnis","Nur zur Kenntnis"]];
  groups.forEach(function(g){
    var list=show.filter(function(i){return i.prio===g[0];});
    if(!list.length)return;
    var sec=el("div","ib-group");
    sec.appendChild(el("div","ib-title",'<span class="dot '+(g[0]==="handeln"?"fail":g[0]==="warten"?"warn":"dormant")+'"></span>'+g[1]+" · "+list.length));
    list.forEach(function(i){
      var rkey="ib:"+i.id;
      var row=el("div","ib-row card"+(A.isRead(rkey)?" read":""));
      row.title="Klick markiert als gelesen";
      row.innerHTML='<div class="ib-main"><div class="ib-head"><span class="ib-src">'+esc(srcLabel(i))+'</span><span class="ib-from">'+esc(i.von)+'</span><span class="ib-age">'+esc(i.alter)+'</span></div><div class="ib-subj">'+esc(i.titel)+'</div><div class="ib-sum">'+esc(i.kurz)+"</div>"+
        (i.aktion?'<div class="iact" style="margin-top:10px"><button class="mini primary" data-act>'+esc(actLabel(i))+'</button><span class="mini-hint">'+(i.aktion.indexOf("/")===0?esc(i.aktion):"kopiert eine fertige Anweisung für Claude")+"</span></div>":"")+"</div>";
      var b=row.querySelector("[data-act]");
      if(b)b.addEventListener("click",function(e){e.stopPropagation();copyText(i.aktion,b);toast("Kopiert — in Claude einfügen und starten.");});
      // Klick auf die Zeile (nicht auf den Aktions-Button) simuliert „gelesen" und zaehlt das Badge runter.
      row.addEventListener("click",function(e){if(e.target.closest("[data-act]"))return;var nowRead=!A.isRead(rkey);A.markRead(rkey,nowRead);row.classList.toggle("read",nowRead);A.updateNavBadges();});
      sec.appendChild(row);
    });
    wrap.appendChild(sec);
  });
  if(!show.length)wrap.appendChild(el("div","quiet","Nichts in dieser Ansicht — alles verarbeitet."));
};
A.dueTodos=dueTodos;
})(window.AIOS);
