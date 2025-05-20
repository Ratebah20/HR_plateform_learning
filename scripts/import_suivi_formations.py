"""Importer le fichier "SUIVI FORMATIONS" dans la base GestionFormation.

Appelle la procédure stockée `sp_ImporterDonneesSuiviFormation` qui attend un
paramètre `@date_import` (DATE) et récupère les données depuis la table
interne `#TempSuivi`.

Usage :
    python import_suivi_formations.py suivi.xlsx --date 2025-05-20
"""
from __future__ import annotations

import argparse
import logging
from datetime import date
from pathlib import Path
from typing import Any

import pandas as pd

from . import db

logger = logging.getLogger("import_suivi")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

EXPECTED_COLS = [
    "CATEGORIE",
    "ID COLLABORATEUR",
    "GENRE",
    "MANAGER",
    "DEPARTEMENT",
    "CONTRAT",
    "ORGANISME FORMATION",
    "NOM FORMATION",
    "DU",
    "AU",
    "DUREE",
    "TARIF HT",
    "Commentaires",
]

COL_MAP: dict[str, str] = {
    "CATEGORIE": "categorie",
    "ID COLLABORATEUR": "id_collaborateur",
    "GENRE": "genre",
    "MANAGER": "manager",
    "DEPARTEMENT": "departement",
    "CONTRAT": "contrat",
    "ORGANISME FORMATION": "organisme_formation",
    "NOM FORMATION": "nom_formation",
    "DU": "date_du",
    "AU": "date_au",
    "DUREE": "duree",
    "TARIF HT": "tarif_ht",
    "Commentaires": "commentaires",
}

INSERT_SQL = (
    "INSERT INTO #TempSuivi (categorie, id_collaborateur, genre, manager, departement, "
    "contrat, organisme_formation, nom_formation, date_du, date_au, duree, tarif_ht, commentaires) "
    "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)"
)


def lire_excel(path: Path) -> pd.DataFrame:
    df = pd.read_excel(path, dtype=str)
    df.columns = df.columns.str.strip()
    missing = set(EXPECTED_COLS) - set(df.columns)
    if missing:
        raise ValueError(f"Colonnes manquantes: {', '.join(missing)}")
    logger.info("Lu %d lignes depuis %s", len(df), path)
    return df


def nettoyer(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    def parse_date(value: Any):
        if pd.isna(value):
            return None
        try:
            return pd.to_datetime(value, dayfirst=False, errors="coerce").date()
        except Exception:
            return None

    df["DU"] = df["DU"].apply(parse_date)
    df["AU"] = df["AU"].apply(parse_date)

    # Nombreux champs numériques
    df["DUREE"] = pd.to_numeric(df["DUREE"], errors="coerce")
    df["TARIF HT"] = pd.to_numeric(df["TARIF HT"], errors="coerce")

    return df


def charger_temp(conn, df: pd.DataFrame):
    df_sql = df.rename(columns=COL_MAP)
    records = df_sql.to_dict("records")

    cur = conn.cursor()
    cur.fast_executemany = True
    cur.executemany(
        INSERT_SQL,
        [
            (
                r["categorie"],
                r["id_collaborateur"],
                r["genre"],
                r["manager"],
                r["departement"],
                r["contrat"],
                r["organisme_formation"],
                r["nom_formation"],
                r["date_du"],
                r["date_au"],
                r["duree"],
                r["tarif_ht"],
                r["commentaires"],
            )
            for r in records
        ],
    )
    logger.info("Inséré %d lignes dans #TempSuivi", len(records))


def main():
    ap = argparse.ArgumentParser(description="Import Suivi Formations")
    ap.add_argument("excel", type=Path)
    ap.add_argument("--date", type=lambda s: date.fromisoformat(s), default=date.today())
    args = ap.parse_args()

    df = nettoyer(lire_excel(args.excel))

    with db.get_connection() as conn:
        charger_temp(conn, df)
        db.call_stored_procedure("sp_ImporterDonneesSuiviFormation", args.date)

    logger.info("Import Suivi terminé")


if __name__ == "__main__":
    main()
