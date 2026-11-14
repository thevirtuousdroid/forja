import json, sys
import numpy as np
from PIL import Image, ImageFilter
import render
from render import hx

ORDER = ['cabelo_tras', 'martelo_tras', 'pescoco', 'corpo', 'braco', 'armadura', 'antebraco_martelo', 'martelo_frente', 'mao_martelo', 'cabeca', 'rosto', 'cabelo', 'elmo']

def names_for(c):
    g, s = c['g'], c['style']
    out = []
    for slot in ORDER:
        if slot == 'cabelo_tras': out.append(f'cabelo_{s}_tras_{g}')
        elif slot == 'cabelo':
            if 'elmo' not in c['items'] or s == 'longo': out.append(f'cabelo_{s}_{g}')
        elif slot in ('pescoco', 'corpo', 'cabeca', 'rosto'): out.append(f'{slot}_{g}')
        elif slot == 'braco': out.append(f'braco_martelo_{g}' if 'martelo' in c['items'] else f'braco_{g}')
        elif slot in ('martelo_tras', 'antebraco_martelo', 'martelo_frente', 'mao_martelo'):
            if 'martelo' in c['items']: out.append(f'{slot}_{g}')
        elif slot in c['items']: out.append(f'{slot}_{g}')
    return out

def image(rgba, scale=4, bg='#0b1016'):
    h, w = rgba.shape[:2]
    a = rgba[..., 3:4]; rgb = rgba[..., :3]; bgc = hx(bg)
    yy, xx = np.mgrid[0:h * scale, 0:w * scale] / scale
    canvas = np.ones((h * scale, w * scale, 3)) * bgc
    canvas += (np.exp(-(((xx - 48) / 30) ** 2 + ((yy - 96) / 14) ** 2)) * 0.55)[..., None] * (hx('#ff7138') - bgc) * 0.6
    canvas += (np.exp(-(((xx - 100) / 20) ** 2 + ((yy - 40) / 34) ** 2)) * 0.3)[..., None] * (hx('#39d5d0') - bgc) * 0.5
    canvas *= (1 - (np.exp(-(((xx - 48) / 16) ** 2 + ((yy - 91.5) / 2.2) ** 2)) * 0.7)[..., None])
    up = np.kron(rgb, np.ones((scale, scale, 1))); ua = np.kron(a, np.ones((scale, scale, 1)))
    canvas = canvas * (1 - ua) + up * ua
    lum = np.zeros((h, w, 3))
    for c in ('#ffb45e', '#fff0d6', '#e6fffd', '#8ff0ea'):
        mm = np.all(np.abs(rgb - hx(c)) < 6, axis=-1) & (a[..., 0] > 0); lum[mm] = hx(c)
    L = Image.fromarray(np.uint8(np.kron(lum, np.ones((scale, scale, 1))))).filter(ImageFilter.GaussianBlur(scale * 2.5))
    canvas = 255 - (255 - canvas) * (255 - np.asarray(L, float) * 0.9) / 255
    return Image.fromarray(np.uint8(np.clip(canvas, 0, 255)))

if __name__ == '__main__':
    layers = json.load(open(sys.argv[1]))
    combos = [
        dict(g='m', skin='retinta', hair='preto', eye='castanho', style='curto', items=[]),
        dict(g='m', skin='clara', hair='castanho', eye='azul', style='curto', items=['armadura', 'martelo']),
        dict(g='f', skin='escura', hair='preto', eye='mel', style='curto', items=['armadura', 'martelo']),
        dict(g='f', skin='clara', hair='ruivo', eye='verde', style='longo', items=['elmo', 'armadura', 'martelo']),
    ]
    tiles = []
    for c in combos:
        pal = render.palette(c['skin'], c['hair'], c['eye'])
        img = render.compose(layers, names_for(c), pal, 96, 96)
        tiles.append(image(img, 4))
    W = Image.new('RGB', (len(tiles) * 388, 384), '#000')
    for i, t in enumerate(tiles): W.paste(t, (i * 388, 0))
    W.save(sys.argv[2]); print('ok')
