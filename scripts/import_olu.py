"""Importation du rapport Excel OLU dans GestionFormation via sp_ImporterDonneesOLU.

Utilisation (exemple):
    python import_olu.py chemin/vers/rapport_OLU.xlsx --date 2025-05-19

Contraintes (depuis procedure.md):
* Pas de tables temporaires créées côté Python - tout est géré dans la procédure stockée.
* Tout l'ETL en mémoire utilisant pandas.
"""
from __future__ import annotations

import argparse
import logging
from datetime import date
from pathlib import Path

import pandas as pd

from . import db

logger = logging.getLogger("import_olu")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

# Colonnes attendues dans Excel
EXPECTED_COLS = [
    "Utilisateur - ID d'utilisateur",
    "Utilisateur - Sexe de l'utilisateur",
    "Utilisateur - Manager - Nom complet",
    "Formation - Titre de la formation",
    "Récapitulatif - Statut",
    "Récapitulatif - Date d'inscription",
    "Récapitulatif - Date d'achèvement",
    "Formation - Heures de formation",
    "Formation - Type de formation",
    "Récapitulatif - Assigné par",
]


def lire_excel(path: Path) -> pd.DataFrame:
    df = pd.read_excel(path, dtype=str)
    logger.info("Read %d rows from %s", len(df), path)
    # Strip surrounding spaces from column names
    df.columns = df.columns.str.strip()
    missing = set(EXPECTED_COLS) - set(df.columns)
    if missing:
        raise ValueError(f"Colonnes manquantes dans {path}: {', '.join(missing)}")
    return df


def nettoyer(df: pd.DataFrame) -> pd.DataFrame:
    """Nettoyage minimal - la procédure stockée fait le gros du travail, mais conversion des dates et nombres."""
    df = df.copy()

    def parse_date(s):
        if pd.isna(s):
            return None
        try:
            return pd.to_datetime(s, dayfirst=False, errors="coerce").date()
        except Exception:
            return None

    df["Récapitulatif - Date d'inscription"] = df[
        "Récapitulatif - Date d'inscription"
    ].apply(parse_date)
    df["Récapitulatif - Date d'achèvement"] = df[
        "Récapitulatif - Date d'achèvement"
    ].apply(parse_date)

    # Heures formation -> float
    df["Formation - Heures de formation"] = pd.to_numeric(
        df["Formation - Heures de formation"], errors="coerce"
    )
    return df


def charger_temp(conn, df: pd.DataFrame):
    """Insère le dataframe dans la table temporaire attendue par la procédure stockée.

    Nous utilisons fast executemany avec .to_records pour les performances.
    """
    col_map = {
        "Utilisateur - ID d'utilisateur": "id_utilisateur",
        "Utilisateur - Sexe de l'utilisateur": "sexe_utilisateur",
        "Utilisateur - Manager - Nom complet": "manager_nom",
        "Formation - Titre de la formation": "titre_formation",
        "Récapitulatif - Statut": "statut",
        "Récapitulatif - Date d'inscription": "date_inscription",
        "Récapitulatif - Date d'achèvement": "date_achevement",
        "Formation - Heures de formation": "heures_formation",
        "Formation - Type de formation": "type_formation",
        "Récapitulatif - Assigné par": "assigne_par",
    }
    df_sql = df.rename(columns=col_map)
    records = df_sql.to_dict("records")

    cursor = conn.cursor()
    cursor.fast_executemany = True

    cursor.executemany(
        "INSERT INTO #TempOLU (id_utilisateur, sexe_utilisateur, manager_nom, titre_formation, "
        "statut, date_inscription, date_achevement, heures_formation, type_formation, assigne_par) "
        "VALUES (?,?,?,?,?,?,?,?,?,?)",
        [
            (
                r["id_utilisateur"],
                r["sexe_utilisateur"],
                r["manager_nom"],
                r["titre_formation"],
                r["statut"],
                r["date_inscription"],
                r["date_achevement"],
                r["heures_formation"],
                r["type_formation"],
                r["assigne_par"],
            )
            for r in records
        ],
    )
    logger.info("Inserted %d rows into #TempOLU", len(records))


def main():
    ap = argparse.ArgumentParser(description="Importer le rapport OLU dans la BD")
    ap.add_argument("excel", type=Path, help="Chemin du fichier Excel OLU")
    ap.add_argument(
        "--date",
        type=lambda s: date.fromisoformat(s),
        default=date.today(),
        help="Date d'extraction à passer à la procédure (YYYY-MM-DD)",
    )
    args = ap.parse_args()

    df = nettoyer(lire_excel(args.excel))

    with db.get_connection() as conn:
        charger_temp(conn, df)
        db.call_stored_procedure("sp_ImporterDonneesOLU", args.date)
    logger.info("Import terminé avec succès")


if __name__ == "__main__":
    main()
