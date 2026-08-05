/* AIOS — Second-Brain-Netz (Canvas) */
(function(A){
"use strict";
var $=A.$,nf=A.nf,esc=A.esc;
var Brain=(function(){
  var canvas,ctx,W=0,H=0,DPR=Math.min(window.devicePixelRatio||1,2);
  var nodes=[],edges=[],meshEdges=[],clusters=[];
  var rotY=0,rotX=-0.42,velY=0.00055,dragV=0,dragging=false,lastX=0,lastY=0,tiltV=0;
  var t=0,hoverCluster=null,selected=null,raf=null,mouse={x:-1,y:-1,active:false},over=false;
  var reducedMotion=!!(window.matchMedia&&window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  var visible=true,tabActive=!document.hidden,io=null;
  function init(){
    canvas=$("brainCanvas");ctx=canvas.getContext("2d");
    window.addEventListener("resize",resize);
    canvas.addEventListener("mousedown",down);window.addEventListener("mousemove",move);window.addEventListener("mouseup",up);
    canvas.addEventListener("mouseenter",function(){over=true;});
    canvas.addEventListener("mouseleave",function(){mouse.active=false;over=false;if(reducedMotion)doFrame();});
    canvas.addEventListener("touchstart",function(e){down(e);},{passive:true});
    canvas.addEventListener("touchmove",function(e){move(e);e.preventDefault();},{passive:false});
    canvas.addEventListener("touchend",up);
    canvas.addEventListener("click",function(){if(hoverCluster){selected=(selected===hoverCluster?null:hoverCluster);}else if(selected){selected=null;}if(reducedMotion)doFrame();});
    if("IntersectionObserver" in window){
      io=new IntersectionObserver(function(entries){
        entries.forEach(function(en){visible=en.isIntersecting;});
        if(visible)ensureLoop();else stopLoop();
      },{threshold:0.01});
      io.observe(canvas);
    }
    document.addEventListener("visibilitychange",function(){
      tabActive=!document.hidden;
      if(tabActive)ensureLoop();else stopLoop();
    });
  }
  function stopLoop(){if(raf){cancelAnimationFrame(raf);raf=null;}}
  function ensureLoop(){
    if(!nodes.length)return;
    if(reducedMotion){doFrame();return;}
    if(!raf&&visible&&tabActive)raf=requestAnimationFrame(tick);
  }
  function resize(){if(!canvas)return;var r=canvas.getBoundingClientRect();W=r.width;H=r.height;canvas.width=W*DPR;canvas.height=H*DPR;ctx.setTransform(DPR,0,0,DPR,0,0);if(reducedMotion)doFrame();}
  function build(byCluster,total){
    nodes=[];edges=[];meshEdges=[];clusters=[];
    var entries=Object.keys(byCluster||{}).map(function(k){return{name:k,count:byCluster[k]};}).sort(function(a,b){return b.count-a.count;});
    var clusterSum=entries.reduce(function(s,e){return s+e.count;},0);
    var grand=Math.max(total||0,clusterSum);
    if(!grand)return;
    var residual=Math.max(0,grand-clusterSum);   // ungetaggte Notizen (total - Summe der Cluster)
    var nc=entries.length;
    var gold=Math.PI*(3-Math.sqrt(5));
    entries.forEach(function(e,ci){
      var y=nc>1?1-(ci/(nc-1))*2:0; var rad=Math.sqrt(Math.max(0,1-y*y)); var th=gold*ci;
      var home=[Math.cos(th)*rad,y,Math.sin(th)*rad];
      var cnt=Math.max(1,e.count);                       // ein Punkt je Notiz, keine Skalierung mehr
      var cluster={name:e.name,count:e.count,home:home,ci:ci,members:[],lx:0,ly:0,lz:0};
      var spread=0.09+0.14*Math.min(1,cnt/200);
      var leader={cluster:cluster,leader:true,base:home.slice(),phase:Math.random()*6.28,phase2:Math.random()*6.28,r0:2.6+Math.min(7,e.count/grand*120),hl:0};
      nodes.push(leader);cluster.leaderNode=leader;cluster.members.push(leader);
      for(var i=1;i<cnt;i++){
        var v=[home[0]+(Math.random()*2-1)*spread,home[1]+(Math.random()*2-1)*spread,home[2]+(Math.random()*2-1)*spread];
        var L=Math.hypot(v[0],v[1],v[2])||1;v=[v[0]/L,v[1]/L,v[2]/L];
        nodes.push({cluster:cluster,leader:false,base:v,phase:Math.random()*6.28,phase2:Math.random()*6.28,r0:1.0+Math.random()*1.2,hl:0});
        cluster.members.push(nodes[nodes.length-1]);
      }
      clusters.push(cluster);
    });
    // Ungetaggte Notizen als neutrale Umgebungswolke (Golden-Spiral ueber die Kugel),
    // damit die sichtbare Punktzahl exakt der Hero-Zahl entspricht.
    for(var r=0;r<residual;r++){
      var yy=1-((r+0.5)/residual)*2; var rr=Math.sqrt(Math.max(0,1-yy*yy)); var tt=gold*(r+nc);
      nodes.push({cluster:null,residual:true,leader:false,base:[Math.cos(tt)*rr,yy,Math.sin(tt)*rr],phase:Math.random()*6.28,phase2:Math.random()*6.28,r0:0.8+Math.random()*0.7,hl:0});
    }
    // Kanten als Cluster-Speichen (Leader->Mitglied) + Leader-zu-Leader-Band.
    clusters.forEach(function(c){for(var i=1;i<c.members.length;i++){edges.push([c.leaderNode,c.members[i],0.09]);}});
    for(var k=0;k<clusters.length;k++){var la=clusters[k].leaderNode,bb=-1,bdd=9;for(var m=0;m<clusters.length;m++){if(k===m)continue;var lb=clusters[m].leaderNode;var d2=(la.base[0]-lb.base[0])*(la.base[0]-lb.base[0])+(la.base[1]-lb.base[1])*(la.base[1]-lb.base[1])+(la.base[2]-lb.base[2])*(la.base[2]-lb.base[2]);if(d2<bdd){bdd=d2;bb=m;}}if(bb>=0)edges.push([la,clusters[bb].leaderNode,0.09]);}
    buildMesh();
    $("brainClusters").textContent=clusters.length;
    ensureLoop();
  }
  // Feine Nachbarschafts-Linien ("neuronales Netz"): einmalig per Grid-Bucketing
  // vorberechnet (kein O(n^2) pro Frame), Degree pro Knoten gedeckelt.
  function buildMesh(){
    meshEdges=[];
    if(!nodes.length)return;
    var thr=0.16,thr2=thr*thr,cell=thr,grid={};
    function key(ix,iy,iz){return ix+"_"+iy+"_"+iz;}
    for(var i=0;i<nodes.length;i++){
      var b=nodes[i].base;
      var ix=Math.floor(b[0]/cell),iy=Math.floor(b[1]/cell),iz=Math.floor(b[2]/cell);
      nodes[i]._gx=ix;nodes[i]._gy=iy;nodes[i]._gz=iz;
      var k=key(ix,iy,iz);(grid[k]=grid[k]||[]).push(i);
    }
    var deg=new Array(nodes.length).fill(0),maxDeg=3,maxEdges=6000;
    for(var n=0;n<nodes.length&&meshEdges.length<maxEdges;n++){
      if(deg[n]>=maxDeg)continue;
      var bi=nodes[n].base,gx=nodes[n]._gx,gy=nodes[n]._gy,gz=nodes[n]._gz,cand=[];
      for(var dx=-1;dx<=1;dx++)for(var dy=-1;dy<=1;dy++)for(var dz=-1;dz<=1;dz++){
        var arr=grid[key(gx+dx,gy+dy,gz+dz)];
        if(arr)for(var a=0;a<arr.length;a++){var j=arr[a];if(j>n)cand.push(j);}
      }
      cand.sort(function(p,q){
        var bp=nodes[p].base,bq=nodes[q].base;
        var dp=(bi[0]-bp[0])*(bi[0]-bp[0])+(bi[1]-bp[1])*(bi[1]-bp[1])+(bi[2]-bp[2])*(bi[2]-bp[2]);
        var dq=(bi[0]-bq[0])*(bi[0]-bq[0])+(bi[1]-bq[1])*(bi[1]-bq[1])+(bi[2]-bq[2])*(bi[2]-bq[2]);
        return dp-dq;
      });
      for(var c=0;c<cand.length&&deg[n]<maxDeg;c++){
        var j2=cand[c];if(deg[j2]>=maxDeg)continue;
        var bj=nodes[j2].base;
        var d2=(bi[0]-bj[0])*(bi[0]-bj[0])+(bi[1]-bj[1])*(bi[1]-bj[1])+(bi[2]-bj[2])*(bi[2]-bj[2]);
        if(d2>thr2)continue;
        meshEdges.push([nodes[n],nodes[j2],1-Math.sqrt(d2)/thr]);
        deg[n]++;deg[j2]++;
        if(meshEdges.length>=maxEdges)break;
      }
    }
  }
  function project(p){
    var cy=Math.cos(rotY),sy=Math.sin(rotY),cx=Math.cos(rotX),sx=Math.sin(rotX);
    var x=p[0]*cy-p[2]*sy, z0=p[0]*sy+p[2]*cy, y=p[1]*cx-z0*sx, z=p[1]*sx+z0*cx;
    var R=Math.min(W,H)*0.36;
    return{x:W/2+x*R,y:H/2+y*R,z:z};
  }
  function tick(){
    if(reducedMotion||!visible||!tabActive){raf=null;return;}
    doFrame();
    raf=requestAnimationFrame(tick);
  }
  function doFrame(){
    if(!reducedMotion)t+=0.016;
    if(!reducedMotion){
      if(!dragging&&!over){rotY+=velY+dragV;dragV*=0.94;rotX+=tiltV;tiltV*=0.9;rotX+=(-0.42-rotX)*0.01;}
      else if(!dragging){dragV*=0.9;tiltV*=0.9;}
    }
    ctx.clearRect(0,0,W,H);
    var wobAmp=reducedMotion?0:0.022;
    for(var i=0;i<nodes.length;i++){
      var nd=nodes[i];
      var wob=1+wobAmp*Math.sin(t*0.5+nd.phase);
      var pr=project([nd.base[0]*wob,nd.base[1]*wob,nd.base[2]*wob]);
      nd.sx=pr.x;nd.sy=pr.y;nd.sz=pr.z;
    }
    clusters.forEach(function(c){var pr=project(c.home);c.lx=pr.x;c.ly=pr.y;c.lz=pr.z;});
    // Hover-Naehe je Knoten: schnelles Auf-, sanftes Abklingen
    var hoverActive=mouse.active&&!dragging&&over,hoverR=60,hoverR2=hoverR*hoverR;
    for(var hi=0;hi<nodes.length;hi++){
      var n2=nodes[hi],target=0;
      if(hoverActive&&n2.sz>-0.4){
        var ddx=mouse.x-n2.sx,ddy=mouse.y-n2.sy,dd2=ddx*ddx+ddy*ddy;
        if(dd2<hoverR2){var ff=1-Math.sqrt(dd2)/hoverR;target=ff*ff;}
      }
      var rate=reducedMotion?1:(target>n2.hl?0.28:0.06);
      n2.hl=(n2.hl||0)+(target-(n2.hl||0))*rate;
      if(n2.hl<0.001)n2.hl=0;
      // Lokale Anziehung Richtung Maus, mit derselben Ein-/Ausklingrate wie der Glow
      // (keine Sprünge), Betrag gedeckelt damit die Kugel als Ganzes sauber bleibt.
      if(n2.hl>0.001){
        var vx=mouse.x-n2.sx,vy=mouse.y-n2.sy,vlen=Math.hypot(vx,vy)||1;
        var mag=Math.min(11,n2.hl*13);
        n2.ox=(vx/vlen)*mag;n2.oy=(vy/vlen)*mag;
      }else{n2.ox=0;n2.oy=0;}
      n2.sx+=n2.ox;n2.sy+=n2.oy;
    }
    for(var e=0;e<edges.length;e++){var Aa=edges[e][0],B=edges[e][1],w=edges[e][2];var fz=(Aa.sz+B.sz)/2;var al=(fz+1)/2;var op=w*(0.35+0.65*al);
      var dim=selected&&Aa.cluster!==selected&&B.cluster!==selected;if(dim)op*=0.25;
      ctx.strokeStyle="rgba(15,15,15,"+op.toFixed(3)+")";ctx.lineWidth=0.6;ctx.beginPath();ctx.moveTo(Aa.sx,Aa.sy);ctx.lineTo(B.sx,B.sy);ctx.stroke();}
    // Neuronale Feinvernetzung: dezent, mit warmem Hover-Glanz
    for(var e2=0;e2<meshEdges.length;e2++){
      var Ma=meshEdges[e2][0],Mb=meshEdges[e2][1],prox=meshEdges[e2][2];
      var fz2=(Ma.sz+Mb.sz)/2;if(fz2<-0.5)continue;
      var al2b=(fz2+1)/2;var baseOp=prox*0.16*(0.3+0.7*al2b);
      var dim2=selected&&Ma.cluster!==selected&&Mb.cluster!==selected;if(dim2)baseOp*=0.2;
      var hlBoost=Math.max(Ma.hl||0,Mb.hl||0);
      if(baseOp<0.008&&hlBoost<0.02)continue;
      if(hlBoost>0.02){ctx.strokeStyle="rgba(255,69,0,"+Math.min(1,baseOp+hlBoost*0.5).toFixed(3)+")";}
      else{ctx.strokeStyle="rgba(15,15,15,"+baseOp.toFixed(3)+")";}
      ctx.lineWidth=0.5;ctx.beginPath();ctx.moveTo(Ma.sx,Ma.sy);ctx.lineTo(Mb.sx,Mb.sy);ctx.stroke();
    }
    var order=nodes.slice().sort(function(a,b){return a.sz-b.sz;});
    hoverCluster=null;var hoverBest=14;
    for(var n=0;n<order.length;n++){var nd2=order[n];var front=(nd2.sz+1)/2;var pulse=reducedMotion?1:0.86+0.14*Math.sin(t*0.7+nd2.phase);
      var sel=selected&&nd2.cluster===selected;var dimN=selected&&!sel;var hl=nd2.hl||0;
      var r=nd2.r0*(0.55+0.75*front)*(sel?1.35:1)*(1+0.8*hl);
      if(nd2.leader){
        var alpha=(0.55+0.45*front)*pulse*(dimN?0.4:1)+hl*0.3;
        ctx.beginPath();ctx.fillStyle="rgba(255,69,0,"+(0.10*front*(dimN?0.3:1)+hl*0.16).toFixed(3)+")";ctx.arc(nd2.sx,nd2.sy,r*3.4,0,6.2832);ctx.fill();
        ctx.beginPath();ctx.fillStyle="rgba(255,69,0,"+Math.min(1,alpha).toFixed(3)+")";ctx.arc(nd2.sx,nd2.sy,r,0,6.2832);ctx.fill();
      }else{
        var base2=nd2.residual?0.09:0.18, span2=nd2.residual?0.30:0.5;   // Umgebungswolke dezenter
        var al2=Math.min(1,(base2+span2*front)*pulse*(dimN?0.3:1)+hl*0.55);
        if(hl>0.04){ctx.beginPath();ctx.fillStyle="rgba(255,69,0,"+(0.22*hl).toFixed(3)+")";ctx.arc(nd2.sx,nd2.sy,r*2.2,0,6.2832);ctx.fill();}
        ctx.beginPath();ctx.fillStyle=hl>0.15?"rgba(255,120,40,"+al2.toFixed(3)+")":"rgba(15,15,15,"+al2.toFixed(3)+")";ctx.arc(nd2.sx,nd2.sy,r,0,6.2832);ctx.fill();
      }
    }
    if(mouse.active&&!dragging){for(var c=0;c<clusters.length;c++){var cl=clusters[c];if(cl.lz<-0.15)continue;var d=Math.hypot(mouse.x-cl.lx,mouse.y-cl.ly);if(d<hoverBest+cl.leaderNode.r0){hoverBest=d;hoverCluster=cl;}}}
    canvas.style.cursor=dragging?"grabbing":(hoverCluster?"pointer":"grab");
    updateChip();
  }
  function clusterLabel(c){var m=/(\d+)/.exec(c.name);return m?"Cluster "+m[1]:c.name;}
  function updateChip(){
    var txt=$("brainChipTxt"),chip=$("brainChip");if(!txt||!chip)return;
    if(selected){var pct=(selected.count/(window.__vaultTotal||1)*100);txt.innerHTML="<b>"+esc(clusterLabel(selected))+"</b> · "+nf(selected.count)+" Notizen · "+pct.toFixed(1)+"% &nbsp;·&nbsp; <span style='color:var(--accent);cursor:pointer' id='clrSel'>zurück</span>";chip.classList.add("show");var b=$("clrSel");if(b)b.onclick=function(ev){ev.stopPropagation();selected=null;};return;}
    if(hoverCluster){txt.textContent=clusterLabel(hoverCluster)+" · "+nf(hoverCluster.count)+" Notizen";chip.classList.add("show");}
    else{txt.textContent="";chip.classList.remove("show");}
  }
  function relPos(e){var r=canvas.getBoundingClientRect();var cx=(e.touches?e.touches[0].clientX:e.clientX),cy=(e.touches?e.touches[0].clientY:e.clientY);return{x:cx-r.left,y:cy-r.top};}
  function down(e){dragging=true;var p=relPos(e);lastX=p.x;lastY=p.y;mouse.active=true;}
  function move(e){if(!canvas)return;var p=relPos(e);mouse.x=p.x;mouse.y=p.y;mouse.active=true;if(dragging){dragV=(p.x-lastX)*0.00040;tiltV=(p.y-lastY)*0.0007;rotY+=(p.x-lastX)*0.006;rotX+=(p.y-lastY)*0.006;rotX=Math.max(-1.3,Math.min(1.3,rotX));lastX=p.x;lastY=p.y;}if(reducedMotion)doFrame();}
  function up(){dragging=false;if(reducedMotion)doFrame();}
  return{init:init,resize:resize,build:build,reset:function(){selected=null;hoverCluster=null;}};
})();
A.Brain=Brain;
A.renderBrain=function(section){
  var st=$("brainState");
  var note=A.stateNote(section,"Second Brain");
  if(note||(section.data&&section.data.available===false)){
    st.style.display="flex";
    st.innerHTML='<div class="state-note '+((note&&note.cls)||"missing")+'" style="justify-content:center">'+esc(note?note.text:(section.data.hint||"Vault-Statistik nicht verfügbar."))+"</div>";
    $("brainTotal").textContent="–";$("brainNew").textContent="";
    Brain.resize();Brain.build({});return;
  }
  st.style.display="none";
  var v=section.data;window.__vaultTotal=v.total;
  $("brainTotal").textContent=nf(v.total);
  $("brainNew").textContent=v.new_last_30_days?"+"+nf(v.new_last_30_days):"";
  Brain.reset();Brain.resize();Brain.build(v.by_cluster||{},v.total||0);
};
})(window.AIOS);
