/* AIOS — Seiten: Skills, Commands, Automationen, Nutzung, System + Shell/Router */
(function(A){
"use strict";
var $=A.$,esc=A.esc,nf=A.nf,el=A.el,toast=A.toast,copyText=A.copyText,stateNote=A.stateNote,noteEl=A.noteEl;

/* ---------- Skills ---------- */
A.pages.skills=function(){
  var wrap=$("skillsWrap");wrap.innerHTML="";
  var note=stateNote(A.DATA.skills,"Skills");
  if(note){var c=el("div","card");c.appendChild(noteEl(note));wrap.appendChild(c);return;}
  var sk=Array.isArray(A.DATA.skills.data&&A.DATA.skills.data.skills)?A.DATA.skills.data.skills:[];
  var max=Math.max.apply(null,sk.map(function(s){return s.uses;}).concat([1]));
  // "aktiv" fehlt in Daten aelterer Collector-Staende: dann gilt alles als aktiv.
  var hasState=sk.some(function(s){return typeof s.aktiv==="boolean";});
  var aktivOf=function(s){return s.aktiv!==false;};
  // Filterzeile im Muster der uebrigen Seiten (Postfach, Leads, Content):
  // Suchfeld plus Chips mit Zaehler, aktiver Chip dunkel gefuellt.
  var anz={alle:sk.length,
           aktiv:sk.filter(aktivOf).length,
           aus:sk.filter(function(s){return !aktivOf(s);}).length};
  var filt=el("div","chips skill-filter");
  filt.innerHTML='<input type="search" id="skillFilter" class="filter-select filter-search" placeholder="Suchen…" autocomplete="off">'+
    (hasState?'<span class="chips" id="skillState">'+
      [["alle","Alle"],["aktiv","Aktiv"],["aus","Deaktiviert"]].map(function(f){
        return '<button class="chip-btn'+(f[0]==="alle"?" on":"")+'" data-state="'+f[0]+'">'+f[1]+
               ' <span class="mono">'+nf(anz[f[0]])+"</span></button>";
      }).join("")+"</span>":"");
  wrap.appendChild(filt);
  [["Fundament","Der Kern-Workflow des Systems, wie er ausgeliefert wird."],["Weitere","Alles andere, was in deinem Setup installiert ist."]].forEach(function(g){
    var list=sk.filter(function(s){return s.gruppe===g[0];});
    if(!list.length)return;
    // Meistgenutzt zuerst. Array.sort ist stabil und der Collector liefert bei
    // Gleichstand alphabetisch, dadurch springen Kacheln nicht von Lauf zu Lauf.
    list.sort(function(a,b){return(b.uses||0)-(a.uses||0);});
    wrap.appendChild(el("div","grp-title",g[0]+' <span class="grp-count mono">('+nf(list.length)+')</span> <span class="grp-sub">'+g[1]+"</span>"));
    var grid=el("div","tile-grid");
    list.forEach(function(s){
      var an=aktivOf(s);
      var t=el("div","card tile"+(an?"":" tile-off"));
      t.setAttribute("data-key",((s.cmd||"")+" "+(s.titel||"")).toLowerCase());
      t.setAttribute("data-state",an?"aktiv":"aus");
      // Punkt-Sprache wie bei Projekt-Ampeln und Postfach-Gruppen: gefuellt = da,
      // hohler Ring = ruht. Traegt den Unterschied auch dort, wo die gedaempfte
      // ok-Farbe allein zu wenig Kontrast haette.
      var tag=hasState
        ? '<span class="tile-tag '+(an?"is-on":"is-off")+'" title="'+
          (an?"Steht in dieser Sitzung zur Verfügung.":"In den Einstellungen deaktiviert, steht in dieser Sitzung nicht zur Verfügung.")+
          '"><span class="dot '+(an?"ok":"dormant")+'"></span>'+(an?"aktiv":"deaktiviert")+"</span>"
        : "";
      // Lange Namen werden per CSS gekuerzt, der volle Befehl bleibt im title
      // und im Kopieren-Knopf erhalten.
      t.innerHTML='<div class="tile-head"><span class="cmd mono" title="'+esc(s.cmd)+'">'+esc(s.cmd)+'</span>'+tag+
        '<button class="mini" data-copy>Kopieren</button></div><div class="tile-title">'+esc(s.titel)+'</div><div class="tile-desc">'+esc(s.desc)+'</div><div class="tile-bar"><span class="bar-track"><span class="bar-fill" style="width:'+Math.round(s.uses/max*100)+'%"></span></span><span class="bar-n mono">'+s.uses+"× / 7 Tage</span></div>";
      t.querySelector("[data-copy]").addEventListener("click",function(){copyText(s.cmd,this);});
      grid.appendChild(t);
    });
    wrap.appendChild(grid);
  });
  wrap.appendChild(el("div","hint-line","Faustregel: Jeder Freitext-Auftrag, der zum dritten Mal auftaucht, wird mit <b>/skill-creator</b> zum eigenen Skill."));
  // Reines Ein-/Ausblenden der schon gebauten Kacheln, kein Neuaufbau.
  var fi=$("skillFilter"),seg=$("skillState"),state="alle";
  function anwenden(){
    var q=(fi&&fi.value.trim().toLowerCase())||"";
    wrap.querySelectorAll(".tile-grid").forEach(function(grid){
      var shown=0;
      grid.querySelectorAll(".tile").forEach(function(t){
        var hit=(!q||(t.getAttribute("data-key")||"").indexOf(q)>=0)&&
                (state==="alle"||t.getAttribute("data-state")===state);
        t.style.display=hit?"":"none";if(hit)shown++;
      });
      var title=grid.previousElementSibling;
      if(title&&title.classList.contains("grp-title"))title.style.display=shown?"":"none";
      grid.style.display=shown?"":"none";
    });
  }
  if(fi)fi.addEventListener("input",anwenden);
  if(seg)seg.addEventListener("click",function(ev){
    var b=ev.target.closest("button[data-state]");if(!b)return;
    state=b.getAttribute("data-state");
    seg.querySelectorAll("button").forEach(function(x){x.classList.toggle("on",x===b);});
    anwenden();
  });
};

/* ---------- Automationen ---------- */
// Badge/Dot-Zuordnung fuer den 3-wertigen Status. Unbekannte/aeltere Werte
// (z.B. das fruehere "prüfen") fallen defensiv auf "warn" zurueck.
function autoBadge(status){
  if(status==="ok")return{cls:"ok",label:"gelaufen"};
  if(status==="fehler")return{cls:"fail",label:"Fehler"};
  if(status==="ueberfaellig")return{cls:"warn",label:"überfällig"};
  return{cls:"warn",label:"prüfen"};
}
function autoRunDot(status){
  if(status==="ok")return"ok";
  if(status==="fehler")return"fail";
  return"dormant";   // "laeuft" oder Unbekanntes: hohler Ring wie bei ruhenden Zustaenden
}
function autoRunTs(ts){
  var m=/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(ts||"");
  return m?m[3]+"."+m[2]+". "+m[4]+":"+m[5]:"";
}
function autoRunTitle(r){
  if(r.status==="laeuft")return"läuft gerade";
  var lbl=r.status==="ok"?"gelaufen":(r.status==="fehler"?"Fehler":r.status);
  return autoRunTs(r.ts)+" · "+lbl;
}
function autoTrunc(s,n){s=String(s||"");return s.length>n?s.slice(0,n-1)+"…":s;}
A.pages.automationen=function(){
  var wrap=$("autoWrap");wrap.innerHTML="";
  var note=stateNote(A.DATA.automationen,"Automationen");
  if(note){var c=el("div","card");c.appendChild(noteEl(note));wrap.appendChild(c);return;}
  var ts=Array.isArray(A.DATA.automationen.data&&A.DATA.automationen.data.tasks)?A.DATA.automationen.data.tasks:[];
  var grid=el("div","tile-grid");
  ts.forEach(function(t){
    var c=el("div","card tile");
    var badge=autoBadge(t.status);
    // Verlauf: neueste zuerst aus den Daten, hier chronologisch (alt→neu) dargestellt.
    var verlauf=(t.verlauf||[]).slice(0,7).slice().reverse();
    var runhistHtml=verlauf.length
      ? '<div class="runhist">'+verlauf.map(function(r){
          return '<span class="dot '+autoRunDot(r.status)+'" title="'+esc(autoRunTitle(r))+'"></span>';
        }).join("")+"</div>"
      : "";
    var errHtml="";
    if(t.status==="fehler"){
      errHtml='<div class="auto-err">'+esc(autoTrunc(t.fehler_text,120))+
        (t.zuletzt_erfolgreich?" · zuletzt erfolgreich: "+esc(t.zuletzt_erfolgreich):"")+"</div>";
    }
    var okNoteHtml="";
    if(t.status==="ok"&&t.zuletzt_erfolgreich&&t.zuletzt_erfolgreich!==t.zuletzt){
      okNoteHtml='<div class="quiet" style="font-size:11.5px;padding:2px 0 0">zuletzt erfolgreich: '+esc(t.zuletzt_erfolgreich)+"</div>";
    }
    c.innerHTML='<div class="tile-head"><span class="auto-when">'+esc(t.rhythmus)+'</span><span class="badge '+badge.cls+'" style="font-size:11px;padding:4px 11px"><span class="dot '+badge.cls+'"></span>'+badge.label+'</span></div><div class="tile-title">'+esc(t.titel)+'</div><div class="tile-desc">'+esc(t.desc)+"</div>"+runhistHtml+'<div class="auto-last">zuletzt: '+esc(t.zuletzt)+"</div>"+errHtml+okNoteHtml;
    grid.appendChild(c);
  });
  wrap.appendChild(grid);
  wrap.appendChild(el("div","hint-line","Diese Läufe starten von allein — Status und Verlauf kommen direkt aus den Session-Protokollen der Läufe."));
};

/* ---------- Nutzung ---------- */
A.pages.nutzung=function(){
  var wrap=$("usageWrap");wrap.innerHTML="";
  var note=stateNote(A.DATA.usage,"Nutzung");
  if(note){var c=el("div","card");c.appendChild(noteEl(note));wrap.appendChild(c);return;}
  var u=A.DATA.usage.data||{};
  var sess=u.sessions_last_7_days||{};
  var main=(sess.main!=null?sess.main:sess.total)||0;
  var sub=sess.subagent||0;
  var sk7=(u.skill_invocations_last_7_days&&u.skill_invocations_last_7_days.total)||0;
  var cw=u.core_workflow||{};
  var cov=u.project_coverage||{};

  // KPI-Leiste (gleiche .kpi-strip/.ktile-Systematik wie Dashboard/Projekte)
  var strip=el("div","kpi-strip");
  function tile(n,l,s){var t=el("div","ktile");t.innerHTML='<div class="n">'+n+'</div><div class="l">'+l+'</div>'+(s?'<div class="s">'+s+"</div>":"");strip.appendChild(t);}
  function qtile(q,l,s){
    var has=(q!=null);var pct=has?Math.round(q*100):0;
    var t=el("div","ktile quote");
    t.innerHTML='<div class="n">'+(has?pct+"%":"—")+'</div><div class="l">'+l+'</div>'+(s?'<div class="s">'+s+"</div>":"")+'<span class="qbar"><span class="qfill" style="width:'+pct+'%"></span></span>';
    strip.appendChild(t);
  }
  tile(nf(main),"Hauptsessions · 7 Tage",sub?("+ "+nf(sub)+" Sub-Agent-Läufe"):"deine eigenen Sitzungen");
  tile(nf(sk7),"Skill-Läufe · 7 Tage","inkl. Sub-Agents");
  qtile(cw.resume_quote,"Resume-Quote",(cw.resume_sessions!=null?cw.resume_sessions+" von "+main+" · Ziel ~100 %":"Session-Einstieg"));
  qtile(cw.wrapup_quote,"Wrap-up-Quote",(cw.wrapup_sessions!=null?cw.wrapup_sessions+" von "+main+" · Ziel ~100 %":"Session-Abschluss"));
  var covSub=cov.off_project!=null?(cov.off_project+" ohne Projekt"+(cov.automation?" · "+cov.automation+" Automation":"")):"in registriertem Projekt";
  qtile(cov.quote,"Projekt-Abdeckung",covSub);
  wrap.appendChild(strip);

  // Chart links, Meistgenutzte Skills rechts
  var grid=el("div","usage-grid");
  var days=Array.isArray(sess.by_day)?sess.by_day:[];
  var cL=el("div","card");cL.appendChild(el("div","bars-title","Sitzungen pro Tag"));
  if(days.length){
    var maxD=Math.max.apply(null,days.map(function(d){return d.n;}).concat([1]));
    var ch=el("div","day-chart");
    days.forEach(function(d){
      var barH=Math.max(4,Math.round(d.n/maxD*150));   // feste Pixel-Hoehe (max 150px), kein Flex-%-Quirk
      var col=el("div","day-col"+(d.today?" dc-today":""));
      col.innerHTML='<div class="day-plot"><span class="day-n mono" style="bottom:'+(barH+4)+'px">'+d.n+'</span><span class="day-bar" style="height:'+barH+'px"></span></div>'+
        '<div class="day-foot"><span class="day-l">'+esc(d.d)+'</span><span class="day-d mono">'+(d.today?"heute":esc(d.date||""))+'</span></div>';
      ch.appendChild(col);
    });
    cL.appendChild(ch);
  }else cL.appendChild(el("div","quiet","Noch keine Sitzungsdaten im Fenster."));
  grid.appendChild(cL);

  var top=Array.isArray(u.skill_invocations_last_7_days&&u.skill_invocations_last_7_days.top)?u.skill_invocations_last_7_days.top:[];
  var cR=el("div","card");cR.appendChild(el("div","bars-title","Meistgenutzte Befehle"));
  if(top.length){
    var maxT=top[0].count||1;
    top.forEach(function(t,idx){var r=el("div","bar-row");r.innerHTML='<span class="name">'+esc(t.skill)+'</span><span class="bar-track"><span class="bar-fill'+(idx>=3?" dim":"")+'" style="width:'+Math.round(t.count/maxT*100)+'%"></span></span><span class="count mono">'+t.count+"</span>";cR.appendChild(r);});
  }else cR.appendChild(el("div","quiet","Noch keine Skill-Läufe im Fenster."));
  grid.appendChild(cR);
  wrap.appendChild(grid);

  // Sitzungen je Projekt (volle Breite)
  var byP=Array.isArray(sess.by_project)?sess.by_project:[];
  if(byP.length){
    var c3=el("div","card");c3.appendChild(el("div","bars-title","Sitzungen je Projekt"));
    var maxP=byP[0].n||1;
    byP.forEach(function(p,idx){var r=el("div","bar-row");r.innerHTML='<span class="name">'+esc(p.p)+'</span><span class="bar-track"><span class="bar-fill'+(idx>=3?" dim":"")+'" style="width:'+Math.round(p.n/maxP*100)+'%"></span></span><span class="count mono">'+p.n+"</span>";c3.appendChild(r);});
    wrap.appendChild(c3);
  }
};

/* ---------- System ---------- */
A.pages.system=function(){
  var card=$("sysCard");card.innerHTML="";
  var section=A.DATA["system-check"];
  var note=stateNote(section,"System-Check");
  if(note){card.appendChild(noteEl(note));}
  else{
    var d=section.data,checks=Array.isArray(d.checks)?d.checks:[];
    var g=A.groupIssues(checks);
    var oks=checks.filter(function(c){return c.status==="ok";});
    var shown=g.issues.filter(function(i){return!A.isRead(issueKey(i));});
    var hidden=g.issues.length-shown.length;
    var hasFail=shown.some(function(i){return i.tone==="fail";});
    var headline=hasFail?"Etwas braucht deine Aufmerksamkeit.":(shown.length?"Dein System läuft — mit "+(shown.length===1?"einem Hinweis.":shown.length+" Hinweisen."):"Dein System läuft rund.");
    var sum=el("div","sys-sum");
    sum.innerHTML='<span class="big"><span class="dot '+(hasFail?"fail":(shown.length?"warn":"ok"))+'"></span>'+esc(headline)+'</span><span class="sub">'+checks.length+' Punkte automatisch geprüft</span><button class="sys-toggle" id="okToggle">Zeigen, was geprüft wurde ▾</button>';
    card.appendChild(sum);
    function redrawSystem(){A.pages.system();updateNavBadges();renderBadge();}
    shown.forEach(function(i){
      var row=el("div","issue");
      row.innerHTML='<span class="sym '+i.tone+'" style="margin-top:4px">'+(i.tone==="fail"?"✕":"▲")+'</span><div class="it"><div class="iname">'+esc(i.title)+'</div><div class="itext">'+esc(i.text)+'</div>'+(i.fix?'<div class="iact"><button class="mini primary" data-fix="'+encodeURIComponent(i.fix)+'">'+esc(i.cta||"Anweisung kopieren")+'</button><span class="mini-hint">kopiert eine fertige Anweisung für Claude — einfügen, Enter, fertig</span></div>':"")+'</div><button class="issue-x" title="Als gelesen ausblenden" aria-label="Ausblenden">✕</button>';
      row.querySelector(".issue-x").addEventListener("click",function(e){e.stopPropagation();A.markRead(issueKey(i));toast("Hinweis ausgeblendet.");redrawSystem();});
      card.appendChild(row);
    });
    if(hidden>0){
      var hb=el("div","hidden-line",hidden+" Hinweis"+(hidden>1?"e":"")+" ausgeblendet · <span class=\"undo\">wieder einblenden</span>");
      hb.querySelector(".undo").addEventListener("click",function(){A.markReadMany(g.issues.map(issueKey),false);redrawSystem();});
      card.appendChild(hb);
    }
    var chips=el("div","ok-chips");chips.style.display="none";
    oks.forEach(function(c){chips.appendChild(el("span","ok-chip",'<span class="sym ok">✓</span>'+esc(A.friendlyOk(c))));});
    card.appendChild(chips);
    var expanded=false;$("okToggle").addEventListener("click",function(){expanded=!expanded;chips.style.display=expanded?"flex":"none";this.textContent=expanded?"Prüfliste ausblenden ▴":"Zeigen, was geprüft wurde ▾";});
    card.querySelectorAll("[data-fix]").forEach(function(b){b.addEventListener("click",function(e){e.stopPropagation();copyText(decodeURIComponent(b.getAttribute("data-fix")),b);toast("Anweisung kopiert — in Claude einfügen und starten.");});});
  }
  renderRecs();
};
function renderRecs(){
  var wrap=$("recsWrap");wrap.innerHTML="";
  var section=A.DATA.recommendations;
  var note=stateNote(section,"Empfehlungen");
  if(note){var c=el("div","card");c.appendChild(noteEl(note));wrap.appendChild(c);return;}
  var recs=Array.isArray(section.data&&section.data.recommendations)?section.data.recommendations:[];
  if(!recs.length){wrap.innerHTML='<div class="card"><div class="state-note" style="justify-content:center">Keine offenen Empfehlungen — sauber aufgeräumt. ✓</div></div>';return;}
  var grid=el("div","recs");
  recs.slice(0,3).forEach(function(r){
    var c=el("div","card rec"+(r.status==="dismissed"?" dismissed":""));
    var statusLabel=r.status==="done"?'<span class="rec-status done">erledigt ✓</span>':(r.status==="dismissed"?'<span class="rec-status dismissed">verworfen</span>':"");
    c.innerHTML='<div class="obs">'+esc(r.beobachtung)+'</div>'+(r.beleg?'<div class="beleg">'+esc(r.beleg)+'</div>':"")+'<div class="rule"></div><div class="emp">'+esc(r.empfehlung)+'</div>'+
      '<div class="rec-actions"><button class="mini primary" data-copy>Anweisung kopieren</button><button class="mini" data-done>Erledigt</button><button class="mini" data-dismiss>Verwerfen</button>'+statusLabel+"</div>";
    grid.appendChild(c);
    c.querySelector("[data-copy]").addEventListener("click",function(){copyText(r.instruktion||r.empfehlung,this);toast("Anweisung kopiert — in Claude einfügen und starten.");});
    c.querySelector("[data-done]").addEventListener("click",function(){setRecStatus(c,r,"done");});
    c.querySelector("[data-dismiss]").addEventListener("click",function(){setRecStatus(c,r,"dismissed");});
  });
  wrap.appendChild(grid);
}
function setRecStatus(card,r,status){
  var act=card.querySelector(".rec-actions");var old=act.querySelector(".rec-status");if(old)old.remove();
  card.classList.toggle("dismissed",status==="dismissed");
  act.appendChild(el("span","rec-status "+status,status==="done"?"erledigt ✓":"verworfen"));
  if(!A.IS_DEMO){A.apiPost("/api/recommendation/status",{id:r.id,status:status}).catch(function(){});}
  toast(status==="done"?"Als erledigt markiert.":"Empfehlung verworfen.");
}

/* ---------- Shell: Sidebar, Router, Topbar ---------- */
var TITLES={dashboard:["Dashboard","Guten Tag — hier ist dein Überblick."],projekte:["Projekte","Alle Vorhaben und ihr Stand."],aufgaben:["Aufgaben","Alle offenen Punkte — fällige zuerst, dann nach Projekt."],inbox:["Inbox","Was in den letzten 24 Stunden reingekommen ist — vorsortiert nach Dringlichkeit."],skills:["Skills & Commands","Deine Arbeitsabläufe — und die Befehle, die den Kreislauf steuern."],automationen:["Automationen","Was nachts und morgens von allein läuft."],nutzung:["Nutzung","Wie intensiv du mit dem System arbeitest."],system:["Zustand","Prüfungen, Hinweise und Verbesserungsvorschläge."],
"vertrieb":["Vertrieb","Deine wichtigsten Zahlen auf einen Blick."],
"vertrieb-pipeline":["Pipeline","Alle Deals, geclustert nach Status."],
"vertrieb-liste":["Leads","Wer sich bis jetzt gemeldet oder eingetragen hat."],
"branding-analytics":["Analytics","Wie deine Inhalte wirken, aus lokalen Daten."],
"content":["Content","Ideen, Entwürfe und Veröffentlichtes im Fluss."]};
var PAGE_MODULE={"vertrieb":"sales","vertrieb-pipeline":"sales","vertrieb-liste":"sales","branding-analytics":"branding","content":"branding"};
function moduleCfg(){return(A.DATA&&A.DATA.config&&A.DATA.config.data&&A.DATA.config.data.modules)||{};}
function moduleEnabled(mod){var m=moduleCfg()[mod];return!!(m&&m.enabled);}
function currentRoute(){
  var h=location.hash.replace(/^#\/?/,"");var parts=h.split("/");
  var page=parts[0]||"dashboard";var arg=parts[1]?decodeURIComponent(parts[1]):null;
  if(page==="commands")page="skills";
  if(!A.pages[page])page="dashboard";
  var mod=PAGE_MODULE[page];
  if(mod&&!moduleEnabled(mod))page="dashboard";
  return{page:page,arg:arg};
}
/* Blendet optionale Nav-/Section-Elemente nach der Modul-Config ein/aus.
   data-requires="leads" braucht zusaetzlich eine konfigurierte Leads-Quelle. */
function applyModules(){
  var mods=moduleCfg();
  document.querySelectorAll("[data-module]").forEach(function(elm){
    var on=!!(mods[elm.getAttribute("data-module")]&&mods[elm.getAttribute("data-module")].enabled);
    elm.style.display=on?"":"none";
  });
  var sales=mods.sales||{};
  var leadsSource=sales.leads&&sales.leads.source;
  var leadsOn=!!(sales.enabled&&leadsSource&&leadsSource!=="none");
  document.querySelectorAll('[data-requires="leads"]').forEach(function(elm){elm.style.display=leadsOn?"":"none";});
  var leadsLabel=(sales.leads&&sales.leads.label)||"Leads";
  var leadsBtnLabel=document.querySelector('.sb-item[data-page="vertrieb-liste"] .sb-label');
  if(leadsBtnLabel)leadsBtnLabel.textContent=leadsLabel;
  TITLES["vertrieb-liste"]=[leadsLabel,"Wer sich bis jetzt gemeldet oder eingetragen hat."];
}
A.applyModules=applyModules;
function renderOnboardingHint(){
  var box=$("onboardingHint");if(!box)return;box.innerHTML="";
  var cfg=A.DATA&&A.DATA.config;
  if(A.IS_DEMO||!cfg||!cfg.data||cfg.data.onboarding_completed!==false)return;
  box.appendChild(el("div","hint-line","Optionale Module (Vertrieb, Branding) lassen sich über <b>/aios-dashboard</b> einrichten."));
}
// Merkt sich die zuletzt gezeichnete Route, damit renderPage zwischen einem
// echten Seitenwechsel und einem blossen Neuzeichnen derselben Seite
// unterscheiden kann. Beim Seitenwechsel gehoert die Ansicht nach oben, beim
// Neuzeichnen (z.B. nach dem Abhaken eines Todos) muss die Scroll-Position
// erhalten bleiben, sonst springt die Liste bei jedem Haken an den Anfang.
var LAST_ROUTE_KEY=null;
A.renderPage=function(){
  if(!A.DATA)return;
  var r=currentRoute();
  document.querySelectorAll(".page").forEach(function(s){s.classList.toggle("on",s.getAttribute("data-page")===r.page);});
  document.querySelectorAll(".sb-item").forEach(function(b){b.classList.toggle("on",b.getAttribute("data-page")===r.page);});
  var t=TITLES[r.page]||["",""];
  $("pageTitle").textContent=t[0];$("pageSub").textContent=t[1];
  var routeKey=r.page+"|"+(r.arg||"");
  var sameRoute=(routeKey===LAST_ROUTE_KEY);
  var keepY=sameRoute?(window.scrollY||window.pageYOffset||0):0;
  A.pages[r.page](r.arg);
  if(r.page==="dashboard")renderOnboardingHint();
  updateNavBadges();
  if(sameRoute){
    // Nur zuruecksetzen, wenn ueberhaupt gescrollt war. Der Browser kann die
    // Position beim Neuaufbau des DOM verlieren, deshalb aktiv wiederherstellen.
    if(keepY)window.scrollTo(0,keepY);
  }else{
    window.scrollTo(0,0);
  }
  LAST_ROUTE_KEY=routeKey;
};
function issueKey(i){return"sys:"+(i.short||i.title||"");}
A.issueKey=issueKey;
A.updateNavBadges=function(){updateNavBadges();};
function updateNavBadges(){
  var chk=A.DATA["system-check"];
  var n=0;
  if(chk&&chk.present&&chk.data)n=A.groupIssues(chk.data.checks).issues.filter(function(i){return!A.isRead(issueKey(i));}).length;
  var sysB=$("navBadgeSystem");sysB.textContent=n||"";sysB.style.display=n?"inline-flex":"none";
  var items=Array.isArray(A.DATA.inbox&&A.DATA.inbox.data&&A.DATA.inbox.data.items)?A.DATA.inbox.data.items:[];
  var hand=items.filter(function(i){return i.prio==="handeln"&&!A.isRead("ib:"+i.id);}).length;
  var ibB=$("navBadgeInbox");ibB.textContent=hand||"";ibB.style.display=hand?"inline-flex":"none";
}
function renderBadge(){
  var b=$("statusBadge");if(!b)return;   // Header-Statusbadge entfernt — Zustand steht im Sidebar-Badge
  var chk=A.DATA["system-check"];
  var note=stateNote(chk,"Status");
  if(note){b.className="badge";b.innerHTML='<span class="dot dormant"></span> Status unbekannt';return;}
  var open=A.groupIssues(chk.data.checks).issues.filter(function(i){return!A.isRead(issueKey(i));});
  var hasFail=open.some(function(i){return i.tone==="fail";});
  if(hasFail){b.className="badge fail";b.innerHTML='<span class="dot fail"></span> Achtung';}
  else if(open.length){b.className="badge warn";b.innerHTML='<span class="dot warn"></span> '+open.length+" Hinweis"+(open.length>1?"e":"");}
  else{b.className="badge ok";b.innerHTML='<span class="dot ok"></span> Alles in Ordnung';}
}
A.renderAll=function(data){
  data=A.applyStateVariant(data);A.DATA=data;
  $("dataStand").innerHTML=(A.IS_DEMO?'<span class="demo-flag">Demo-Daten</span>':"")+" · Stand "+new Date(data.generated_at).toLocaleTimeString("de-DE",{hour:"2-digit",minute:"2-digit"})+" Uhr";
  applyModules();
  renderBadge();
  A.renderPage();
};
/* Zaehlt aufeinanderfolgende 403 (Token ungueltig/abgelaufen) und stoppt den
   5-Minuten-Hintergrund-Poll danach, statt endlos gegen ein totes Token zu
   pollen und das server.log mit "403 no-token"-Zeilen vollzuschreiben. */
var consec403=0,pollIntervalId=null;
/* Sichtbares Fehler-Banner statt stillem Fail-Open in Demo-Daten. Greift sowohl
   bei Abruf-Fehlern (Netzwerk/HTTP/JSON) als auch bei einem Render-Fehler, der
   erst NACH einer erfolgreichen Antwort auftritt (z. B. durch Typwechsel in
   einer Collector-Datei). Demo-Daten zeigt ab jetzt nur noch der bewusste
   Aufruf über ?demo=1, nicht mehr ein zufaelliger Fehler in renderAll. */
function dataErrorBanner(){
  var b=document.getElementById("dataErrorBanner");
  if(!b){
    b=document.createElement("div");
    b.id="dataErrorBanner";
    b.className="data-error-banner";
    b.textContent="Daten konnten nicht geladen oder dargestellt werden. Details in der Browser-Konsole.";
    b.style.display="none";
    document.body.appendChild(b);
  }
  return b;
}
function showDataError(){dataErrorBanner().style.display="block";}
function hideDataError(){dataErrorBanner().style.display="none";}
A.loadData=function(){
  hideDataError();
  if(A.qp&&A.qp.get("demo")==="1"){A.IS_DEMO=true;A.renderAll(A.SAMPLE_DATA);return Promise.resolve();}
  return fetch(A.apiUrl("/api/data"),{credentials:"same-origin"}).then(function(res){
    if(res.status===403){
      consec403++;
      var stopNote=consec403>=2?' Automatisches Neuladen wurde gestoppt.':'';
      document.body.innerHTML='<main style="padding:60px 32px"><p class="eyebrow">Zugriff verweigert</p><h1 class="title">403 · Token fehlt</h1><p style="max-width:520px;color:var(--text-2)">Bitte über den <code>/aios-dashboard</code>-Skill erneut öffnen, damit ein gültiges Token gesetzt wird.'+stopNote+'</p></main>';
      if(consec403>=2&&pollIntervalId){clearInterval(pollIntervalId);pollIntervalId=null;}
      throw new Error("403");
    }
    consec403=0;
    return res.json();
  }).then(function(data){
    A.IS_DEMO=false;
    try{A.renderAll(data);}
    catch(renderErr){console.error("Render-Fehler nach Datenabruf:",renderErr);showDataError();}
  }).catch(function(err){
    if(err&&err.message==="403")return;
    console.error("Abruf-Fehler beim Laden der Daten:",err);
    showDataError();
  });
};
A.init=function(){
  A.Brain.init();
  // Sidebar
  var open=false;try{open=localStorage.getItem("aios_sidebar")==="open";}catch(e){}
  function setSb(o){open=o;document.body.classList.toggle("sb-open",o);try{localStorage.setItem("aios_sidebar",o?"open":"closed");}catch(e){}}
  setSb(open);
  $("sbToggle").addEventListener("click",function(){setSb(!open);});
  document.querySelectorAll(".sb-item").forEach(function(b){b.addEventListener("click",function(){location.hash="#/"+b.getAttribute("data-page");if(window.innerWidth<=820)setSb(false);});});
  // Profil-Menü
  $("profileBtn").addEventListener("click",function(e){e.stopPropagation();var m=$("profileMenu");var isOpen=m.classList.contains("open");A.closeMenus();if(!isOpen){A.fillMenu(m,"global",null);m.classList.add("open");}});
  document.addEventListener("click",A.closeMenus);
  // Aktions-Overlay schließen (Button + Klick auf den Hintergrund)
  var apEl=$("actionPanel"),apClose=$("apClose");
  if(apClose)apClose.addEventListener("click",function(){A.closePanel();});
  if(apEl)apEl.addEventListener("click",function(e){if(e.target===apEl)A.closePanel();});
  // Detail-Modal schließen (gleiches Muster wie das Aktions-Overlay)
  var dpEl=$("detailPanel"),dpClose=$("dpClose");
  if(dpClose)dpClose.addEventListener("click",function(){A.closeDetail();});
  if(dpEl)dpEl.addEventListener("click",function(e){if(e.target===dpEl)A.closeDetail();});
  // Esc schließt zuerst das Detail-Modal (liegt oben), sonst das Aktions-Overlay
  document.addEventListener("keydown",function(e){
    if(e.key!=="Escape")return;
    var dp=$("detailPanel");
    if(dp&&dp.style.display!=="none"){A.closeDetail();return;}
    A.closePanel();
  });
  // run-indicator: laufender Hintergrund-Lauf, Klick reisst das Overlay wieder auf
  var runInd=$("runIndicator");
  if(runInd)runInd.addEventListener("click",function(){A.reopenActionPanel();});
  // Refresh
  $("refreshBtn").addEventListener("click",function(){
    var b=this;b.disabled=true;b.classList.add("spinning");
    function done(){b.disabled=false;b.classList.remove("spinning");}
    if(A.IS_DEMO){setTimeout(function(){A.loadData().finally(done);},600);return;}
    fetch(A.apiUrl("/api/refresh"),{method:"POST",credentials:"same-origin"}).then(function(r){return r.json();}).then(function(){return A.loadData();}).catch(function(){toast("Aktualisieren fehlgeschlagen.",true);}).finally(done);
  });
  // Uhr + Datum
  function tick(){var d=new Date();function p(n){return(n<10?"0":"")+n;}$("clock").textContent=p(d.getHours())+":"+p(d.getMinutes())+":"+p(d.getSeconds());}
  tick();setInterval(tick,1000);
  var d=new Date();
  $("headDate").innerHTML='<em>'+esc(d.toLocaleDateString("de-DE",{weekday:"long"}))+',</em> '+esc(d.toLocaleDateString("de-DE",{day:"numeric",month:"long",year:"numeric"}));
  window.addEventListener("hashchange",A.renderPage);
  A.loadCatalog();
  A.loadData().then(function(){resumeRunIfAny();});
  pollIntervalId=setInterval(function(){if(!A.IS_DEMO)A.loadData();},5*60*1000);
};
/* Seiten-Reload waehrend ein Hintergrund-Lauf serverseitig noch aktiv ist:
   einmalig nachfragen und den run-indicator wieder aufnehmen. */
function resumeRunIfAny(){
  if(A.IS_DEMO)return;
  fetch(A.apiUrl("/api/action/status"),{credentials:"same-origin"}).then(function(r){return r.json();}).then(function(d){
    if(d.running)A.resumeRun(d.running);
  }).catch(function(){});
}
})(window.AIOS);
