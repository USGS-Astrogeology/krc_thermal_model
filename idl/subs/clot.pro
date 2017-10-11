PRO clot,yyy,txt,xx=xx,locc=locc,xran=xran,yran=yran,titl=titl,oplot=oplot $
,abso=abso,yr2=yr2,bw=bw,ksym=ksym,tsiz=tsiz,_extra=e
;_Titl  CLOT  Color plot of related curves
; yyy   in. array(n,m=numCurves)  Data to plot
; txt   in_ strarr(m)  Labels for curves. Default is 0-based count
; xx    in_ array (n)  Abcissa positions, default is 0,1,2...
; locc  in_ fltarr(4)  Loc. for Guide in NORMAL units ala CURVEGUIDE.
;           fltarr(5)  [xloc,off,size,thick,over] for LABEL_CURVE  
;              if absent, no guide. If less then 4 use [0.15,0.92,-0.04,0.08]
; xran  in_ fltarr(2)  X plot limits:  Default is automatic. Ignored for oplot
; yran  in_ fltarr(2)  Y plot limits:  Default: full range. Ignored for oplot
;            If values are equal,uses full range of dataset
;            If [0] gt [1], normalizes each curve onto 0:1 
; titl  in_ strarr(3)  Lables for x,y axes and top. Ignored for oplot
; oplot in_ flag.      If set, overplots: ranges and titl ignored 
;                        Offset in SETCOLOR line index -=none
;                      Number of curves set by yyy
;       oplot modes:
;        -9 or less: more data; use same line set, no addition to legend
;        -n: alternate values. use line type -n, show within existing legend
;        +n: more curves, offset line index, add more items to legend
;       100+n: n=line style and  new set of labels
; abso  in_ flag  If set, plots absolute value, with symbol where negative
; yr2   in_ fltarr(2)  Yrange for 2nd plot on right half in one call.
;                          Ignored if values are equal
; bw    in_ Intarr(m)  Line type. If m>2, does in black and white
; ksym  in_ Int        Symbol to use as well as line. Will use abs-value
;                      If negative, will suppress the line
; tsiz  in_ Float  Character-size for CURVEGUIDE. Default=IDL default

; Responds to !dbug : ge 8: stop at entry.    ge 7: storp before return
;_Hist 20209dec08 Hugh Kieffer
; 2010mar16 HK Add _Extra keyword
 ;2010apr09-11 HK Enable overplot, add keyword ksym.  Done only for color code
; 2010jul14 HK Allow auto scaling of all curves
; 2010dec10 HK Fix bug that could overwrite input xx
; 2011dec31 HK Add oplot>100 mode
; 2012jan18 HK Add keyword  tsiz
; 2012feb06 HK Add keyword abso
; 2013apr01 HK Make default X value Long so will handle >32767 properly
; 2013may12 HK Include _extra in  all data plot commands
; 2014feb03 HK Add keyword yr2
common SETCOLOR_COM2, kcc,linecol,kkc,kkl,kkp,fixkkc,fixkkl,fixkkp,kink,scex1
;_End

if !dbug ge 8 then stop
; help,yyy,txt,xx,locc,xran,yran,titl,oplot,bw,ksym,oplot

kok=n_elements(locc)
if kok lt 4 then loc2=[0.15,0.93,-0.03,0.06] else loc2=locc

if keyword_set(oplot) then idop=oplot else idop=0 ; line index offset
dos = idop lt 100               ; use line style from commmon
dop = idop ne 0                 ; overplot Flag
doa = keyword_set(abso)         ; plot absolute value
if dos then begin
    koff=idop>0                 ; line index offset
    kfix= (-idop)>0  & if kfix gt 5 then kfix=0 ; overplot fixed line index
endif else begin                ; fixed line style
    koff=0                      ; no index offset
    kfix=idop-100               ; line style
endelse

if not keyword_set(tsiz) then tsiz=0
if n_elements(yr2) lt 2 then yr2=[0,0]       ; dual plot, Y magnified on right
dod = yr2[0] ne yr2[1] ; ignore if values the same

dol= not idop and kok ge 5 and abs(loc2[2]) gt .3  ; put label on each curve
dog= kok ge 1 and idop gt -5 and not dol      ; do curve Guide
if dog and dop and not dos and kfix gt 0 then begin ; new line type for existing guide
        loc2[1]=loc2[1]+0.25*loc2[2] ; Y offset
        loc2[3]=.8*loc2[3]      ; shorter line, will offset symbol if used
    endif

if not keyword_set(ksym) then ksym=0 
ksya=abs(ksym)<8                  ; ensure not beyond psym valid range
siz=size(yyy)
if siz[0] ne 2 and not dop then message,'Arg1 must be 2D, 1D allowed for oplot'
nx=siz[1]
if siz[0] eq 2 then ny=siz[2] else ny=siz[1]

np=n_params() ; 
if np lt 2 then txt=strtrim(indgen(ny),2) ; curve numbers

if n_elements(xx) lt nx then xv=lindgen(nx) else xv=xx[0:nx-1] ; x values
if n_elements(xran) lt 2 then begin ; set X range
    xa=min(xv,max=xb)
    xran=[xa,xb]
 end

don=0 ; set to not auto-scale each
if n_elements(yran) lt 2 then yran=[-1.,-1.]; Yran absent; set to auto-scale
if yran[0] eq yran[1] then begin            ; equal, use full dataset rance 
   ya=min(yyy,max=yb,/nan)
   if ya gt 0 then doa=0B       ; there are no negative values
   if doa then ya=min(abs(yyy),max=yb,/nan)
endif else if yran[0] gt yran[1] then begin ; min>max, normalize onto 0,1
   don=1                                    ; set the normalization flag
   ya=0. & yb=1. 
endif else begin
         ya=yran[0] & yb=yran[1] ; use the input values
endelse
yrn=[ya,yb]                     ; yrange to use
xmarg=[10,3]                    ; the default xmargin
if dod then begin               ; must double X plot range
   dx=(xb-xa)/(nx-1.)           ; delta X value
   xa2=xb+dx                    ; gap to right half
   xran[1]=xa2+(xb-xa)          ; new top of xrange
   xd=xv+(xa2-xa)               ; right side
   fff=SCALELIN(yr2,vv=yrn)
   xmarg=[10,8]
endif

if not keyword_set(titl) then titl=['Count','Constant scale','CLOT']

if not dop then plot,xv,xv,xran=xran,yran=yrn,/nodata $
,xtit=titl[0],ytit=titl[1],title=titl[2],xmargin=xmarg,_extra=e

if dod then axis,yaxis=1,yrange=yr2,ystyle=1,ticklen=-.02 ; right scale

if doa then begin 
    plots,.82,.02,psym=8,/norm,_extra=e
    xyouts,.83,.015,' indicates was negative',/norm
endif

jn=0                            ; default is no symbol for negative data
nlin=n_elements(bw)
ytr=''                          ; default is no individaul range guide 
gtex=''                         ; insurance
doc = nlin lt 2                 ; do color
; linn=[0,2,3,4,5,1]
for k=0,ny-1 do begin
    k2=koff+k                ;  setcolor line/color index 
    yy=yyy[*,k]
    if doa then begin 
        ii=where(yy lt 0.,jn)   ; all negative points
        yy=abs(yy)
    endif
    if idop ge 1 or not dop then gtex=txt[k] else gtex='' 

    if dod then yd=(yy-fff[0])*fff[1] ;  re-scale for right plot
 
    if don then begin ; auto-scale
        ya=min(yy,max=yb)
        if ya ne yb then yy= (yy-ya)/(yb-ya) ; scale onto [0,1]
        gtex=gtex+ST0([ya,yb]) ; range as text
    endif

    if doc then begin ; color
        clr=kkc[k2 mod kcc[2]]
        lin=kkl[k2 mod kcc[3]]
        if kfix gt 0 then lin=kfix
        j=lin ; for use by  CURVEGUIDE
        if ksym ge 0 then oplot,xv,yy,line=lin,color=clr,_extra=e ; plot data line
        if ksya ne 0 then  oplot,xv,yy,psym=ksya,color=clr,_extra=e ; add symbol
    if jn gt 0 then for i=0,jn-1 do plots,xv[ii],yy[ii],color=clr,psym=8,_extra=e
        if dod then begin ; plot again on the right
           if ksym ge 0 then oplot,xd,yd,line=lin,color=clr,_extra=e 
           if ksya ne 0 then  oplot,xd,yd,psym=ksya,color=clr,_extra=e
    if jn gt 0 then for i=0,jn-1 do plots,xd[ii],yd[ii],color=clr,psym=8,_extra=e
        endif
  if dog then CURVEGUIDE,k2,gtex,lin,locc=loc2,color=clr,ksym=ksya,charsize=tsiz
        if dol then LABEL_CURVE, gtex,xv,yy,loc2[0],off=loc2[1],size=loc2[2] $
                       ,thick=loc2[3],over=loc2[4],color=clr
    endif else begin ; monochrome
        lin=((bw[k2 mod nlin])>0) mod 6 ; ensure valid line
        oplot,xv,yy,line=lin
        if ksya ne 0 then  oplot,xv,yy,psym=ksya,_extra=e ; add symbol 
        if jn gt 0 then for i=0,jn-1 do plots,xv[ii],yy[ii],psym=8,_extra=e 
        if dog then CURVEGUIDE,k2,gtex,lin,locc=loc2,ksym=ksya,charsize=tsiz
        if dol then LABEL_CURVE,gtex,xv,yy,loc2[0],off=loc2[1],size=loc2[2] $
                       ,thick=loc2[3],over=loc2[4]
        if dod then begin ; plot again on the right
           oplot,xd,yd,line=lin
           if ksya ne 0 then  oplot,xd,yd,psym=ksya,_extra=e ; add symbol 
           if jn gt 0 then for i=0,jn-1 do plots,xd[ii],yd[ii],psym=8,_extra=e 
           if dol then LABEL_CURVE,gtex,xd,yd,loc2[0],off=loc2[1],size=loc2[2] $
                          ,thick=loc2[3],over=loc2[4]
        endif
    endelse
 endfor

if !dbug ge 7 then stop
; help,yyy,txt,xv,locc,xran,yran,titl,oplot,bw,ksym,oplot
; help, np,idop,dop,koff,kfix,dog,loc2,ksy,k2,lin,j

return
end