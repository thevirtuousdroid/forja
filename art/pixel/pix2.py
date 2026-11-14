import sys
from PIL import Image, ImageFilter, ImageEnhance
def conv(src, out, grid=128, cols=40):
    im = Image.open(src).convert('RGB')
    im = ImageEnhance.Contrast(im).enhance(1.15).filter(ImageFilter.UnsharpMask(1.2, 80, 2))
    s = im.resize((grid, grid), Image.BOX)
    q = s.quantize(colors=cols, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
    q.save(out); return q
if __name__ == '__main__':
    for b in sys.argv[1:]:
        conv(f'{b}_ai.png', f'{b}_q128.png')
