"""Script pour corriger directement les fichiers problématiques."""

import os
import re
import shutil

SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))

def backup_file(file_path):
    """Crée une sauvegarde du fichier avant modification."""
    backup_path = file_path + ".bak10"
    if not os.path.exists(backup_path):
        shutil.copy2(file_path, backup_path)
        print(f"Sauvegarde créée: {backup_path}")
    return backup_path

def fix_file(file_path):
    """Corrige un fichier en remplaçant son contenu."""
    backup_file(file_path)
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Corriger les blocs if dans les fonctions
    content = re.sub(
        r'(if pd\.isna\(v\):)\s*\n\s*(if key in \["duree", "tarif_ht", "budget", "sessions", "priorite", "heures_formation"\]:)',
        r'\1\n                if key in ["duree", "tarif_ht", "budget", "sessions", "priorite", "heures_formation"]:',
        content
    )
    
    # Corriger les blocs if dans les fonctions charger_temp
    content = re.sub(
        r'(if pd\.isna\(value\):)\s*\n\s*(if key in \["duree", "tarif_ht", "budget", "sessions", "priorite", "heures_formation"\]:)',
        r'\1\n                if key in ["duree", "tarif_ht", "budget", "sessions", "priorite", "heures_formation"]:',
        content
    )
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Correction appliquée à {file_path}")

def main():
    """Fonction principale pour appliquer toutes les corrections."""
    print("Début des corrections directes")
    
    # Corriger tous les fichiers problématiques
    fix_file(os.path.join(SCRIPTS_DIR, "import_olu.py"))
    fix_file(os.path.join(SCRIPTS_DIR, "import_suivi_formations.py"))
    fix_file(os.path.join(SCRIPTS_DIR, "import_plan_formation.py"))
    fix_file(os.path.join(SCRIPTS_DIR, "import_budget_formation.py"))
    fix_file(os.path.join(SCRIPTS_DIR, "import_recueil_besoins.py"))
    
    print("Corrections terminées avec succès")

if __name__ == "__main__":
    main()
