#!/usr/bin/env python3
"""But : produire schema_pipeline_ci_cd.png à partir de schema_pipeline_ci_cd.drawio, sans installer draw.io.

Fonctionnement : traduit en HTML et SVG le sous-ensemble de draw.io utilisé par ce schéma (rectangles, flèches
droites, ou coudées avec exitX/exitY/entryX/entryY et points intermédiaires), puis photographie la page avec
Chromium en mode sans écran. La taille de l'image est celle de la page du schéma (pageWidth, pageHeight), à
l'échelle 2.

Usage : python3 docs/livrables/render_schema.py      (aucun paramètre ; chromium-browser requis)
Le Chromium installé par snap ne voit pas /tmp : les fichiers intermédiaires sont créés sous le dossier personnel.
"""
import html
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'schema_pipeline_ci_cd.drawio'
TARGET = HERE / 'schema_pipeline_ci_cd.png'


def style_of(cell):
    return dict(part.split('=', 1) for part in (cell.get('style') or '').split(';') if '=' in part)


def box_of(cell):
    geometry = cell.find('mxGeometry')
    return tuple(float(geometry.get(name)) for name in ('x', 'y', 'width', 'height'))


def border_point(start, towards):
    """Point du bord du rectangle `start` sur la droite horizontale ou verticale qui mène à `towards`."""
    x, y, width, height = start
    center = (x + width / 2, y + height / 2)
    dx = towards[0] + towards[2] / 2 - center[0]
    dy = towards[1] + towards[3] / 2 - center[1]
    if abs(dx) * height > abs(dy) * width:
        return (x + width if dx > 0 else x, center[1])
    return (center[0], y + height if dy > 0 else y)


def vertex_html(cell):
    style = style_of(cell)
    x, y, width, height = box_of(cell)
    fill = style.get('fillColor', 'none')
    stroke = style.get('strokeColor', '#000')
    line = 'dashed' if style.get('dashed') else 'solid'
    border = 'none' if stroke == 'none' else f'{style.get("strokeWidth", "1")}px {line} {stroke}'
    top = style.get('verticalAlign') == 'top'
    align = style.get('align', 'center')
    css = [
        'position:absolute', f'left:{x}px', f'top:{y}px', f'width:{width}px', f'height:{height}px',
        'box-sizing:border-box', f'background:{"transparent" if fill == "none" else fill}', f'border:{border}',
        f'border-radius:{"4px" if style.get("arcSize") else "10px"}', 'display:flex', 'flex-direction:column',
        f'justify-content:{"flex-start" if top else "center"}',
        f'align-items:{"flex-start" if align == "left" else "center"}', f'text-align:{align}',
        f'padding:{"6px" if top else "2px 6px"}', f'font-size:{style.get("fontSize", "12")}px',
        f'font-weight:{"bold" if style.get("fontStyle") == "1" else "normal"}', 'white-space:pre-line',
    ]
    return f'<div style="{";".join(css)}">{html.escape(cell.get("value") or "")}</div>'


def edge_points(cell, cells):
    style = style_of(cell)
    source = box_of(cells[cell.get('source')])
    target = box_of(cells[cell.get('target')])
    if 'exitX' not in style:
        return [border_point(source, target), border_point(target, source)]

    def anchor(box, kind):
        return (box[0] + box[2] * float(style[f'{kind}X']), box[1] + box[3] * float(style[f'{kind}Y']))

    middle = [(float(p.get('x')), float(p.get('y'))) for p in cell.iter('mxPoint')]
    return [anchor(source, 'exit'), *middle, anchor(target, 'entry')]


def page_html(model, cells):
    width, height = model.get('pageWidth'), model.get('pageHeight')
    boxes = [vertex_html(c) for c in cells.values() if c.get('vertex') == '1']
    lines, colors = [], set()
    for cell in (c for c in cells.values() if c.get('edge') == '1'):
        style = style_of(cell)
        color = style.get('strokeColor', '#333')
        colors.add(color)
        points = edge_points(cell, cells)
        dash = ' stroke-dasharray="8 5"' if style.get('dashed') else ''
        path = ' '.join(f'{x:.1f},{y:.1f}' for x, y in points)
        lines.append(f'<polyline points="{path}" fill="none" stroke="{color}" stroke-width="2"{dash} '
                     f'marker-end="url(#a{color[1:]})"/>')
        if cell.get('value'):
            (x1, y1), (x2, y2) = points[0], points[1]
            lines.append(f'<text x="{(x1 + x2) / 2 + 6}" y="{(y1 + y2) / 2 - 6}" font-size="12" fill="{color}">'
                         f'{html.escape(cell.get("value"))}</text>')
    markers = ''.join(f'<marker id="a{c[1:]}" markerWidth="10" markerHeight="8" refX="9" refY="4" orient="auto">'
                      f'<path d="M0,0 L10,4 L0,8 z" fill="{c}"/></marker>' for c in sorted(colors))
    return (f'<html><head><meta charset="utf-8"></head><body style="margin:0;background:#fff;'
            f'font-family:Helvetica,Arial,sans-serif"><div style="position:relative;width:{width}px;'
            f'height:{height}px"><svg width="{width}" height="{height}" style="position:absolute">'
            f'<defs>{markers}</defs>{"".join(lines)}</svg>{"".join(boxes)}</div></body></html>')


def main():
    # Les retours à la ligne des libellés (&#10;) sont conservés par l'analyseur XML.
    root = ET.fromstring(SOURCE.read_text(encoding='utf-8'))
    model = next(root.iter('mxGraphModel'))
    cells = {c.get('id'): c for c in root.iter('mxCell')}
    with tempfile.TemporaryDirectory(prefix='orion-schema-', dir=Path.home()) as work:
        page = Path(work) / 'schema.html'
        image = Path(work) / 'schema.png'
        page.write_text(page_html(model, cells), encoding='utf-8')
        size = f'{model.get("pageWidth")},{model.get("pageHeight")}'
        subprocess.run(['chromium-browser', '--headless', '--disable-gpu', '--hide-scrollbars',
                        f'--window-size={size}', '--force-device-scale-factor=2', f'--screenshot={image}',
                        page.as_uri()], check=True, capture_output=True)
        shutil.copyfile(image, TARGET)
    print(f'ok: {TARGET.name}')


if __name__ == '__main__':
    main()
