import json, sys
from PIL import Image, ImageDraw
import render3, render4
L=json.load(open(sys.argv[2] if len(sys.argv)>2 else 'layers6.json'))
items=[('cabeca','cab_faixa'),('cabeca','cab_elmo_silencio'),('corpo','cor_malha'),('corpo','cor_sentinela'),('corpo','cor_placas'),
       ('arma','arm_cajado'),('arma','arm_martelo_juiz'),('amuleto','amu_ampulheta'),('amuleto','amu_calma'),('amuleto','amu_equilibrio')]
W=Image.new('RGB',(5*240,2*330),(10,12,18)); d=ImageDraw.Draw(W)
for i,(slot,it) in enumerate(items):
    g='m' if i%2==0 else 'f'
    c=dict(corpo=g,pele=[1,4,2,5,0][i%5],cabelo=1 if g=='m' else 4,corCabelo=i%8,corRoupa=i%6,barba=0,olhos='azul',equip={slot:it})
    im=render4.image(render4.compose(L,render4.order(c,L),render3.palette(c)),1)
    W.paste(im.crop((44,0,148,192)).resize((156*1,288),Image.NEAREST).resize((156,288)),( (i%5)*240+40,(i//5)*330+30))
    d.text(((i%5)*240+10,(i//5)*330+8),it,fill=(220,220,220))
W.save(sys.argv[1] if len(sys.argv)>1 else 'items_now.png')
