import json, sys
from PIL import Image, ImageDraw
import render3, render4
L=json.load(open(sys.argv[2]))
items=[('cabeca','cab_faixa',(66,0,126,40)),('cabeca','cab_elmo_silencio',(66,0,126,40)),('corpo','cor_malha',(60,20,132,100)),('corpo','cor_placas',(60,20,132,100)),
       ('arma','arm_cajado',(96,0,136,40)),('arma','arm_martelo_juiz',(80,0,152,72)),('amuleto','amu_ampulheta',(80,50,112,90)),('amuleto','amu_calma',(80,50,112,90)),('amuleto','amu_equilibrio',(80,50,112,90))]
W=Image.new('RGB',(5*240,2*250),(10,12,18))
for i,(slot,it,box) in enumerate(items):
    g='m' if i%2==0 else 'f'
    c=dict(corpo=g,pele=[1,4,2,5,0][i%5],cabelo=1 if g=='m' else 4,corCabelo=i%8,corRoupa=i%6,barba=0,olhos='azul',equip={slot:it})
    im=render4.image(render4.compose(L,render4.order(c,L),render3.palette(c)),1)
    cr=im.crop(box); s=230/max(cr.size)
    W.paste(cr.resize((int(cr.size[0]*s),int(cr.size[1]*s)),Image.NEAREST),((i%5)*240+5,(i//5)*250+10))
W.save(sys.argv[1])
