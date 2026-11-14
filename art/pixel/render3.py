"""Montagem e prévias do personagem completo (mesma ordem de camadas usada no app)."""
import json, sys
import numpy as np
from PIL import Image, ImageDraw
import render
from render import hx
from render2 import image

SKINS6 = {
    0: ['#9a6a54', '#c48f74', '#e2b49a', '#f3d2b8', '#fde9da'],
    1: ['#8a5440', '#b8765c', '#d39a74', '#e3b08a', '#f4cfaf'],
    2: ['#6e3e26', '#9a5e3c', '#b97a50', '#c68a5f', '#dcaa80'],
    3: ['#4e2a18', '#74432a', '#93583a', '#a3683f', '#bd875e'],
    4: ['#331b10', '#4e2c1c', '#683d27', '#7a4a2b', '#956446'],
    5: ['#1e100a', '#2f1a10', '#432618', '#4f311f', '#6a4834'],
}
HAIRS8 = {
    0: ['#0b0b10', '#16161e', '#22222d', '#343444', '#4e4e62'],
    1: ['#170d08', '#2a1810', '#3e2418', '#563624', '#704a32'],
    2: ['#2a160c', '#4a2a16', '#6a3e22', '#8a5530', '#ab7044'],
    3: ['#4a2a10', '#714016', '#9a5c1e', '#c3802e', '#e2a64a'],
    4: ['#6a4c1e', '#9a7430', '#c49e48', '#e2c46a', '#f6e2a0'],
    5: ['#4a1408', '#76220c', '#a83414', '#d04e1e', '#f07a3a'],
    6: ['#3a3e46', '#5c626c', '#868c96', '#b4bac2', '#e0e4ea'],
    7: ['#0e1a32', '#1a2e52', '#2a4a7a', '#4068a2', '#6a92cc'],
}
OUTFITS6 = {
    0: ['#0b1018', '#141e2c', '#1f2d42', '#2e4260', '#465e84'],
    1: ['#140c09', '#24160f', '#382218', '#4e3024', '#6a4434'],
    2: ['#081410', '#0f221c', '#18342a', '#24493c', '#366454'],
    3: ['#160709', '#260d12', '#3c141c', '#561e29', '#73303c'],
    4: ['#0a0f15', '#121a23', '#1b2733', '#283a4a', '#3d5569'],
    5: ['#171007', '#2a1e0c', '#433014', '#5c441e', '#7a5c2c'],
}
EXTRA = {
    'P': ['#3a0a2e', '#6a1250', '#a81e7a', '#e040a8', '#ff9ad8'],
    'B': ['#0e1c34', '#1c3358', '#2c4f84', '#4c78b4', '#8cb4e6'],
    'G': ['#0e1c18', '#1c322a', '#2c4a3e', '#456a5a', '#6e9484'],
    'Y': ['#4a300a', '#7a5214', '#b07e26', '#deac44', '#fbe08a'],
    'V': ['#160c26', '#26163e', '#38225c', '#4e3280', '#6c4aa6'],
    'F': ['#2a0606', '#4a0c0c', '#741614', '#a2241c', '#cc4630'],
    'J': ['#08080c', '#121218', '#1e1e27', '#30303c', '#5a5a70'],
}
SHOULDER = {'arm_martelo', 'arm_martelo_juiz'}
STYLES = ['raspado', 'curto', 'franja', 'cacheado', 'longo', 'coque', 'volumoso', 'sem']
HIDE_FRONT = {'cab_capuz'}
HIDE_BACK = {'cab_capuz', 'cab_elmo_ferro', 'cab_elmo_silencio'}


def palette(c):
    p = {k: [hx(v) for v in vv] for k, vv in {**render.FIXED, **EXTRA}.items()}
    p['S'] = [hx(v) for v in SKINS6[c['pele']]]
    p['H'] = [hx(v) for v in HAIRS8[c['corCabelo']]]
    p['I'] = [hx(v) for v in render.EYES[c.get('olhos', 'castanho')]]
    p['C'] = [hx(v) for v in OUTFITS6[c['corRoupa']]]
    red = hx('#b3404a'); p['L'] = [x * 0.55 + red * 0.45 for x in p['S']]
    return p


def order(c, layers, blink=False):
    g, e = c['corpo'], c.get('equip', {})
    s = STYLES[c['cabelo']] if isinstance(c['cabelo'], int) else c['cabelo']
    cab, cor, cap, arm, amu = e.get('cabeca'), e.get('corpo'), e.get('capa'), e.get('arma'), e.get('amuleto')
    out = []
    if cap: out.append(f'{cap}_tras_{g}')
    if not (cab in HIDE_BACK and s in ('coque', 'volumoso')) and cab != 'cab_capuz':
        out.append(f'cabelo_{s}_tras_{g}')
    if arm in SHOULDER: out.append(f'{arm}_tras_{g}')
    out += [f'pescoco_{g}', f'corpo_{g}']
    if arm and arm not in SHOULDER: out.append(f'{arm}_tras_{g}')
    out.append(f'braco_ombro_{g}' if arm in SHOULDER else f'braco_{g}')
    if cor and cor != 'cor_tunica': out.append(f'{cor}_{g}')
    if amu: out.append(f'{amu}_{g}')
    if cap: out.append(f'{cap}_{g}')
    if arm in SHOULDER: out += [f'antebraco_ombro_{g}', f'{arm}_{g}', f'mao_ombro_{g}']
    out += [f'cabeca_{g}', f'rosto_{g}_piscar' if blink else f'rosto_{g}']
    if c.get('barba'): out.append(f"barba_{c['barba']}_{g}")
    if cab not in HIDE_FRONT: out.append(f'cabelo_{s}_{g}')
    if cab: out.append(f'{cab}_{g}')
    return [n for n in out if n in layers]


def render_one(layers, c, scale=3):
    img = render.compose(layers, order(c, layers), palette(c), 96, 96)
    return image(img, scale)


if __name__ == '__main__':
    layers = json.load(open(sys.argv[1]))
    base_f = dict(corpo='f', pele=2, cabelo=4, corCabelo=1, corRoupa=0, barba=0, olhos='mel', equip={})
    base_m = dict(corpo='m', pele=4, cabelo=1, corCabelo=0, corRoupa=4, barba=0, olhos='castanho', equip={})
    rows = []
    # 1: cabelos (mulher) · 2: cabelos (homem) + barbas
    rows.append([dict(base_f, cabelo=i, corCabelo=(i * 3) % 8, pele=i % 6) for i in range(8)])
    rows.append([dict(base_m, cabelo=i, corCabelo=(i * 5) % 8, pele=(i + 2) % 6, barba=(i % 3)) for i in range(8)])
    items = [('cabeca', x) for x in ('cab_faixa', 'cab_capuz', 'cab_elmo_silencio', 'cab_elmo_ferro', 'cab_coroa')] + \
            [('corpo', x) for x in ('cor_gibao', 'cor_malha', 'cor_sentinela')]
    rows.append([dict(base_m if k % 2 else base_f, equip={sl: it}) for k, (sl, it) in enumerate(items)])
    items2 = [('capa', x) for x in ('cap_curta', 'cap_constante', 'cap_fenix', 'cap_mestre')] + \
             [('arma', x) for x in ('arm_martelo', 'arm_martelo_juiz', 'arm_cajado', 'arm_lamina')]
    rows.append([dict(base_f if k % 2 else base_m, equip={sl: it}, corRoupa=k % 6) for k, (sl, it) in enumerate(items2)])
    rows.append([dict(base_m, equip={'amuleto': a}) for a in ('amu_ampulheta', 'amu_calma', 'amu_equilibrio')] +
                [dict(base_f, equip=dict(cabeca='cab_coroa', corpo='cor_placas', capa='cap_mestre', arma='arm_martelo_juiz', amuleto='amu_calma')),
                 dict(base_m, pele=1, cabelo=4, corCabelo=4, equip=dict(cabeca='cab_capuz', corpo='cor_gibao', capa='cap_curta', arma='arm_lamina')),
                 dict(base_f, pele=5, cabelo=6, corCabelo=0, equip=dict(cabeca='cab_elmo_silencio', corpo='cor_sentinela', arma='arm_cajado', amuleto='amu_equilibrio')),
                 dict(base_m, pele=0, cabelo=5, corCabelo=5, barba=2, corRoupa=3, equip=dict(corpo='cor_malha', capa='cap_fenix', arma='arm_martelo')),
                 dict(base_f, pele=3, cabelo=2, corCabelo=7, corRoupa=2, equip=dict(cabeca='cab_faixa', capa='cap_constante'))])
    T = 288
    W = Image.new('RGB', (8 * T, len(rows) * T), '#000')
    for ri, row in enumerate(rows):
        for ci, c in enumerate(row):
            W.paste(render_one(layers, c), (ci * T, ri * T))
    W.save(sys.argv[2]); print('ok', W.size)
