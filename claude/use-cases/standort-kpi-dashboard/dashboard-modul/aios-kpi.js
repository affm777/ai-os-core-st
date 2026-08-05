/* AIOS — Modul Standorte: Standort-Kennzahlen aus /standort-kpi-dashboard
   Datenquelle: A.DATA.kpi (kanonisch, quellenneutral). Generisch gehalten: keine
   Standortnamen oder Monatszahlen im Code, alles kommt aus den Daten.

   Schema von ~/.claude/dashboard/data/kpi.json (Feld "data", siehe server.mjs):
   {
     "generated_at": "2026-07-28T10:00:00+02:00",
     "zeitraum": { "von": "2026-01", "bis": "2026-06" },   // Monate als "YYYY-MM"
     "standorte": [
       { "name": "Standort A", "monate": [
           { "monat": "2026-01", "umsatz_ist": 42000, "umsatz_plan": 45000,
             "kosten": 31000, "liquiditaet": 18000, "behandlungen": 120 }
           // fehlende Monate fehlen einfach im Array — KEINE Interpolation, KEINE 0-Fuellung.
       ] }
     ],
     "hinweise": []
   }
   Neuer Standort = neue Datei im Skill-Eingang, erscheint hier automatisch.
   Angezeigt: Umsatz Ist, Kosten, EBIT und Behandlungen
   (Decision 2026-07-29: Plan/Liquiditaet bleiben in den Rohdaten).
   EBIT kommt AUSSCHLIESSLICH aus dem ebit-Feld der Rohdaten und wird nie
   aus Umsatz minus Kosten hergeleitet (Decision 2026-07-29: EBIT wird
   gelesen, nicht gerechnet; die Berichtsvorlagen enthalten Abschreibungen,
   die naive Differenz läge messbar daneben). Fehlt das Feld in einem
   Berichtsmonat, zeigt die betroffene Summe ein "?" statt einer stillen
   Untertreibung oder Herleitung.
   Den Seitentitel setzt das Modul selbst (Opt-in-Modul: aios-system.js kennt
   die Seite nicht und wird vom Bootstrap überschrieben, also nicht gepatcht). */
(function(A){
"use strict";
var $=A.$,esc=A.esc,nf=A.nf,el=A.el,stateNote=A.stateNote,noteEl=A.noteEl;

/* Modul-eigenes CSS einmalig injizieren, statt index.html anzufassen.
   Alle Werte sind bestehende Host-Tokens (var(--card), var(--ok), ...). */
(function injectStyle(){
  if(document.getElementById("kpi-modul-style"))return;
  var s=document.createElement("style");
  s.id="kpi-modul-style";
  s.textContent=
    ".kloc-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(360px,1fr));gap:16px;align-items:stretch}"+
    ".kloc-card{padding:16px 18px 14px;display:flex;flex-direction:column}"+
    ".kloc-head{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap}"+
    ".kloc-name{font-family:var(--serif);font-size:19px;letter-spacing:-.01em}"+
    ".kviz-tip{position:fixed;z-index:300;background:var(--ink);color:var(--bg);font-size:12px;line-height:1.4;padding:7px 11px;border-radius:9px;pointer-events:none;white-space:nowrap;box-shadow:0 8px 24px rgba(0,0,0,.2);display:none}"+
    ".kchip{display:inline-flex;align-items:center;gap:6px;font-size:11.5px;font-weight:600;border-radius:999px;padding:3px 11px;white-space:nowrap}"+
    ".kchip.pos{color:var(--ok);background:var(--ok-bg)}"+
    ".kchip.neg{color:var(--fail);background:var(--fail-bg)}"+
    ".kfilter{align-items:center;gap:8px;margin-bottom:0}"+
    ".kfilter .filter-select{padding:6px 10px;font-size:12.5px}"+
    ".kfilter-sep{font-size:12px;color:var(--faint)}"+
    ".kcal-wrap{position:relative;display:inline-block}"+
    ".kcal-btn{white-space:nowrap}"+
    ".kcal{position:absolute;left:0;top:calc(100% + 6px);z-index:180;background:var(--card-solid);border:1px solid var(--border-2);border-radius:14px;box-shadow:0 12px 34px rgba(0,0,0,.14);padding:12px;width:252px}"+
    ".kcal-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:6px}"+
    ".kcal-y{font-weight:600;font-size:14px;font-variant-numeric:tabular-nums}"+
    ".kcal-nav{border:1px solid var(--border-2);background:transparent;border-radius:8px;width:26px;height:26px;cursor:pointer;font-size:13px;line-height:1;color:var(--ink)}"+
    ".kcal-nav:hover:not(:disabled){background:rgba(15,15,15,0.06)}"+
    ".kcal-nav:disabled{opacity:.3;cursor:default}"+
    ".kcal-hint{font-size:11px;color:var(--muted);margin-bottom:8px}"+
    ".kcal-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:6px}"+
    ".kcal-m{border:1px solid var(--border);background:transparent;border-radius:9px;padding:7px 0;font-size:12px;cursor:pointer;font-family:inherit;color:var(--text-2)}"+
    ".kcal-m:hover:not(:disabled){border-color:var(--ink);color:var(--ink)}"+
    ".kcal-m:disabled{opacity:.3;cursor:default}"+
    ".kcal-m.sel{background:var(--accent);border-color:var(--accent);color:#fff;font-weight:600}"+
    ".kcal-m.inr{background:var(--accent-soft);border-color:transparent;color:var(--ink)}"+
    ".kstats-cap{font-size:10px;letter-spacing:.14em;text-transform:uppercase;color:var(--muted);font-weight:700;margin-top:14px}"+
    ".kstats{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin:8px 0 4px;padding:10px 0;border-top:1px solid var(--divider);border-bottom:1px solid var(--divider)}"+
    ".kstat .n{font-family:var(--serif);font-size:19px;line-height:1;letter-spacing:-.01em;font-variant-numeric:tabular-nums;white-space:nowrap}"+
    ".kstat .l{font-size:10px;letter-spacing:.14em;text-transform:uppercase;color:var(--muted);font-weight:700;margin-top:4px}"+
    ".kdelta{display:block;font-size:10.5px;font-weight:600;margin-top:3px;font-variant-numeric:tabular-nums}"+
    ".kdelta.up{color:var(--ok)}.kdelta.down{color:var(--fail)}.kdelta.flat{color:var(--faint);font-weight:500}"+
    ".kviz-wrap{margin-top:8px}"+
    ".kviz{width:100%;height:auto;display:block;overflow:visible}"+
    ".kviz-legend{display:flex;gap:14px;margin-top:4px;font-size:11px;color:var(--muted)}"+
    ".kviz-legend-item{display:flex;align-items:center;gap:6px}"+
    ".kviz-legend-box{width:10px;height:10px;border-radius:2px;display:inline-block}"+
    ".kviz-legend-box.ist{background:var(--ok)}"+
    ".kviz-legend-line{width:14px;height:2px;border-radius:1px;display:inline-block;background:var(--accent)}"+
    ".kviz-sub-title{font-size:10px;letter-spacing:.14em;text-transform:uppercase;color:var(--muted);font-weight:700;margin:12px 0 0}"+
    ".kval-q{cursor:help;color:var(--faint);font-weight:600}"+
    ".kcmp-row{display:grid;grid-template-columns:minmax(100px,130px) 1fr 88px 168px;gap:14px;align-items:center;padding:10px 0;border-top:1px solid var(--divider);font-size:13px}"+
    ".kcmp-row:first-of-type{border-top:none}"+
    ".kcmp-row .nm{font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;min-width:0}"+
    ".kcmp-row .val{font-family:var(--mono);font-size:12.5px;color:var(--ink-2);text-align:right;white-space:nowrap}"+
    ".kcmp-row .kchip{justify-self:end;font-size:11px;padding:3px 9px}"+
    "@media (max-width:640px){.kcmp-row{grid-template-columns:minmax(90px,110px) 1fr 80px;gap:10px}.kcmp-row .kchip{display:none}}"+
    ".krank{display:block;min-width:0;height:8px;border-radius:999px;background:rgba(15,15,15,0.08);overflow:hidden}"+
    ".krank-fill{display:block;height:100%;border-radius:999px;background:var(--accent);min-width:8px}"+
    ".kov-grid{display:grid;grid-template-columns:1.5fr 1fr;gap:16px;align-items:stretch}"+
    "@media (max-width:980px){.kov-grid{grid-template-columns:1fr}}"+
    "@media (max-width:820px){.kstats{grid-template-columns:repeat(3,minmax(0,1fr))}.kloc-grid{grid-template-columns:1fr}}";
  document.head.appendChild(s);
})();

function cardOf(node){var c=el("div","card");c.appendChild(node);return c;}
function euro(n){return(typeof n==="number")?nf(Math.round(n))+" €":"—";}
function euroSigned(n){return(n>=0?"+":"−")+nf(Math.abs(Math.round(n)))+" €";}
function naSpan(title){return '<span class="kval-q" title="'+esc(title)+'">?</span>';}
function snapshotDate(data){return data.generated_at?new Date(data.generated_at).toLocaleDateString("de-DE"):"unbekannt";}

/* "2026-01".."2026-06" -> ["2026-01",...,"2026-06"], robust gegen kaputte Werte. */
function monthRange(von,bis){
  var out=[];
  var vm=/^(\d{4})-(\d{2})$/.exec(von||"");
  var bm=/^(\d{4})-(\d{2})$/.exec(bis||"");
  if(!vm||!bm)return out;
  var y=+vm[1],m=+vm[2],ey=+bm[1],em=+bm[2];
  var guard=0;
  while((y<ey||(y===ey&&m<=em))&&guard<600){
    out.push(y+"-"+(m<10?"0":"")+m);
    m++;if(m>12){m=1;y++;}
    guard++;
  }
  return out;
}
function collectAllMonths(standorte){
  var set={};
  standorte.forEach(function(s){(s.monate||[]).forEach(function(mo){if(mo&&mo.monat)set[mo.monat]=true;});});
  return Object.keys(set).sort();
}
var MONTH_LABELS={"01":"Jan","02":"Feb","03":"Mrz","04":"Apr","05":"Mai","06":"Jun","07":"Jul","08":"Aug","09":"Sep","10":"Okt","11":"Nov","12":"Dez"};
function monthLabel(k){var m=/^(\d{4})-(\d{2})$/.exec(k||"");if(!m)return k||"?";return(MONTH_LABELS[m[2]]||m[2])+" "+m[1].slice(2);}
function monatMap(standort){var map={};(standort.monate||[]).forEach(function(mo){if(mo&&mo.monat)map[mo.monat]=mo;});return map;}
/* Ab 7 Monaten nur jeden zweiten beschriften (Anfang und Ende immer). */
function shouldLabelMonth(i,total){return total<=6||i%2===0||i===total-1;}

/* Standort-uebergreifende Summe je Monat, keine Interpolation. */
function aggregateStandorte(standorte,months){
  var map={};
  months.forEach(function(mk){
    var ist=null,kosten=null,beh=null,any=false;
    standorte.forEach(function(s){
      var mo=monatMap(s)[mk];
      if(!mo)return;
      if(typeof mo.umsatz_ist==="number"){ist=(ist||0)+mo.umsatz_ist;any=true;}
      if(typeof mo.kosten==="number"){kosten=(kosten||0)+mo.kosten;any=true;}
      if(typeof mo.behandlungen==="number"){beh=(beh||0)+mo.behandlungen;any=true;}
    });
    if(any)map[mk]={monat:mk,umsatz_ist:ist===null?undefined:ist,kosten:kosten===null?undefined:kosten,behandlungen:beh===null?undefined:beh};
  });
  return map;
}
function sumField(map,months,field){
  var sum=0,any=false;
  months.forEach(function(mk){var mo=map[mk];if(mo&&typeof mo[field]==="number"){sum+=mo[field];any=true;}});
  return any?sum:null;
}
/* EBIT je Zeitraum: Summe der gelesenen ebit-Werte über alle übergebenen
   Monats-Maps, aber nur, wenn JEDER Monat mit Daten auch einen trägt.
   Sonst null: lieber ein "?" als eine still untertriebene Summe, und
   niemals eine Herleitung aus Umsatz minus Kosten. */
function ebitSum(maps,months){
  var sum=0,any=false;
  for(var i=0;i<maps.length;i++){
    for(var j=0;j<months.length;j++){
      var mo=maps[i][months[j]];
      if(!mo)continue;
      if(typeof mo.ebit!=="number")return null;
      sum+=mo.ebit;any=true;
    }
  }
  return any?sum:null;
}
/* Letzter erfasster Wert + Vormonatswert fuer die Trend-Anzeige.
   "Vormonat" = der davor liegende Monat MIT Wert, Luecken werden uebersprungen. */
function lastWithPrev(map,months,field){
  var vals=[];
  months.forEach(function(mk){var mo=map[mk];if(mo&&typeof mo[field]==="number")vals.push({mk:mk,v:mo[field]});});
  if(!vals.length)return null;
  var last=vals[vals.length-1],prev=vals.length>1?vals[vals.length-2]:null;
  return{mk:last.mk,v:last.v,prev:prev?prev.v:null};
}
/* Trend-Zeile: Pfeil + Prozent gegen den Vormonat (Luecken werden uebersprungen).
   invert=true fuer Kosten (weniger ist gut). */
function deltaHtml(lw,invert){
  if(!lw||lw.prev==null||lw.prev===0)return '<span class="kdelta flat">kein Vormonatswert</span>';
  var pct=(lw.v-lw.prev)/lw.prev*100;
  if(Math.abs(pct)<0.05)return '<span class="kdelta flat">± 0 %</span>';
  var good=invert?pct<0:pct>0;
  var arrow=pct>0?"▲":"▼";
  return '<span class="kdelta '+(good?"up":"down")+'">'+arrow+" "+Math.abs(pct).toFixed(1).replace(".",",")+' %</span>';
}
/* Gemeinsamer Hover-Tooltip fuer alle Chart-Punkte (ein Element, folgt dem
   Zeiger). Delegiert auf [data-tip]-Flaechen, funktioniert auch fuer Touch. */
function ensureTip(){
  var t=document.getElementById("kvizTip");
  if(!t){t=el("div","kviz-tip");t.id="kvizTip";document.body.appendChild(t);}
  return t;
}
function wireTips(wrap){
  if(wrap.__kpiTipsWired)return;wrap.__kpiTipsWired=true;
  var tip=ensureTip();
  wrap.addEventListener("pointerover",function(e){var z=e.target.closest?e.target.closest("[data-tip]"):null;if(!z)return;tip.textContent=z.getAttribute("data-tip");tip.style.display="block";});
  wrap.addEventListener("pointermove",function(e){if(tip.style.display!=="block")return;var x=Math.min(e.clientX+14,window.innerWidth-tip.offsetWidth-10);tip.style.left=x+"px";tip.style.top=(e.clientY+18)+"px";});
  wrap.addEventListener("pointerout",function(e){var z=e.target.closest?e.target.closest("[data-tip]"):null;if(z)tip.style.display="none";});
}

/* ---------- KPI-Kacheln oben ---------- */
function kpiTile(strip,n,l,s,cls){
  var t=el("div","ktile"+(cls?" "+cls:""));
  t.innerHTML='<div class="n">'+n+'</div><div class="l">'+esc(l)+'</div>'+(s?'<div class="s">'+esc(s)+"</div>":"");
  strip.appendChild(t);
}
function renderKpiStrip(wrap,standorte,months,aggMap){
  var sumIst=sumField(aggMap,months,"umsatz_ist");
  var sumKosten=sumField(aggMap,months,"kosten");
  var sumBeh=sumField(aggMap,months,"behandlungen");
  var zeitraum=months.length?monthLabel(months[0])+" bis "+monthLabel(months[months.length-1]):"";
  var strip=el("div","kpi-strip kpi-row");
  kpiTile(strip,sumIst!=null?euro(sumIst):naSpan("Noch keine Umsatzwerte erfasst"),"Umsatz gesamt",zeitraum+" · "+nf(standorte.length)+" Standort"+(standorte.length===1?"":"e"));
  kpiTile(strip,sumKosten!=null?euro(sumKosten):naSpan("Noch keine Kostenwerte erfasst"),"Kosten gesamt",zeitraum);
  var ebit=ebitSum(standorte.map(monatMap),months);
  var marge=(ebit!=null&&sumIst>0)?Math.round(ebit/sumIst*100):null;
  kpiTile(strip,ebit!=null?euroSigned(ebit):naSpan("EBIT fehlt in mindestens einem Berichtsmonat"),"EBIT",marge!=null?("aus den Berichten · Marge "+marge+" %"):"aus den Berichten übernommen, nie gerechnet",ebit!=null&&ebit<0?"alert":"");
  var avg=(sumIst!=null&&sumBeh)?sumIst/sumBeh:null;
  kpiTile(strip,sumBeh!=null?nf(sumBeh):naSpan("Noch keine Behandlungszahlen erfasst"),"Behandlungen",avg!=null?("Ø "+euro(avg)+" Umsatz je Behandlung"):zeitraum);
  wrap.appendChild(strip);
}

/* ---------- Inline-SVG-Charts (kein externes Chart-Lib) ----------
   Umsatz Ist als Balken (var(--ok)) + Kosten als Linie (var(--accent)), EINE
   gemeinsame Skala. Fehlende Monate: gestrichelte Luecken-Markierung statt
   0-Balken; fehlt nur der Kosten-Wert, bricht die Linie dort ab. */
function buildUmsatzKostenSvg(months,map,opts){
  opts=opts||{};
  /* Feste Design-Breite: die viewBox entspricht ungefaehr den realen Pixeln
     der Karte, damit Balken und Beschriftung nicht vom Browser hochskaliert
     werden. Spalten verteilen sich ueber die Breite. */
  var W=opts.designW||560,padTop=opts.padTop||8,padBottom=opts.padBottom||18,plotH=opts.plotH||72;
  var colW=W/months.length;
  var barW=Math.min(opts.barW||16,Math.max(6,Math.round(colW*0.4)));
  var H=padTop+plotH+padBottom;
  var maxVal=1;
  months.forEach(function(mk){
    var mo=map[mk];if(!mo)return;
    if(typeof mo.umsatz_ist==="number")maxVal=Math.max(maxVal,mo.umsatz_ist);
    if(typeof mo.kosten==="number")maxVal=Math.max(maxVal,mo.kosten);
  });
  var baseY=padTop+plotH;
  function yFor(v){return baseY-(v/maxVal*plotH);}
  var svg='<svg class="kviz" viewBox="0 0 '+W+' '+H+'" role="img" aria-label="Umsatz und Kosten je Monat">';
  svg+='<line x1="0" y1="'+baseY+'" x2="'+W+'" y2="'+baseY+'" stroke="var(--divider)" stroke-width="1"/>';
  months.forEach(function(mk,i){
    var cx=i*colW+colW/2,x=cx-barW/2;
    var mo=map[mk];
    if(!mo){
      svg+='<line x1="'+cx+'" y1="'+(baseY-6)+'" x2="'+cx+'" y2="'+baseY+'" stroke="var(--faint)" stroke-width="1.5" stroke-dasharray="2,2"><title>'+esc(monthLabel(mk))+': kein Wert erfasst</title></line>';
      svg+='<text x="'+cx+'" y="'+(baseY-10)+'" text-anchor="middle" font-size="10" fill="var(--faint)">?</text>';
    }else if(typeof mo.umsatz_ist==="number"){
      var h=Math.max(Math.round(mo.umsatz_ist/maxVal*plotH),2);
      svg+='<rect x="'+x+'" y="'+(baseY-h)+'" width="'+barW+'" height="'+h+'" rx="3" ry="3" fill="var(--ok)"><title>'+esc(monthLabel(mk))+' Umsatz: '+esc(euro(mo.umsatz_ist))+'</title></rect>';
    }
    if(shouldLabelMonth(i,months.length))svg+='<text x="'+cx+'" y="'+(H-4)+'" text-anchor="middle" font-size="10" fill="var(--muted)">'+esc(monthLabel(mk))+'</text>';
  });
  var seg=[];
  function flushSeg(){
    if(seg.length>1){
      var d="M"+seg[0].x+","+seg[0].y;
      for(var k=1;k<seg.length;k++)d+=" L"+seg[k].x+","+seg[k].y;
      svg+='<path d="'+d+'" fill="none" stroke="var(--accent)" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>';
    }
    seg=[];
  }
  months.forEach(function(mk,i){
    var mo=map[mk];
    var kv=mo&&typeof mo.kosten==="number"?mo.kosten:null;
    if(kv==null){flushSeg();}else{seg.push({x:i*colW+colW/2,y:yFor(kv)});}
  });
  flushSeg();
  months.forEach(function(mk,i){
    var mo=map[mk];
    var kv=mo&&typeof mo.kosten==="number"?mo.kosten:null;
    if(kv!=null){
      svg+='<circle cx="'+(i*colW+colW/2)+'" cy="'+yFor(kv)+'" r="2.6" fill="var(--accent)" stroke="var(--card-solid)" stroke-width="1.5"><title>'+esc(monthLabel(mk))+' Kosten: '+esc(euro(kv))+'</title></circle>';
    }
  });
  months.forEach(function(mk,i){
    var mo=map[mk];
    var parts=[monthLabel(mk)];
    if(!mo)parts.push("kein Wert erfasst");
    else{
      parts.push("Umsatz "+(typeof mo.umsatz_ist==="number"?euro(mo.umsatz_ist):"?"));
      parts.push("Kosten "+(typeof mo.kosten==="number"?euro(mo.kosten):"?"));
      if(typeof mo.ebit==="number")parts.push("EBIT "+euroSigned(mo.ebit));
    }
    svg+='<rect x="'+(i*colW)+'" y="0" width="'+colW+'" height="'+H+'" fill="transparent" data-tip="'+esc(parts.join(" · "))+'"/>';
  });
  svg+='</svg>';
  return svg;
}
/* Behandlungszahlen: kleine einfarbige Balken, EINE Serie. */
function buildBehandlungenSvg(months,map,opts){
  opts=opts||{};
  var W=opts.designW||560,padTop=opts.padTop||4,padBottom=opts.padBottom||16,plotH=opts.plotH||34;
  var colW=W/months.length;
  var barW=Math.min(opts.barW||10,Math.max(5,Math.round(colW*0.3)));
  var H=padTop+plotH+padBottom;
  var maxV=1;
  months.forEach(function(mk){var mo=map[mk];if(mo&&typeof mo.behandlungen==="number")maxV=Math.max(maxV,mo.behandlungen);});
  var baseY=padTop+plotH;
  var svg='<svg class="kviz" viewBox="0 0 '+W+' '+H+'" role="img" aria-label="Behandlungszahlen je Monat">';
  svg+='<line x1="0" y1="'+baseY+'" x2="'+W+'" y2="'+baseY+'" stroke="var(--divider)" stroke-width="1"/>';
  months.forEach(function(mk,i){
    var cx=i*colW+colW/2,x=cx-barW/2;
    var mo=map[mk];
    var v=mo&&typeof mo.behandlungen==="number"?mo.behandlungen:null;
    if(v==null){
      svg+='<line x1="'+cx+'" y1="'+(baseY-5)+'" x2="'+cx+'" y2="'+baseY+'" stroke="var(--faint)" stroke-width="1.5" stroke-dasharray="2,2"><title>'+esc(monthLabel(mk))+': kein Wert erfasst</title></line>';
    }else{
      var h=Math.max(Math.round(v/maxV*plotH),2);
      svg+='<rect x="'+x+'" y="'+(baseY-h)+'" width="'+barW+'" height="'+h+'" rx="2.5" ry="2.5" fill="var(--muted)"><title>'+esc(monthLabel(mk))+': '+nf(v)+' Behandlungen</title></rect>';
    }
    if(shouldLabelMonth(i,months.length))svg+='<text x="'+cx+'" y="'+(H-3)+'" text-anchor="middle" font-size="9.5" fill="var(--muted)">'+esc(monthLabel(mk))+'</text>';
  });
  months.forEach(function(mk,i){
    var mo=map[mk];
    var v=mo&&typeof mo.behandlungen==="number"?mo.behandlungen:null;
    svg+='<rect x="'+(i*colW)+'" y="0" width="'+colW+'" height="'+H+'" fill="transparent" data-tip="'+esc(monthLabel(mk)+" · "+(v==null?"kein Wert erfasst":nf(v)+" Behandlungen"))+'"/>';
  });
  svg+='</svg>';
  return svg;
}
function umsatzKostenLegend(){
  var legend=el("div","kviz-legend");
  legend.innerHTML='<span class="kviz-legend-item"><span class="kviz-legend-box ist"></span>Umsatz Ist</span><span class="kviz-legend-item"><span class="kviz-legend-line"></span>Kosten</span>';
  return legend;
}

/* ---------- Gesamtansicht + Standort-Vergleich nebeneinander ---------- */
/* Chart-Slots: erst leere Wrapper einhaengen, dann die ECHTE Breite messen und
   das SVG mit genau dieser Design-Breite bauen (viewBox 1:1 zu den Pixeln).
   Ein ResizeObserver baut das SVG neu, wenn sich die Slot-Breite aendert:
   Sidebar-Transition beim Laden, Sidebar-Toggle, Fenster-Resize. Der Rebuild
   ist reine String-Erzeugung und damit billig. */
var slotRO=("ResizeObserver" in window)?new ResizeObserver(function(entries){
  entries.forEach(function(en){
    var n=en.target;if(!n.__kvizBuild)return;
    var w=Math.round(n.clientWidth||0);
    if(w<40||Math.abs(w-(n.__kvizW||0))<6)return;
    n.__kvizW=w;
    n.innerHTML=n.__kvizBuild(Math.max(240,w));
  });
}):null;
function vizSlot(fills,build){
  var d=el("div","kviz-wrap");
  d.__kvizBuild=build;
  fills.push(d);
  return d;
}
function fillSlots(fills){
  fills.forEach(function(d){
    var w=Math.max(240,Math.round(d.clientWidth||560));
    d.__kvizW=w;
    d.innerHTML=d.__kvizBuild(w);
    if(slotRO)slotRO.observe(d);
  });
}
function ergChip(erg,ist,periodLabel){
  if(erg==null)return"";
  var marge=(ist>0)?Math.round(erg/ist*100):null;
  return '<span class="kchip '+(erg>=0?"pos":"neg")+'" title="EBIT '+esc(periodLabel||"")+': aus den Berichten übernommen, nie gerechnet'+(marge!=null?", EBIT-Marge "+marge+" %":"")+'">'+esc(euroSigned(erg))+(marge!=null?" · "+marge+" % Marge":" EBIT")+'</span>';
}
function renderOverview(wrap,standorte,months,aggMap,fills,periodLabel){
  var sec=el("section","blk");
  sec.style.marginTop="32px";
  var head=el("div","sec-head");
  head.innerHTML='<span class="kick">Gesamtansicht</span><h2>Alle Standorte <em>zusammen</em></h2><span class="rule"></span>';
  sec.appendChild(head);
  var grid=el("div","kov-grid");
  // links: Verlauf
  var cL=el("div","card kloc-card");
  cL.appendChild(el("div","bars-title","Umsatz und Kosten je Monat"));
  cL.appendChild(vizSlot(fills,function(w){return buildUmsatzKostenSvg(months,aggMap,{designW:w,barW:22,plotH:120});}));
  cL.appendChild(umsatzKostenLegend());
  grid.appendChild(cL);
  // rechts: Ranking nach Umsatz im Zeitraum
  var cR=el("div","card kloc-card");
  cR.appendChild(el("div","bars-title","Standorte nach Umsatz · "+esc(periodLabel)));
  var rows=standorte.map(function(s){
    var map=monatMap(s);
    var ist=sumField(map,months,"umsatz_ist");
    return{name:s.name||"Unbenannter Standort",ist:ist,erg:ebitSum([map],months)};
  }).sort(function(a,b){return(b.ist||0)-(a.ist||0);});
  var maxIst=Math.max.apply(null,rows.map(function(r){return r.ist||0;}).concat([1]));
  rows.forEach(function(r){
    var row=el("div","kcmp-row");
    row.innerHTML='<span class="nm" title="'+esc(r.name)+'">'+esc(r.name)+'</span><span class="krank"><span class="krank-fill" style="width:'+Math.max(2,Math.round((r.ist||0)/maxIst*100))+'%"></span></span><span class="val">'+(r.ist!=null?esc(euro(r.ist)):naSpan("Kein Umsatz erfasst"))+'</span>'+ergChip(r.erg,r.ist,periodLabel);
    cR.appendChild(row);
  });
  grid.appendChild(cR);
  sec.appendChild(grid);
  wrap.appendChild(sec);
}

/* ---------- Karte je Standort ---------- */
function statHtml(label,valueHtml,delta){
  return '<div class="kstat"><div class="n">'+valueHtml+'</div><div class="l">'+esc(label)+'</div>'+delta+'</div>';
}
function renderStandortCard(grid,s,months,fills,periodLabel){
  var map=monatMap(s);
  var ist=sumField(map,months,"umsatz_ist");
  var erg=ebitSum([map],months);

  var card=el("div","card kloc-card");
  var head=el("div","kloc-head");
  head.innerHTML='<span class="kloc-name">'+esc(s.name||"Unbenannter Standort")+'</span>'+ergChip(erg,ist,periodLabel);
  card.appendChild(head);

  // Kennzahlen des letzten erfassten Monats, mit Trend gegen den Vormonat
  var lwU=lastWithPrev(map,months,"umsatz_ist");
  var lwK=lastWithPrev(map,months,"kosten");
  var lwB=lastWithPrev(map,months,"behandlungen");
  /* Der letzte erfasste Monat steht EINMAL in der Zeile ueber den Kennzahlen.
     Nur wenn eine Kennzahl aelter ist (Luecke), traegt sie ihren Monat selbst. */
  var mks=[lwU,lwK,lwB].filter(Boolean).map(function(x){return x.mk;});
  var refMk=mks.length?mks.slice().sort()[mks.length-1]:null;
  function stLabel(base,lw){return base+((lw&&lw.mk!==refMk)?" · "+monthLabel(lw.mk):"");}
  if(refMk)card.appendChild(el("div","kstats-cap","Stand "+esc(monthLabel(refMk))+" · Trend zum Vormonat"));
  var stats=el("div","kstats");
  stats.innerHTML=
    statHtml(stLabel("Umsatz",lwU),lwU?esc(euro(lwU.v)):naSpan("Kein Wert erfasst"),deltaHtml(lwU,false))+
    statHtml(stLabel("Kosten",lwK),lwK?esc(euro(lwK.v)):naSpan("Kein Wert erfasst"),deltaHtml(lwK,true))+
    statHtml(stLabel("Behandlungen",lwB),lwB?nf(lwB.v):naSpan("Kein Wert erfasst"),deltaHtml(lwB,false));
  card.appendChild(stats);

  card.appendChild(vizSlot(fills,function(w){return buildUmsatzKostenSvg(months,map,{designW:w,barW:14,plotH:64});}));
  card.appendChild(umsatzKostenLegend());
  card.appendChild(el("div","kviz-sub-title","Behandlungszahlen"));
  card.appendChild(vizSlot(fills,function(w){return buildBehandlungenSvg(months,map,{designW:w});}));
  grid.appendChild(card);
}

/* ---------- Zeitraum-Filter ----------
   Ein Dropdown mit Presets (Gesamt, aktuelles/letztes Jahr, letzte 3/6 Monate,
   eigener Zeitraum); die Von/Bis-Monatsauswahl erscheint nur bei "eigener
   Zeitraum". Auswahl lebt im Modul-Zustand und uebersteht das Neuzeichnen. */
var kpiRange={mode:"all",von:null,bis:null};
function applyRange(baseMonths){
  if(!baseMonths.length)return baseMonths;
  var lastY=baseMonths[baseMonths.length-1].slice(0,4);
  if(kpiRange.mode==="all")return baseMonths;
  if(kpiRange.mode==="last3")return baseMonths.slice(-3);
  if(kpiRange.mode==="last6")return baseMonths.slice(-6);
  if(kpiRange.mode==="yearCur")return baseMonths.filter(function(mk){return mk.slice(0,4)===lastY;});
  if(kpiRange.mode==="yearPrev")return baseMonths.filter(function(mk){return mk.slice(0,4)===String(+lastY-1);});
  if(kpiRange.mode==="custom"){
    var von=kpiRange.von||baseMonths[0],bis=kpiRange.bis||baseMonths[baseMonths.length-1];
    if(von>bis){var t=von;von=bis;bis=t;}
    return baseMonths.filter(function(mk){return mk>=von&&mk<=bis;});
  }
  return baseMonths;
}
function renderRangeFilter(wrap,baseMonths,months){
  var lastY=baseMonths.length?baseMonths[baseMonths.length-1].slice(0,4):null;
  var hasPrevYear=baseMonths.some(function(mk){return mk.slice(0,4)===String(+lastY-1);});
  var row=el("div","chips kfilter");
  var presets=[["all","Gesamter Zeitraum"]];
  if(hasPrevYear){presets.push(["yearCur","Jahr "+lastY]);presets.push(["yearPrev","Jahr "+(+lastY-1)]);}
  if(baseMonths.length>6)presets.push(["last6","Letzte 6 Monate"]);
  if(baseMonths.length>3)presets.push(["last3","Letzte 3 Monate"]);
  presets.push(["custom","Eigener Zeitraum"]);
  var preset=el("select","filter-select");
  preset.setAttribute("aria-label","Zeitraum");
  presets.forEach(function(p){
    var o=el("option");o.value=p[0];o.textContent=p[1];if(kpiRange.mode===p[0])o.selected=true;
    preset.appendChild(o);
  });
  preset.addEventListener("change",function(){
    var m=preset.value;
    kpiRange=(m==="custom")?{mode:"custom",von:months[0]||baseMonths[0],bis:months[months.length-1]||baseMonths[baseMonths.length-1]}:{mode:m,von:null,bis:null};
    A.pages.kpi();
  });
  row.appendChild(preset);
  if(kpiRange.mode==="custom"){
    /* Kalender-Popover statt endloser Monats-Dropdowns: Jahr blaettern,
       Monat klicken (erst Start-, dann Endmonat), Auswahl kann Jahresgrenzen
       ueberschreiten. Monate ohne Daten sind deaktiviert. */
    var von=kpiRange.von||baseMonths[0],bis=kpiRange.bis||baseMonths[baseMonths.length-1];
    var cwrap=el("span","kcal-wrap");
    var btn=el("button","filter-select kcal-btn",esc(monthLabel(von))+" bis "+esc(monthLabel(bis)));
    btn.setAttribute("aria-haspopup","dialog");
    btn.title="Zeitraum im Kalender wählen";
    cwrap.appendChild(btn);
    row.appendChild(cwrap);
    var pop=null,tempVon=null,curY=+von.slice(0,4);
    var minY=+baseMonths[0].slice(0,4),maxY=+baseMonths[baseMonths.length-1].slice(0,4);
    function closeCal(){if(pop){pop.remove();pop=null;}document.removeEventListener("click",outside,true);}
    function outside(e){if(pop&&!cwrap.contains(e.target))closeCal();}
    function drawCal(){
      pop.innerHTML="";
      var head=el("div","kcal-head");
      var prev=el("button","kcal-nav","‹");prev.setAttribute("aria-label","Vorheriges Jahr");prev.disabled=curY<=minY;
      var next=el("button","kcal-nav","›");next.setAttribute("aria-label","Nächstes Jahr");next.disabled=curY>=maxY;
      prev.addEventListener("click",function(){curY--;drawCal();});
      next.addEventListener("click",function(){curY++;drawCal();});
      head.appendChild(prev);head.appendChild(el("span","kcal-y",String(curY)));head.appendChild(next);
      pop.appendChild(head);
      pop.appendChild(el("div","kcal-hint",tempVon?"Endmonat wählen (Start: "+esc(monthLabel(tempVon))+")":"Startmonat wählen"));
      var grid=el("div","kcal-grid");
      for(var m=1;m<=12;m++){
        var mm=(m<10?"0":"")+m,mk=curY+"-"+mm;
        var b=el("button","kcal-m",MONTH_LABELS[mm]);
        b.disabled=baseMonths.indexOf(mk)===-1;
        if(tempVon){if(mk===tempVon)b.classList.add("sel");}
        else{
          if(mk===von||mk===bis)b.classList.add("sel");
          else if(mk>von&&mk<bis)b.classList.add("inr");
        }
        (function(mk){b.addEventListener("click",function(){
          if(!tempVon){tempVon=mk;drawCal();return;}
          var a=tempVon,z=mk;if(a>z){var t=a;a=z;z=t;}
          kpiRange={mode:"custom",von:a,bis:z};
          closeCal();A.pages.kpi();
        });})(mk);
        grid.appendChild(b);
      }
      pop.appendChild(grid);
    }
    btn.addEventListener("click",function(e){
      e.stopPropagation();
      if(pop){closeCal();return;}
      pop=el("div","kcal");pop.setAttribute("role","dialog");pop.setAttribute("aria-label","Zeitraum wählen");
      tempVon=null;curY=+(kpiRange.von||baseMonths[0]).slice(0,4);
      drawCal();cwrap.appendChild(pop);
      document.addEventListener("click",outside,true);
    });
    row.appendChild(el("span","kfilter-sep",months.length+" Monate"));
  }else{
    row.appendChild(el("span","kfilter-sep",months.length?monthLabel(months[0])+" bis "+monthLabel(months[months.length-1])+" · "+months.length+" Monate":""));
  }
  wrap.appendChild(row);
}

/* ---------- Seite ---------- */
function guardSection(wrap){
  var sec=A.DATA.kpi;
  var note=stateNote(sec,"Kennzahlen","Noch keine Kennzahlen. Lauf /standort-kpi-dashboard einrichten.");
  if(!sec||!sec.present){wrap.appendChild(cardOf(noteEl(note)));return null;}
  return{sec:sec,data:sec.data||{}};
}
A.pages.kpi=function(){
  /* Titel selbst setzen: renderPage() läuft vorher und leert Titel und
     Untertitel, weil TITLES in aios-system.js diese Seite nicht kennt.
     Guard auf leeren Titel, falls eine spätere Core-Version sie doch kennt. */
  var tt=$("pageTitle"),ts=$("pageSub");
  if(tt&&!tt.textContent){tt.textContent="Standorte";if(ts)ts.textContent="Kennzahlen je Standort: Umsatz, Kosten und Behandlungszahlen.";}
  var wrap=$("kpiWrap");wrap.innerHTML="";
  var ctx=guardSection(wrap);if(!ctx)return;
  var data=ctx.data;
  var standorte=data.standorte||[];
  if(!standorte.length){
    wrap.appendChild(cardOf(el("div","quiet","Noch keine Kennzahlen. Lauf /standort-kpi-dashboard einrichten.")));
    return;
  }
  var baseMonths=monthRange(data.zeitraum&&data.zeitraum.von,data.zeitraum&&data.zeitraum.bis);
  if(!baseMonths.length)baseMonths=collectAllMonths(standorte);
  var months=applyRange(baseMonths);
  if(!months.length)months=baseMonths;

  renderRangeFilter(wrap,baseMonths,months);
  var aggMap=aggregateStandorte(standorte,months);
  var fills=[];
  var periodLabel=months.length?monthLabel(months[0])+" bis "+monthLabel(months[months.length-1]):"";
  wireTips(wrap);
  renderKpiStrip(wrap,standorte,months,aggMap);
  renderOverview(wrap,standorte,months,aggMap,fills,periodLabel);

  var gridSec=el("section","blk");
  var gridHead=el("div","sec-head");
  gridHead.innerHTML='<span class="kick">Je Standort</span><h2>Standorte im <em>Detail</em></h2><span class="rule"></span><span class="aside">Kennzahlen: letzter erfasster Monat · EBIT: '+esc(periodLabel)+'</span>';
  gridSec.appendChild(gridHead);
  var grid=el("div","kloc-grid");
  standorte.forEach(function(s){renderStandortCard(grid,s,months,fills,periodLabel);});
  gridSec.appendChild(grid);
  wrap.appendChild(gridSec);
  fillSlots(fills);

  if(data.hinweise&&data.hinweise.length){
    var hc=el("div","card");hc.style.marginTop="24px";
    hc.appendChild(el("div","bars-title","Hinweise"));
    data.hinweise.forEach(function(h){hc.appendChild(el("div","hint-line",esc(h)));});
    wrap.appendChild(hc);
  }
  if(ctx.sec.freshness==="stale"){
    wrap.appendChild(el("div","hint-line","Stand vom "+esc(snapshotDate(data))+". Neue Zahlen über /standort-kpi-dashboard einreichen."));
  }
};
})(window.AIOS);
