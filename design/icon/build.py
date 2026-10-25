import cairosvg, io, json, os
from PIL import Image, ImageDraw, ImageFont
INK="#1C2430"; KEEP="#1B3A5F"; STONE="#E8E0D4"; PAPER="#FAFAF8"; MUTE="#5C6570"
FONT="/workspace/fortkeeps/fonts/ibm-plex-sans/IBMPlexSans-SemiBold.ttf"
import glob
if not os.path.exists(FONT): FONT=(glob.glob("/workspace/fortkeeps/fonts/**/IBMPlexSans-SemiBold.ttf",recursive=True) or [None])[0]
for d in ["concepts","macos","ios","doc","doc/macos"]: os.makedirs(d,exist_ok=True)

# ---- glyphs, drawn in a 1024 canvas, centred ~ (512,512) ----
def scroll_glyph(fg, knock):
    # Concept A "Scroll Keep": vertical scroll, crenellated top roll, knocked-out Markdown down-arrow
    return f'''
<g fill="{fg}">
  <!-- crenellated top roll (merlons = Fortkeeps keep) -->
  <path d="M300 250 h88 v56 h56 v-56 h136 v56 h56 v-56 h88 v130 h-424z"/>
  <!-- sheet -->
  <rect x="332" y="370" width="360" height="330"/>
  <!-- bottom roll -->
  <rect x="270" y="690" width="484" height="90" rx="45"/>
</g>
<g fill="{knock}"><circle cx="315" cy="735" r="20"/><circle cx="709" cy="735" r="20"/></g>
<g fill="{knock}">
  <!-- Markdown arrow: bold shaft + head -->
  <rect x="457" y="405" width="110" height="140"/>
  <path d="M392 530 h240 l-120 135z"/>
</g>'''
def tower_glyph(fg, knock):
    # Concept B "Keep + Banner": Fortkeeps tower with a scroll banner across it carrying M↓
    return f'''
<g fill="{fg}">
  <path d="M332 230 h96 v70 h168 v-70 h96 v120 h-24 v444 h-130 v-110 a42 42 0 0 0 -84 0 v110 h-130 v-444 h-24z"/>
</g>
<rect x="250" y="420" width="524" height="150" rx="30" fill="{knock}" stroke="{fg}" stroke-width="28"/>
<g fill="{fg}">
  <path d="M330 540 v-90 h30 l32 40 l32 -40 h30 v90 h-30 v-48 l-32 38 l-32 -38 v48z"/>
  <rect x="560" y="450" width="40" height="52"/><path d="M530 500 h100 l-50 44z"/>
</g>'''

def svg(body, bg=STONE, shape="ios", grad=None):
    # ios: full-bleed square; mac: 824 squircle-ish rect at 100px margin (Apple macOS grid)
    if shape=="ios":
        back=f'<rect width="1024" height="1024" fill="{bg}"/>' if bg else ''
        inner=body
    else:
        back=f'''<defs><filter id="s" x="-10%" y="-10%" width="120%" height="130%"><feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000" flood-opacity="0.28"/></filter></defs>
<rect x="100" y="100" width="824" height="824" rx="185" fill="{bg}" filter="url(#s)"/>
<rect x="100.5" y="100.5" width="823" height="823" rx="185" fill="none" stroke="#000" stroke-opacity="0.08"/>'''
        inner=f'<g transform="translate(512 512) scale(0.9) translate(-512 -512)">{body}</g>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{back}{inner}</svg>'

def png(s, size, path=None, opaque=False):
    im=Image.open(io.BytesIO(cairosvg.svg2png(bytestring=s.encode(),output_width=size,output_height=size))).convert("RGBA")
    if opaque: im=im.convert("RGB")
    if path: im.save(path)
    return im

concepts={"A-scroll-keep":scroll_glyph,"B-keep-banner":tower_glyph}
for n,g in concepts.items():
    open(f"concepts/{n}.svg","w").write(svg(g(INK,STONE)))
    open(f"concepts/{n}-macos.svg","w").write(svg(g(INK,STONE),shape="mac"))
G=scroll_glyph  # chosen
mac=svg(G(INK,STONE),shape="mac"); ios=svg(G(INK,STONE))
ios_dark=svg(G(STONE,"#11161D"),bg="#11161D")
ios_tint=svg(G("#FFFFFF","#000000"),bg="#000000")   # grayscale luminance source for tinted mode
open("FKScroll-AppIcon-master.svg","w").write(ios)
open("FKScroll-AppIcon-macOS.svg","w").write(mac)
open("FKScroll-AppIcon-iOS-dark.svg","w").write(ios_dark)
open("FKScroll-AppIcon-iOS-tinted.svg","w").write(ios_tint)
macfiles=[]
for p in [16,32,128,256,512]:
    for sc in (1,2):
        f=f"icon_{p}x{p}{'@2x' if sc==2 else ''}.png"; png(mac,p*sc,"macos/"+f); macfiles.append((p,sc,f))
png(mac,64,"macos/icon_64x64.png"); png(mac,1024,"macos/icon_1024x1024.png")
png(ios,1024,"ios/AppIcon-1024.png",True)
png(ios_dark,1024,"ios/AppIcon-1024-dark.png",True)
png(ios_tint,1024,"ios/AppIcon-1024-tinted.png",True)

# ---- document icon (macOS doc grid: page ~ 0.72w, folded corner) ----
def docsvg():
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs><filter id="s"><feDropShadow dx="0" dy="8" stdDeviation="10" flood-opacity="0.25"/></filter></defs>
<path d="M190 60 h460 l184 184 v720 h-644z" fill="{PAPER}" stroke="#B9B2A6" stroke-width="10" filter="url(#s)"/>
<path d="M650 60 v184 h184z" fill="{STONE}" stroke="#B9B2A6" stroke-width="10" stroke-linejoin="round"/>
<g transform="translate(512 430) scale(0.5) translate(-512 -512)">
 <rect x="212" y="212" width="600" height="600" rx="135" fill="{STONE}"/>
 <g transform="translate(512 512) scale(0.9) translate(-512 -512)">{G(INK,STONE)}</g></g>
<rect x="250" y="720" width="524" height="180" rx="36" fill="{KEEP}"/>
<text x="512" y="855" font-family="IBM Plex Sans" font-weight="700" font-size="150" fill="#FFFFFF" text-anchor="middle" letter-spacing="8">MD</text>
</svg>'''
doc=docsvg(); open("doc/FKScroll-Document.svg","w").write(doc)
docfiles=[]
for p in [16,32,128,256,512]:
    for sc in (1,2):
        f=f"doc_{p}x{p}{'@2x' if sc==2 else ''}.png"; png(doc,p*sc,"doc/macos/"+f); docfiles.append(f)

# ---- Contents.json ----
os.makedirs("AppIcon.appiconset-macOS",exist_ok=True); os.makedirs("AppIcon.appiconset-iOS",exist_ok=True)
json.dump({"images":[{"idiom":"mac","size":f"{p}x{p}","scale":f"{sc}x","filename":f} for p,sc,f in macfiles],"info":{"author":"xcode","version":1}},open("AppIcon.appiconset-macOS/Contents.json","w"),indent=2)
for p,sc,f in macfiles: Image.open("macos/"+f).save("AppIcon.appiconset-macOS/"+f)
json.dump({"images":[
 {"idiom":"universal","platform":"ios","size":"1024x1024","filename":"AppIcon-1024.png"},
 {"idiom":"universal","platform":"ios","size":"1024x1024","filename":"AppIcon-1024-dark.png","appearances":[{"appearance":"luminosity","value":"dark"}]},
 {"idiom":"universal","platform":"ios","size":"1024x1024","filename":"AppIcon-1024-tinted.png","appearances":[{"appearance":"luminosity","value":"tinted"}]}],
 "info":{"author":"xcode","version":1}},open("AppIcon.appiconset-iOS/Contents.json","w"),indent=2)
for f in ["AppIcon-1024.png","AppIcon-1024-dark.png","AppIcon-1024-tinted.png"]: Image.open("ios/"+f).save("AppIcon.appiconset-iOS/"+f)

# ---- contact sheet ----
font=ImageFont.truetype(FONT,22) if FONT else ImageFont.load_default()
small=ImageFont.truetype(FONT,14) if FONT else font
rows=[("Concept A (chosen) macOS",[png(svg(scroll_glyph(INK,STONE),shape="mac"),s) for s in (16,32,64,128,256)]),
      ("Concept B macOS",[png(svg(tower_glyph(INK,STONE),shape="mac"),s) for s in (16,32,64,128,256)]),
      ("iOS light / dark / tinted (180, 60, 29)",[png(x,s) for x in (ios,ios_dark,ios_tint) for s in (180,60,29)]),
      ("Document .md (16,32,64,128,256)",[png(doc,s) for s in (16,32,64,128,256)])]
W=1900; H=60+sum(max(i.height for i in r[1])+70 for r in rows)
sheet=Image.new("RGB",(W,H))
for half,(bg,fg) in enumerate([(PAPER,INK),("#1E1E1E","#EEEEEE")]):
    x0=half*W//2; d=ImageDraw.Draw(sheet); d.rectangle([x0,0,x0+W//2,H],fill=bg)
    d.text((x0+20,15),["Light background","Dark background"][half]+" — actual pixel sizes",fill=fg,font=font)
    y=60
    for label,ims in rows:
        d.text((x0+20,y),label,fill=fg,font=small); y+=24; x=x0+20; rh=max(i.height for i in ims)
        for im in ims:
            if x+im.width>x0+W//2-10: break
            if im.mode=="RGB": im=im.convert("RGBA")
            sheet.paste(im,(x,y+rh-im.height),im); x+=im.width+16
        y+=rh+46
sheet.save("contact-sheet.png")
