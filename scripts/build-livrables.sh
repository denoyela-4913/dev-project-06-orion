#!/usr/bin/env bash
# Génère les .docx des livrables à partir des .md (pandoc), puis met en page l'annexe du schéma.
#
# Pourquoi un post-traitement: pandoc ne sait pas changer l'orientation d'une page. Le docx produit n'a pas de
# taille de page (Word applique alors celle de sa langue). On fixe donc A4 portrait pour le corps du document,
# puis on insère un saut de section avant l'annexe et on passe la dernière section en A4 paysage, pour que le
# schéma du pipeline occupe toute la largeur.
# Usage: scripts/build-livrables.sh   (depuis n'importe quel dossier)
set -euo pipefail
cd "$(dirname "$0")/../docs/livrables"

for md in 01_veille_audit_recommandations.md 02_normalisation_plan_ci.md; do
  docx="${md%.md}.docx"
  pandoc "$md" -o "$docx" --toc --toc-depth=2
  python3 - "$docx" <<'PY'
import re, sys, zipfile, shutil

path = sys.argv[1]
PORTRAIT = '<w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>'
LANDSCAPE = '<w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="708" w:footer="708" w:gutter="0"/>'

with zipfile.ZipFile(path) as z:
    items = {n: z.read(n) for n in z.namelist()}
xml = items["word/document.xml"].decode("utf-8")

# Dernière section (propriétés du corps du document): footnotePr existant + taille de page.
last = list(re.finditer(r"<w:sectPr>(.*?)</w:sectPr>", xml, re.S))[-1]
inner = last.group(1)
has_annex = "Annexe" in xml
if has_annex:
    # Fin de la section portrait juste avant le titre de l'annexe (nouvelle page par défaut).
    para_start = xml.rfind("<w:p>", 0, xml.index("Annexe"))
    para_start = max(para_start, xml.rfind("<w:p ", 0, xml.index("Annexe")))
    brk = f"<w:p><w:pPr><w:sectPr>{inner}{PORTRAIT}</w:sectPr></w:pPr></w:p>"
    xml = xml[:para_start] + brk + xml[para_start:]
    last = list(re.finditer(r"<w:sectPr>(.*?)</w:sectPr>", xml, re.S))[-1]
    final = f"<w:sectPr>{inner}{LANDSCAPE}</w:sectPr>"
else:
    final = f"<w:sectPr>{inner}{PORTRAIT}</w:sectPr>"
xml = xml[:last.start()] + final + xml[last.end():]
if has_annex:
    # pandoc borne la largeur d'une image à celle du texte en PORTRAIT: on agrandit donc l'image à la largeur
    # utile du paysage (A4 paysage, marges 2 cm: environ 10 pouces).
    m = re.search(r'<wp:extent cx="(\d+)" cy="(\d+)"', xml)
    cx, cy = int(m.group(1)), int(m.group(2))
    ncx = int(10.0 * 914400)
    ncy = round(cy * ncx / cx)
    xml = xml.replace(f'cx="{cx}" cy="{cy}"', f'cx="{ncx}" cy="{ncy}"')
items["word/document.xml"] = xml.encode("utf-8")

tmp = path + ".tmp"
with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
    for n, b in items.items():
        z.writestr(n, b)
shutil.move(tmp, path)
PY
  echo "ok: $docx"
done
