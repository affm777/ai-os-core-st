/* AIOS Dashboard — Kern: Utils, Daten, API, Aktionen, Router */
window.AIOS=(function(){
"use strict";
function mkProj(slug,days,ampel,conform,n,dl){var t=[];for(var i=1;i<=n;i++)t.push({text:"Beispiel-Aufgabe "+i+" für "+slug,checked:false,hash:slug+"-h"+i,deadline:(dl&&i===1)?dl:null});return{slug:slug,exists:true,days_since_change:days,ampel:ampel,template_conform:conform,state_path:"x",pending_todos:t,excerpt:null,sessions_7d:(days<4?14-days:0)};}
var SAMPLE_DATA={
"system-check":{present:true,freshness:"ok",updated_at:"2026-07-24T11:57:58+02:00",data:{generated_at:"2026-07-24T11:57:58+02:00",mode:"light",checks:[
{id:"1",name:"settings.json parsebar",status:"ok",detail:"~/.claude/settings.json ist valides JSON.",fix:""},
{id:"2",name:"Registrierte Hooks existieren + ausführbar",status:"ok",detail:"Alle 7 registrierten Hook-Dateien vorhanden und ausführbar.",fix:""},
{id:"3",name:"Hook-Syntax",status:"ok",detail:"Alle geprüften .sh/.js-Hooks sind syntaktisch fehlerfrei.",fix:""},
{id:"4",name:"Node erreichbar",status:"ok",detail:"node v24.12.0 über PATH aufgelöst.",fix:""},
{id:"5",name:"Scheduled Tasks gelaufen",status:"ok",detail:"Vault-Sweep vor ca. 0h; Cleanup-Marker vor 1h.",fix:""},
{id:"6",name:"Connector-Auth",status:"warn",detail:"Re-Auth nötig für: claude.ai · Stripe",fix:"Connector(en) im Claude-Client neu autorisieren (OAuth-Flow erneut durchlaufen): claude.ai Stripe"},
{id:"7",name:"Vault-Maschinerie",status:"ok",detail:"letzter Sweep vor ca. 0h; Inbox: 11 Dateien; Index aktualisiert 09:48.",fix:""},
{id:"8",name:"Vault-Lint-Frische",status:"ok",detail:"Jüngster Report 2026-07-19, 0 WARN/FAIL-Zeilen.",fix:""},
{id:"9.projekt-a",name:"STATE.md: projekt-a",status:"ok",detail:"Template-konform (0 Tage).",fix:""},
{id:"9.projekt-b",name:"STATE.md: projekt-b",status:"warn",detail:"Nicht Template-konform. Fehlend: Current Position, Pending Todos.",fix:"Migriere die STATE.md von projekt-b verlustfrei in die Template-Struktur (~/.claude/templates/new-project/STATE.md.template): Backup anlegen, Inhalt erhalten, unter die Template-Überschriften umsortieren, danach Diff zeigen."},
{id:"9.projekt-c",name:"STATE.md: projekt-c",status:"warn",detail:"Nicht Template-konform. Alter 30 Tage.",fix:"Migriere die STATE.md von projekt-c verlustfrei in die Template-Struktur, Backup + Diff."},
{id:"9.projekt-d",name:"STATE.md: projekt-d",status:"warn",detail:"Nicht Template-konform. Alter 126 Tage.",fix:"Migriere die STATE.md von projekt-d verlustfrei in die Template-Struktur, Backup + Diff."},
{id:"9.projekt-e",name:"STATE.md: projekt-e",status:"ok",detail:"Template-konform (39 Tage).",fix:""},
{id:"9.projekt-f",name:"STATE.md: projekt-f",status:"warn",detail:"Nicht Template-konform. Alter 167 Tage.",fix:"Migriere die STATE.md von projekt-f verlustfrei in die Template-Struktur, Backup + Diff."},
{id:"9.projekt-g",name:"STATE.md: projekt-g",status:"warn",detail:"Nicht Template-konform. Alter 139 Tage.",fix:"Migriere die STATE.md von projekt-g verlustfrei in die Template-Struktur, Backup + Diff."},
{id:"9.projekt-h",name:"STATE.md: projekt-h",status:"ok",detail:"Template-konform (87 Tage).",fix:""},
{id:"9.projekt-i",name:"STATE.md: projekt-i",status:"ok",detail:"Template-konform (47 Tage).",fix:""},
{id:"9.projekt-j",name:"STATE.md: projekt-j",status:"ok",detail:"Template-konform (51 Tage).",fix:""},
{id:"9.projekt-k",name:"STATE.md: projekt-k",status:"warn",detail:"Nicht Template-konform. Alter 20 Tage.",fix:"Migriere die STATE.md von projekt-k verlustfrei in die Template-Struktur, Backup + Diff."},
{id:"9.projekt-l",name:"STATE.md: projekt-l",status:"ok",detail:"Template-konform (32 Tage).",fix:""}
],summary:{ok:13,warn:7,fail:0}}},
portfolio:{present:true,freshness:"ok",updated_at:"2026-07-24T11:57:58+02:00",data:{generated_at:"2026-07-24T11:57:58+02:00",projects:[
mkProj("projekt-a",0,"gruen",true,4,"2026-07-24"),
{slug:"projekt-b",exists:true,days_since_change:0,ampel:"gruen",template_conform:false,state_path:"x",pending_todos:[],excerpt:""},
{slug:"projekt-c",exists:true,days_since_change:30,ampel:"gelb",template_conform:false,state_path:"x",pending_todos:[],excerpt:""},
{slug:"projekt-d",exists:true,days_since_change:126,ampel:"rot",template_conform:false,state_path:"x",pending_todos:[],excerpt:""},
mkProj("projekt-e",39,"gelb",true,4,"2026-07-25"),
{slug:"projekt-f",exists:true,days_since_change:167,ampel:"rot",template_conform:false,state_path:"x",pending_todos:[],excerpt:""},
{slug:"projekt-g",exists:true,days_since_change:139,ampel:"rot",template_conform:false,state_path:"x",pending_todos:[],excerpt:""},
mkProj("projekt-h",87,"rot",true,4),
(function(){var p=mkProj("projekt-i",47,"gelb",true,6);p.todos_outside_section=3;return p;})(),
mkProj("projekt-j",51,"rot",true,4),
{slug:"projekt-k",exists:true,days_since_change:20,ampel:"gelb",template_conform:false,state_path:"x",pending_todos:[],excerpt:""},
mkProj("projekt-l",32,"gelb",true,5)
]}},
"vault-stats":{present:true,freshness:"ok",updated_at:"2026-07-24T11:57:58+02:00",data:{generated_at:"2026-07-24T11:57:58+02:00",available:true,total:2271,by_type:{area:2,concept:51,decision:752,learning:789,meeting:141,meta:16,organization:10,person:95,project:12,resource:22,"session-log":381},by_cluster:{"cluster-01":208,"cluster-02":150,"cluster-03":103,"cluster-04":87,"cluster-05":87,"cluster-06":76,"cluster-07":50,"cluster-08":43,"cluster-09":41,"cluster-10":23,"cluster-11":11,"cluster-12":4,"cluster-13":3,"cluster-14":2,"cluster-15":2,"cluster-16":1,"cluster-17":1,"cluster-18":1,"cluster-19":1,"cluster-20":1,"cluster-21":1},new_last_30_days:547,inbox_count:11}},
usage:{present:true,freshness:"ok",updated_at:"2026-07-24T11:57:58+02:00",data:{generated_at:"2026-07-24T11:57:58+02:00",sessions_last_7_days:{total:73,main:73,subagent:41,by_day:[{d:"Sa",n:6},{d:"So",n:3},{d:"Mo",n:14},{d:"Di",n:12},{d:"Mi",n:16},{d:"Do",n:13},{d:"Fr",n:9}],by_project:[{p:"projekt-a",n:24},{p:"projekt-e",n:15},{p:"projekt-i",n:11},{p:"projekt-k",n:8},{p:"(ohne Projekt)",n:6}]},skill_invocations_last_7_days:{total:52,top:[{skill:"wrap-up",count:18},{skill:"playwright-cli",count:10},{skill:"brain:sync-meetings",count:7},{skill:"brain:sort-inbox",count:5},{skill:"resume-session",count:5},{skill:"research-prompt",count:2}]},core_workflow:{main_sessions:73,resume_sessions:31,resume_quote:0.42,wrapup_sessions:44,wrapup_quote:0.6},project_coverage:{in_project:67,off_project:6,quote:0.92},ccusage:{available:false,hint:"npm i -g ccusage"}}},
heute:{present:true,freshness:"ok",updated_at:"2026-07-24T11:57:58+02:00",data:{generated_at:"2026-07-24T11:57:58+02:00",kalender:[{zeit:"09:30",titel:"Sparring mit Partner",konto:"privat",quelle:"privat"},{zeit:"14:00",titel:"Kundencall",konto:"gws",quelle:"gws"}],mail:{handeln:2,warten:1,kenntnis:5,neu_24h:8,top:["Angebot Rückfrage","Terminvorschlag"]},deals:[{name:"beispiel-kunde",next_step:"Angebot nachfassen",faellig:"2026-07-24"}],sources:{gws_calendar:{status:"ok",updated_at:"2026-07-24T11:57:58+02:00",count:1},privat_calendar:{status:"ok",updated_at:"2026-07-24T11:57:58+02:00"}}}},
inbox:{present:true,freshness:"ok",updated_at:"2026-07-24T11:57:58+02:00",data:{accounts:[{email:"hauptkonto@example.com",label:"Gmail privat",unread:3,status:"ok"},{email:"zweitkonto@example.com",label:"Gmail (Zweitkonto)",unread:1,status:"ok"}],items:[
{id:"i1",source:"gmail",prio:"handeln",von:"Kunde A · privat",titel:"Angebot Rückfrage",alter:"vor 2 Std.",kurz:"Fragt nach Staffelpreisen für das Jahrespaket — Antwort bis morgen zugesagt.",aktion:"Entwirf eine Antwort an Kunde A zur Rückfrage 'Staffelpreise Jahrespaket' in meinem Ton. Kontext aus dem Second Brain laden (Kontakt + letzte Mails), Entwurf zeigen, nicht senden."},
{id:"i2",source:"gmail",prio:"handeln",von:"Steuerberater · privat",titel:"Unterlagen für Q2",alter:"vor 5 Std.",kurz:"Zwei Belege fehlen für den Quartalsabschluss — Frist ist Freitag.",aktion:"Suche die zwei fehlenden Q2-Belege (Kontext: Mail vom Steuerberater) in Drive und im Second Brain und lege eine Antwort mit Anhängen als Entwurf an."},
{id:"i3",source:"gmail",prio:"warten",von:"Partner B · gws",titel:"Terminvorschlag",alter:"gestern",kurz:"Vorschlag ist raus — wartet auf Bestätigung durch den Partner.",aktion:""},
{id:"i4",source:"gmail",prio:"kenntnis",von:"Newsletter · privat",titel:"Wochenupdate",alter:"vor 1 Std.",kurz:"Zusammenfassung der Woche. Keine Aktion nötig.",aktion:""},
{id:"i6",source:"vault",prio:"kenntnis",von:"Second Brain",titel:"11 unsortierte Notizen",alter:"heute",kurz:"Werden beim nächsten Inbox-Sort automatisch einsortiert — oder jetzt sofort per Befehl.",aktion:"/brain:sort-inbox"}
]}},
skills:{present:true,freshness:"ok",updated_at:"2026-07-24T11:57:58+02:00",data:{skills:[
{cmd:"/wrap-up",gruppe:"Fundament",titel:"Sitzung abschließen",desc:"Sichert Entscheidungen, Erkenntnisse und offene Punkte aus der Sitzung ins Second Brain und aktualisiert den Projektstatus.",uses:18},
{cmd:"/resume-session",gruppe:"Fundament",titel:"Arbeitsstand wiederherstellen",desc:"Holt beim Start den letzten Stand: wo waren wir, was ist offen, was wurde entschieden.",uses:5},
{cmd:"/briefing",gruppe:"Fundament",titel:"Tages-Briefing",desc:"Kalender, Postfach, fällige Schritte und System-Status als kurze Morgen-Essenz.",uses:7},
{cmd:"/system-check",gruppe:"Fundament",titel:"System-Doktor",desc:"Prüft das gesamte Setup und liefert zu jedem Befund eine fertige Korrektur-Anweisung.",uses:2},
{cmd:"/new-project",gruppe:"Fundament",titel:"Neues Projekt anlegen",desc:"Setzt ein Projekt mit korrekter Struktur und Status-Datei auf.",uses:1},
{cmd:"/skill-creator",gruppe:"Fundament",titel:"Ablauf zum Skill machen",desc:"Verwandelt einen wiederkehrenden Freitext-Auftrag in einen eigenen, aufrufbaren Skill.",uses:1},
{cmd:"/brain:sync-meetings",gruppe:"Fundament",titel:"Meetings einsammeln",desc:"Übernimmt Meeting-Transkripte als Notizen ins Second Brain.",uses:7},
{cmd:"/mail",gruppe:"Weitere",titel:"Antwort-Entwürfe",desc:"Entwirft Mail-Antworten im eigenen Ton — senden tust du.",uses:9},
{cmd:"/designer",gruppe:"Weitere",titel:"Dokumente & Slides",desc:"Erstellt Print-Dokumente, PDFs und Präsentationen aus einfachem Text.",uses:3},
{cmd:"/research-prompt",gruppe:"Weitere",titel:"Recherche-Prompts",desc:"Baut optimierte Prompts für externe KI-Recherchen.",uses:2},
{cmd:"/clear",gruppe:"Fundament",titel:"Chat leeren",desc:"Leert den Chat-Verlauf für einen frischen Start. Der Arbeitsstand ist vorher durch das Wrap-up gesichert.",uses:12},
{cmd:"/aios-dashboard",gruppe:"Fundament",titel:"Schaltstelle öffnen",desc:"Startet dieses Dashboard lokal auf deinem Rechner.",uses:4},
{cmd:"/playwright-cli",gruppe:"Weitere",titel:"Browser steuern & testen",desc:"Steuert einen echten Browser, für Klickstrecken, Screenshots und Tests.",uses:2}
]}},
automationen:{present:true,freshness:"ok",updated_at:"2026-07-24T11:57:58+02:00",data:{tasks:[
{name:"fathom-sync",titel:"Meeting-Notizen einsammeln",rhythmus:"nachts · 02:00",zuletzt:"heute, 02:00",status:"ok",desc:"Holt Meeting-Transkripte aus Fathom und legt sie als Notizen ins Second Brain."},
{name:"inbox-sort",titel:"Inbox einsortieren",rhythmus:"nachts · 03:30",zuletzt:"heute, 03:30",status:"ok",desc:"Sortiert neue Notizen in die richtigen Ordner und hält den Index aktuell."},
{name:"vault-health",titel:"Second Brain prüfen",rhythmus:"sonntags · 04:00",zuletzt:"So, 19.07.",status:"ok",desc:"Wöchentlicher Qualitäts-Check über alle Notizen und Verknüpfungen."},
{name:"briefing",titel:"Tages-Briefing",rhythmus:"morgens · 07:00",zuletzt:"heute, 07:00",status:"ok",desc:"Stellt das Wichtigste für heute zusammen und schickt die Essenz nach Slack."}
]}},
recommendations:{present:true,freshness:"ok",updated_at:"2026-07-24T11:57:58+02:00",data:{generated_at:"2026-07-24T11:57:58+02:00",recommendations:[
{id:"rec-1",beobachtung:"Du rufst den Sitzungs-Abschluss (wrap-up) sehr oft von Hand auf — ein klares Muster für Automatisierung.",beleg:"18-mal in 7 Tagen.",empfehlung:"Den Abschluss automatisch am Ende jeder Sitzung laufen lassen.",instruktion:"Baue mit /skill-creator einen Session-End-Hook, der den wrap-up-Skill automatisch nach jeder Session ausführt.\nKontext: wrap-up lief 18x in 7 Tagen manuell.\nZiel: automatischer Trigger + kurze Bestätigung.",status:"open"},
{id:"rec-2",beobachtung:"Sechs Projekte führen ihre Status-Datei noch im alten Format — dadurch fehlen dort Aufgabenlisten im Dashboard.",beleg:"6 von 12 Projekten betroffen.",empfehlung:"Alle alten Status-Dateien in einem Rutsch aufs neue Format umstellen lassen.",instruktion:"Migriere alle als 'nicht Template-konform' markierten STATE.md-Dateien verlustfrei in die Template-Struktur.\nBackup je Datei, danach Sammel-Diff.",status:"open"},
{id:"rec-3",beobachtung:"Die Kostenübersicht ist noch nicht eingerichtet — du siehst nicht, was deine KI-Nutzung kostet.",beleg:"0 Kosten-Datenpunkte verfügbar.",empfehlung:"Kosten-Tracking einmalig installieren, danach erscheint der Verbrauch hier.",instruktion:"npm i -g ccusage",status:"dismissed"}
]}},
meta:{present:true,freshness:"ok",updated_at:"2026-07-24T11:57:58+02:00",data:{collectors:{}}},
config:{present:true,data:{onboarding_completed:true,modules:{
  branding:{enabled:true,platforms:["linkedin","instagram"],content_path:"~/projekte/content"},
  sales:{enabled:true,pipeline:{source:"airtable"},leads:{source:"airtable",label:"Leads"},events:{source:"airtable"}}
}}},
/* Demo-Daten fuer das Opt-in-Modul "Standorte" (Use-Case-Bundle
   standort-kpi-dashboard). Ohne angewendetes Modul ungenutzt und harmlos,
   mit Modul zeigt der Demo-Modus damit eine gefuellte Seite: ein spaeter
   eroeffneter Standort mit Luecken und ein fehlender Einzelwert, damit
   Luecken-Markierung und "?" sichtbar sind. */
kpi:{present:true,freshness:"ok",updated_at:"2026-07-24T11:57:58+02:00",data:{generated_at:"2026-07-24T11:57:58+02:00",zeitraum:{von:"2026-01",bis:"2026-06"},standorte:[
{name:"Standort Mitte",monate:[{monat:"2026-01",umsatz_ist:42000,kosten:31500,ebit:7900,behandlungen:118},{monat:"2026-02",umsatz_ist:39500,kosten:30800,ebit:6200,behandlungen:109},{monat:"2026-03",umsatz_ist:45200,kosten:31900,ebit:10700,behandlungen:127},{monat:"2026-04",umsatz_ist:47100,kosten:32400,ebit:12100,behandlungen:131},{monat:"2026-05",umsatz_ist:44800,kosten:32100,ebit:10100},{monat:"2026-06",umsatz_ist:48900,kosten:33000,ebit:13300,behandlungen:136}]},
{name:"Standort Nord",monate:[{monat:"2026-03",umsatz_ist:21500,kosten:19800,ebit:400,behandlungen:64},{monat:"2026-04",umsatz_ist:24300,kosten:20400,ebit:2600,behandlungen:71},{monat:"2026-05",umsatz_ist:26100,kosten:20900,ebit:3900,behandlungen:78},{monat:"2026-06",umsatz_ist:27400,kosten:21200,ebit:4900,behandlungen:82}]}],hinweise:[]}},
branding:{present:true,freshness:"ok",updated_at:"2026-07-24T11:57:58+02:00",data:{
  generated_at:"2026-07-24T11:57:58+02:00",available:true,content_path:"~/projekte/content",platforms:["linkedin","instagram"],
  pillars:["Praxis-Learnings","Produkt-Einblicke","Branchentrends"],
  pipeline:{
    backlog:[
      {slug:"idee-a",title:"Warum kleine Automationen den größten Hebel haben",pillar:"Praxis-Learnings",format:"Post",virality_score:4,created_at:"2026-07-10"},
      {slug:"idee-b",title:"Ein Tag im Leben mit einem KI-Betriebssystem",pillar:"Produkt-Einblicke",format:"Carousel",virality_score:3,created_at:"2026-07-14"},
      {slug:"idee-c",title:"Der Unterschied zwischen Tool und System",pillar:"Branchentrends",format:"Post",virality_score:5,created_at:"2026-07-18"},
      {slug:"idee-d",title:"Was Gründer über Automatisierung falsch verstehen",pillar:"Praxis-Learnings",format:"Post",virality_score:3,created_at:"2026-07-20"}
    ],
    drafts:[{slug:"entwurf-a",title:"Drei Learnings aus dem letzten Workshop",pillar:"Praxis-Learnings",slot:"2026-07-28"}],
    published:[
      {slug:"post-a",title:"Wie ein persönliches AI-Betriebssystem wirklich aussieht",date:"2026-07-12",pillar:"Produkt-Einblicke",format:"Post",platform:"linkedin",url:"https://linkedin.com/example-a",metrics:{impressions:4200,members_reached:3100,likes:88,comments:14,follows:6},d_score:78},
      {slug:"post-b",title:"Fünf Automationen, die sich in der ersten Woche lohnen",date:"2026-07-05",pillar:"Praxis-Learnings",format:"Carousel",platform:"linkedin",url:"https://linkedin.com/example-b",metrics:{impressions:6100,members_reached:4500,likes:132,comments:21,follows:11},d_score:85}
    ]
  },
  analytics:{summary_available:true,followers_total:1840,periods:[
    {from:"2026-07-18",to:"2026-07-24",days:7,impressions:9800,members_reached:6700,engagements:410,new_followers:22,followers_total:1840,posts:2},
    {from:"2026-07-11",to:"2026-07-17",days:7,impressions:7200,members_reached:5100,engagements:305,new_followers:14,followers_total:1818,posts:1}
  ]}
}},
sales:{present:true,freshness:"ok",updated_at:"2026-07-24T11:57:58+02:00",data:{
  generated_at:"2026-07-24T11:57:58+02:00",
  sources:{pipeline:{status:"ok",adapter:"airtable",updated_at:"2026-07-24T11:57:58+02:00",hint:""},leads:{status:"ok",adapter:"airtable",updated_at:"2026-07-24T11:57:58+02:00",hint:""},events:{status:"ok",adapter:"airtable",updated_at:"2026-07-24T11:57:58+02:00",hint:""}},
  stages:[
    {id:"lead",label:"Lead",category:"lead",forecast:false,count:5,value_sum:0},
    {id:"gespraech",label:"Gespräch",category:"active",forecast:false,count:3,value_sum:9000},
    {id:"angebot",label:"Angebot",category:"active",forecast:true,count:2,value_sum:12000},
    {id:"gewonnen",label:"Gewonnen",category:"won",forecast:false,count:4,value_sum:31000},
    {id:"verloren",label:"Verloren",category:"lost",forecast:false,count:2,value_sum:0}
  ],
  kpis:{expected_revenue:12000,expected_revenue_deals:2,conversations:9,won:4,companies_in_pipeline:7},
  deals:[
    {id:"demo-1",name:"Ansprechpartner A",company:"Beispiel-Kunde A",stage:"angebot",value:8000,next_step:"Angebot nachfassen",due:"2026-07-28",overdue:false},
    {id:"demo-2",name:"Ansprechpartner B",company:"Beispiel-Kunde B",stage:"gespraech",value:4000,next_step:"Folgetermin vereinbaren",due:"2026-07-22",overdue:true},
    {id:"demo-3",name:"Ansprechpartner C",company:"Beispiel-Kunde C",stage:"angebot",value:4000,next_step:"Rückmeldung abwarten",due:"2026-08-01",overdue:false}
  ],
  leads:{label:"Leads",total:33,entries:[
    {name:"Max Beispiel",company:"Musterfirma GmbH",date:"2026-07-20",extra:{topics:"Automatisierung, KI-Strategie",role:"Geschäftsführung"}},
    {name:"Erika Beispiel",company:"Beispiel Consulting",date:"2026-07-17",extra:{topics:"Content, Vertrieb",role:"Marketing"}},
    {name:"Sam Muster",company:"Muster & Partner",date:"2026-07-11",extra:{topics:"Prozesse",role:"Operations"}}
  ]},
  events:{available:true,items:[
    {label:"Workshop-Termin A",count:14,seats:16,revenue:22260},
    {label:"Workshop-Termin B",count:9,seats:16,revenue:14310}
  ]}
}},
generated_at:"2026-07-24T11:57:58+02:00"};

/* Token / API */
var qp=new URLSearchParams(location.search);
var tokenFromUrl=qp.get("t");
if(tokenFromUrl){try{sessionStorage.setItem("aios_token",tokenFromUrl);}catch(e){}}
function getToken(){try{return sessionStorage.getItem("aios_token")||tokenFromUrl||"";}catch(e){return tokenFromUrl||"";}}
function apiUrl(p){var t=getToken();var s=p.indexOf("?")===-1?"?":"&";return t?p+s+"t="+encodeURIComponent(t):p;}
function apiPost(path,body){return fetch(apiUrl(path),{method:"POST",credentials:"same-origin",headers:{"Content-Type":"application/json"},body:JSON.stringify(body||{})}).then(function(res){return res.json().catch(function(){return{};}).then(function(d){return{ok:res.ok,status:res.status,data:d};});});}

/* Utils */
function $(id){return document.getElementById(id);}
function esc(s){return String(s==null?"":s).replace(/[&<>"']/g,function(c){return{"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c];});}
function nf(n){return (typeof n==="number"?n:0).toLocaleString("de-DE");}
function el(tag,cls,html){var e=document.createElement(tag);if(cls)e.className=cls;if(html!=null)e.innerHTML=html;return e;}
function toast(msg,err){var w=$("toasts");var t=el("div","toast"+(err?" err":""));t.textContent=msg;w.appendChild(t);setTimeout(function(){t.style.opacity="0";t.style.transition="opacity .3s";setTimeout(function(){t.remove();},300);},err?6000:3400);}
function copyText(text,btn){function done(){if(!btn)return;var o=btn.textContent;btn.textContent="Kopiert ✓";setTimeout(function(){btn.textContent=o;},1600);}
  if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(text).then(done).catch(function(){fb();done();});}else{fb();done();}
  function fb(){var ta=el("textarea");ta.value=text;ta.style.position="fixed";ta.style.opacity="0";document.body.appendChild(ta);ta.select();try{document.execCommand("copy");}catch(e){}document.body.removeChild(ta);}}
/* Lokaler „gelesen/erledigt"-Zustand fuer Badges (Inbox-Items, System-Hinweise).
   Rein clientseitig in localStorage, ueberlebt Reload. Stale Keys sind harmlos:
   beim Rendern wird gegen die aktuellen Daten geschnitten, verschwundene Keys zaehlen nicht. */
var READ_KEY="aios_read_v1";
function readSet(){try{return new Set(JSON.parse(localStorage.getItem(READ_KEY)||"[]"));}catch(e){return new Set();}}
function isRead(k){return readSet().has(k);}
function markRead(k,on){var s=readSet();if(on===false)s.delete(k);else s.add(k);try{localStorage.setItem(READ_KEY,JSON.stringify(Array.from(s)));}catch(e){}}
function markReadMany(keys,on){var s=readSet();keys.forEach(function(k){if(on===false)s.delete(k);else s.add(k);});try{localStorage.setItem(READ_KEY,JSON.stringify(Array.from(s)));}catch(e){}}
/* fix ist optional und ueberschreibt den generischen "Aktualisieren"-Hinweis.
   Regel: Wer eine Kachel aus Connector-Daten speist, muss ihren Leerzustand
   selbst beschriften (der Aktualisieren-Knopf erreicht Connectoren nicht).
   Der generische Text gilt nur fuer Collector-Kacheln (refresh.sh). */
function stateNote(section,label,fix){
  if(!section||!section.present)return{cls:"missing",text:label+": Es liegen noch keine Daten vor.",fix:fix||"Einmal auf „Aktualisieren“ drücken — dann sammelt das System die Daten ein."};
  if(section.freshness==="stale"){var d=new Date(section.updated_at);return{cls:"stale",text:label+": Stand vom "+d.toLocaleString("de-DE")+" — älter als 12 Stunden.",fix:""};}
  return null;
}
function noteEl(n){var e=el("div","state-note "+n.cls);e.innerHTML='<span class="sym '+(n.cls==="missing"?"fail":"warn")+'">'+(n.cls==="missing"?"✕":"▲")+"</span><span>"+esc(n.text)+(n.fix?'<span class="fixhint">'+esc(n.fix)+"</span>":"")+"</span>";return e;}
/* Bezieht sich auf die letzte Änderung an Status-Datei/Git-Commit des Projekts,
   NICHT auf Sitzungen. Die echte Session-Zahl steht separat (sessions_7d). */
function daysLabel(p){var d=p.days_since_change;if(d==null)return"—";if(d<=0)return"Status heute";if(d===1)return"Status gestern";if(d<14)return"Status vor "+d+" Tagen";if(d<60)return"Status vor "+Math.round(d/7)+" Wochen";return"ruht seit "+Math.round(d/30)+" Monaten";}
function ampelCls(a){return a==="gruen"?"active":(a==="gelb"?"aging":"dormant");}

/* System-Check: Klartext-Gruppierung */
function friendlyOk(c){var n=c.name||"";
  if(/settings\.json/i.test(n))return"Grundeinstellungen gültig";
  if(/Hooks existieren/i.test(n))return"Alle Schutzmechanismen aktiv";
  if(/Hook-Syntax/i.test(n))return"Schutzskripte fehlerfrei";
  if(/Node/i.test(n))return"Technische Basis läuft";
  if(/Scheduled/i.test(n))return"Nächtliche Automatik gelaufen";
  if(/Vault-Maschinerie/i.test(n))return"Second-Brain-Automatik läuft";
  if(/Vault-Lint/i.test(n))return"Second Brain sauber geprüft";
  if(/^STATE\.md: /.test(n))return n.replace(/^STATE\.md: /,"")+": Status-Datei aktuell";
  return n;}
function groupIssues(checks){
  var issues=[],stateWarns=[];
  (checks||[]).forEach(function(c){
    if(c.status==="ok")return;
    var tone=c.status==="fail"?"fail":"warn";
    if(/^STATE\.md: /.test(c.name||"")){stateWarns.push(c);return;}
    if(/Connector/i.test(c.name||"")){
      var svcs=(c.detail||"").split(":").pop().split("·").map(function(s){return s.trim();}).filter(Boolean);
      issues.push({tone:tone,title:"Verbindungen brauchen eine neue Anmeldung",short:"Verbindungen",text:(svcs.length?svcs.join(" und "):"Einige Dienste")+" sind nicht mehr angemeldet. Solange bleibt z. B. Mail- oder Zahlungs-Abgleich stehen. Die Anmeldung dauert eine Minute.",fix:c.fix,cta:"Anweisung kopieren"});return;
    }
    issues.push({tone:tone,title:c.name,short:c.name,text:c.detail||"",fix:c.fix,cta:"Anweisung kopieren"});
  });
  if(stateWarns.length){
    // Zwei Faelle getrennt halten (V12): ohne Status-Datei gibt es nichts
    // umzustellen, das Migrations-Angebot gilt nur fuer vorhandene, nicht
    // konforme Dateien. Unterscheidung ueber den Detailtext von check.sh.
    var missing=stateWarns.filter(function(c){return/Keine STATE\.md/i.test(c.detail||"");});
    var fmtW=stateWarns.filter(function(c){return!/Keine STATE\.md/i.test(c.detail||"");});
    if(fmtW.length){
      var slugs=fmtW.map(function(c){return c.name.replace(/^STATE\.md: /,"");});
      issues.push({tone:"warn",title:slugs.length+(slugs.length===1?" Projekt führt seine":" Projekte führen ihre")+" Status-Datei noch im alten Format",short:"Status-Dateien",
        text:"Betroffen: "+slugs.join(", ")+". Dadurch fehlen dort die Aufgabenlisten. Claude kann alle Dateien automatisch umstellen, ohne Datenverlust, mit Backup.",
        fix:"Migriere die STATE.md-Dateien dieser Projekte verlustfrei in die Template-Struktur (~/.claude/templates/new-project/STATE.md.template): "+slugs.join(", ")+". Je Datei ein Backup anlegen, Inhalte erhalten, danach einen Sammel-Diff zeigen.",cta:"Alle umstellen lassen"});
    }
    if(missing.length){
      var mSlugs=missing.map(function(c){return c.name.replace(/^STATE\.md: /,"");});
      issues.push({tone:"warn",title:mSlugs.length+(mSlugs.length===1?" Projekt hat":" Projekte haben")+" noch keine Status-Datei",short:"Status-Dateien",
        text:"Betroffen: "+mSlugs.join(", ")+". Aufgaben erscheinen im Dashboard, sobald eine STATE.md angelegt ist.",
        fix:"Lege für diese Projekte eine STATE.md gemäß Template an (~/.claude/templates/new-project/STATE.md.template): "+mSlugs.join(", ")+".",cta:"Anweisung kopieren"});
    }
  }
  return{issues:issues};
}

/* Aktionen */
var ACTIONS=null,pollTimer=null;
/* Ein Poller fuer serverseitige Claude-Laeufe, zwei Darstellungen: "modal"
   (blockierendes Overlay, klassisches Verhalten fuer kurze Aktionen) oder
   "background" (nur der run-indicator in der Kopfzeile, Seite bleibt nutzbar). */
var runState={active:null,mode:"modal"};
var pollFailCount=0;
/* Deckt sich mit dashboard/actions.json — Fallback greift nur, wenn der
   Katalog-Endpunkt nicht erreichbar ist, muss also dieselben Aktionen zeigen. */
var DEMO_CATALOG=[{name:"system-check",label:"System-Check (light)",scope:"global",kind:"shell",enabled:true},{name:"refresh-data",label:"Daten aktualisieren",scope:"global",kind:"shell",enabled:true},{name:"briefing",label:"Tages-Briefing",scope:"global",kind:"claude",enabled:true}];
function loadCatalog(){return fetch(apiUrl("/api/actions/catalog"),{credentials:"same-origin"}).then(function(r){return r.json();}).then(function(d){ACTIONS=d.actions||[];}).catch(function(){ACTIONS=DEMO_CATALOG.slice();});}
function menuItem(a){var disabled=a.enabled===false;var hint=disabled?(a.hint||"noch nicht verfügbar"):(a.kind==="claude"?"startet einen Claude-Lauf":"");return'<button class="menu-item" data-action="'+esc(a.name)+'" '+(disabled?"disabled":"")+">"+esc(a.label||a.name)+(hint?'<span class="h'+(a.kind==="claude"?" claude":"")+'">'+esc(hint)+"</span>":"")+"</button>";}
function fillMenu(menu,scope,slug){
  if(!ACTIONS){menu.innerHTML='<div class="menu-label">lädt…</div>';return;}
  var acts=ACTIONS.filter(function(a){return a.scope===scope;});
  menu.innerHTML='<div class="menu-label">'+(scope==="global"?"Aktionen":"Projekt-Aktionen")+"</div>"+acts.map(menuItem).join("");
  menu.querySelectorAll(".menu-item").forEach(function(b){if(b.disabled)return;b.addEventListener("click",function(e){e.stopPropagation();runAction(b.getAttribute("data-action"),slug);});});
}
function closeMenus(){document.querySelectorAll(".menu.open").forEach(function(m){m.classList.remove("open");});}
function actionErr(d){if(d&&d.error==="busy")return d.detail||"Es läuft bereits eine Aktion.";if(d&&d.error==="disabled")return d.detail||"Aktion noch nicht verfügbar.";return(d&&d.detail)||"Aktion fehlgeschlagen.";}
function isClaude(name){var a=(ACTIONS||[]).filter(function(x){return x.name===name;})[0];return a&&a.kind==="claude";}
function actionLabel(name){var a=(ACTIONS||[]).filter(function(x){return x.name===name;})[0];return(a&&a.label)||name;}
/* Aktions-Overlay (global, NICHT mehr an die Zustand-Seite gebunden) */
var panelDismissed=false;
function runAction(name,project){
  closeMenus();
  panelDismissed=false;
  if(A.IS_DEMO){demoRunAction(name,project);return;}
  apiPost("/api/action/run",{name:name,project:project}).then(function(r){if(!r.ok){toast(actionErr(r.data),true);return;}
    runState={active:{name:name,project:project,started_at:(r.data&&r.data.started_at)||new Date().toISOString()},mode:"modal"};
    showPanel(name,project,"läuft…",true,isClaude(name));
    updateRunIndicator(runState.active);
    ensurePolling();
  }).catch(function(){toast("Netzwerkfehler beim Starten der Aktion.",true);});
}
/* Startet eine Aktion, ohne das blockierende Overlay zu zeigen — nur der
   run-indicator in der Kopfzeile signalisiert den laufenden Claude-Lauf.
   Fuer lange Laeufe, waehrend derer die Seite normal nutzbar bleiben soll.
   Aktuell hat diese Funktion keinen Aufrufer: sie ist der Baustein fuer die
   naechste Aktion, die laenger als ein paar Sekunden braucht. */
function runActionBackground(name,project){
  closeMenus();
  if(A.IS_DEMO){demoRunAction(name,project);return;}
  apiPost("/api/action/run",{name:name,project:project}).then(function(r){if(!r.ok){toast(actionErr(r.data),true);return;}
    runState={active:{name:name,project:project,started_at:(r.data&&r.data.started_at)||new Date().toISOString()},mode:"background"};
    updateRunIndicator(runState.active);
    ensurePolling();
    A.renderPage();
  }).catch(function(){toast("Netzwerkfehler beim Starten der Aktion.",true);});
}
/* Vom geschlossenen Overlay uebernommener, weiterlaufender Lauf: run-indicator
   zeigt ihn an, Klick darauf reisst das Overlay wieder auf (siehe unten). */
function reopenActionPanel(){
  if(!runState.active)return;
  panelDismissed=false;runState.mode="modal";
  showPanel(runState.active.name,runState.active.project,"läuft…",true,isClaude(runState.active.name));
}
/* Uebernimmt einen beim Laden bereits serverseitig laufenden Lauf (Seiten-Reload
   waehrend ein Hintergrund-Lauf noch aktiv ist). */
function resumeRun(running){
  if(!running)return;
  runState={active:{name:running.name,project:running.project,started_at:running.started_at},mode:"background"};
  updateRunIndicator(runState.active);
  ensurePolling();
}
function isActionRunning(){return runState.active||A.actionRunning||null;}
function updateRunIndicator(running){
  var ind=$("runIndicator");if(!ind)return;
  if(running){ind.style.display="inline-flex";var lbl=$("runIndicatorLabel");if(lbl)lbl.textContent=actionLabel(running.name);}
  else ind.style.display="none";
}
function showPanel(name,project,status,running,claude){
  if(panelDismissed)return;            // Nutzer hat das Overlay geschlossen — nicht wieder aufreissen
  var p=$("actionPanel");if(!p)return;
  p.style.display="flex";
  $("apTitle").innerHTML='<span class="dot '+(running?"warn":"ok")+'"></span>'+esc(name)+(project?' · <span class="mono">'+esc(project)+"</span>":"");
  $("apStatus").innerHTML=(running?'<span class="spinner"></span>':"")+esc(status);
  $("apHint").textContent=claude&&running?"Dies startet einen Claude-Lauf — bitte einen Moment.":"";
}
function closePanel(){
  panelDismissed=true;
  var p=$("actionPanel");if(p)p.style.display="none";
  // Der Lauf laeuft serverseitig weiter — der Poller bleibt aktiv, nur die
  // Darstellung wechselt vom Overlay auf den dezenten run-indicator.
  if(runState.active){runState.mode="background";updateRunIndicator(runState.active);}
}
function stopPolling(){if(pollTimer){clearInterval(pollTimer);pollTimer=null;}}
function ensurePolling(){
  if(pollTimer)return;                 // schon ein Intervall aktiv — idempotent
  pollFailCount=0;
  pollTimer=setInterval(function(){
    fetch(apiUrl("/api/action/status"),{credentials:"same-origin"}).then(function(r){return r.json();}).then(function(d){
      pollFailCount=0;
      A.actionRunning=d.running||null;
      updateRunIndicator(d.running);
      if(d.running){
        if(runState.mode==="modal"&&!panelDismissed)showPanel(d.running.name,d.running.project,"läuft seit "+new Date(d.running.started_at).toLocaleTimeString("de-DE")+"…",true,isClaude(d.running.name));
        return;
      }
      stopPolling();
      var act=runState.active;
      // Neustart-Toleranz: der zuletzt gesehene Lauf passt nicht mehr zum, den
      // wir erwartet haben — Server ist vermutlich neu gestartet, Lauf verloren.
      if(act&&(!d.last||d.last.name!==act.name||d.last.finished_at<act.started_at)){
        runState={active:null,mode:"modal"};
        toast("Der Lauf ist nicht mehr auffindbar, vermutlich wurde der Server neu gestartet.",true);
        A.loadData();
        return;
      }
      var mode=runState.mode;
      runState={active:null,mode:"modal"};
      if(d.last){
        var lbl={ok:"fertig",error:"Fehler",timeout:"Zeitüberschreitung"}[d.last.status]||d.last.status;
        if(mode==="modal"){
          showPanel(d.last.name,d.last.project,lbl+" · "+new Date(d.last.finished_at).toLocaleTimeString("de-DE"),false,false);
          fetchOutput(d.last.output_file);
          if(d.last.status!=="ok")toast('Aktion „'+d.last.name+'“ '+lbl.toLowerCase()+".",true);else{toast('Aktion „'+d.last.name+'“ abgeschlossen.');A.loadData();}
        }else{
          if(d.last.status!=="ok")toast('Aktion „'+actionLabel(d.last.name)+'“ '+lbl.toLowerCase()+".",true);else toast('Aktion „'+actionLabel(d.last.name)+'“ abgeschlossen.');
          A.loadData();
        }
      }
    }).catch(function(){
      pollFailCount++;
      if(pollFailCount>=30){        // 30 Fehl-Ticks à 2s = 60s ohne Antwort
        stopPolling();updateRunIndicator(null);
        runState={active:null,mode:"modal"};
        toast("Der Lauf ist nicht mehr auffindbar, vermutlich wurde der Server neu gestartet.",true);
        A.loadData();
      }
    });
  },2000);
}
function fetchOutput(file){
  var out=$("apOut");out.style.display="block";out.textContent="lädt Ergebnis…";
  var fn=(file||"").split("/").pop();
  fetch(apiUrl("/api/action/output?file="+encodeURIComponent(fn)),{credentials:"same-origin"}).then(function(r){return r.ok?r.text():Promise.reject();}).then(function(txt){out.textContent=txt||"(leere Ausgabe)";}).catch(function(){out.textContent="Ergebnis gespeichert unter: "+file;});
}
function demoRunAction(name,project){
  panelDismissed=false;
  var claude=isClaude(name);
  showPanel(name,project,"läuft…",true,claude);
  var out=$("apOut");out.style.display="none";
  setTimeout(function(){
    showPanel(name,project,"fertig · "+new Date().toLocaleTimeString("de-DE"),false,false);
    out.style.display="block";
    out.textContent=claude?
      "▸ Claude-Lauf (Demo)\n\nHier steht im Live-Betrieb die Ausgabe des Laufs,\nzum Beispiel dein Tages-Briefing.\n\n(Der Demo-Modus führt nichts aus.)":
      "▸ "+name+" (Demo) abgeschlossen.\nIm Live-Betrieb wird hier die reale Ausgabe angezeigt.";
    toast('Demo: Aktion „'+name+'“ simuliert.');
  },1400);
}

/* Generisches Detail-Modal (Themen-Erklaerung, Karten-Detailansicht, o.ae.) —
   unabhaengig vom Aktions-Overlay, kann parallel zum run-indicator offen sein. */
function openDetail(titleHtml,contentNode){
  var p=$("detailPanel");if(!p)return;
  var t=$("dpTitle");if(t)t.innerHTML=titleHtml||"";
  var b=$("dpBody");if(b){b.innerHTML="";if(contentNode)b.appendChild(contentNode);}
  p.style.display="flex";
}
function closeDetail(){var p=$("detailPanel");if(p)p.style.display="none";}

/* Demo-Zustände (?state=stale|missing|allgreen) */
function applyStateVariant(data){
  var v=qp.get("state");if(!v)return data;
  data=JSON.parse(JSON.stringify(data));
  if(v==="stale"){Object.keys(data).forEach(function(k){if(data[k]&&data[k].present){data[k].freshness="stale";var d=new Date();d.setHours(d.getHours()-18);data[k].updated_at=d.toISOString();}});}
  if(v==="missing"){data.usage.present=false;data["vault-stats"].data.available=false;data["vault-stats"].data.hint="Vault-Index fehlt — noch nicht eingesammelt.";data.heute.present=false;data.recommendations.present=false;}
  if(v==="allgreen"){data["system-check"].data.checks=data["system-check"].data.checks.map(function(c){c.status="ok";c.fix="";return c;});data["system-check"].data.summary={ok:data["system-check"].data.checks.length,warn:0,fail:0};}
  return data;
}

var A={SAMPLE_DATA:SAMPLE_DATA,IS_DEMO:false,DATA:null,qp:qp,actionRunning:null,
  $:$,esc:esc,nf:nf,el:el,toast:toast,copyText:copyText,stateNote:stateNote,noteEl:noteEl,daysLabel:daysLabel,ampelCls:ampelCls,
  isRead:isRead,markRead:markRead,markReadMany:markReadMany,
  apiUrl:apiUrl,apiPost:apiPost,friendlyOk:friendlyOk,groupIssues:groupIssues,
  loadCatalog:loadCatalog,fillMenu:fillMenu,closeMenus:closeMenus,runAction:runAction,closePanel:closePanel,applyStateVariant:applyStateVariant,
  runActionBackground:runActionBackground,reopenActionPanel:reopenActionPanel,resumeRun:resumeRun,isActionRunning:isActionRunning,
  openDetail:openDetail,closeDetail:closeDetail,
  loadData:null};
return A;
})();
