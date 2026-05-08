import zipfile, os, shutil

# Copiar analyze-frontend.sh do build anterior
ANALYZE_SH = '/tmp/output/analyze-frontend.sh'

base = '/tmp/feramentas-uteis'
shutil.rmtree(base, ignore_errors=True)

for path, content in files.items():
    full = os.path.join(base, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w') as f:
        f.write(content)

# Copiar analyze-frontend.sh para frontend/
shutil.copy(ANALYZE_SH, os.path.join(base, 'frontend', 'analyze-frontend.sh'))

# Criar ZIP
zip_path = '/tmp/output/feramentas-uteis.zip'
with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, fnames in os.walk(base):
        dirs[:] = [d for d in dirs if d != '.git']
        for fname in fnames:
            full = os.path.join(root, fname)
            arc  = full.replace(base + '/', '')
            zf.write(full, arc)

size_kb = os.path.getsize(zip_path) / 1024
print(f"ZIP: feramentas-uteis.zip ({size_kb:.1f} KB)\n")
print("Estrutura:")
with zipfile.ZipFile(zip_path) as zf:
    for info in sorted(zf.infolist(), key=lambda x: x.filename):
        kb = info.file_size / 1024
        print(f"  {info.filename:<60} {kb:5.1f} KB")
