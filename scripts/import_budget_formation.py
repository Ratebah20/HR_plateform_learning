"""Importer le fichier BUDGET FORMATION.
Appelle `sp_ImporterBudgetFormation` (@annee INT).
"""
from __future__ import annotations

import argparse
import logging
from pathlib import Path

import pandas as pd

from . import db

logger = logging.getLogger("import_budget")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

EXPECTED_COLS = [
    "ORGANISME FORMATION",
    "NOM FORMATION",
    "DATES",
    "TARIF HT",
    "BUDGET",
    "SEMESTRE DE VALIDATION",
    "EMPLOYES",
    "Commentaires",
]

COL_MAP = {
    "ORGANISME FORMATION": "organisme_formation",
    "NOM FORMATION": "nom_formation",
    "DATES": "dates",
    "TARIF HT": "tarif_ht",
    "BUDGET": "budget",
    "SEMESTRE DE VALIDATION": "semestre_validation",
    "EMPLOYES": "employes",
    "Commentaires": "commentaires",
}

INSERT_SQL = (
    "INSERT INTO #TempBudget (organisme_formation, nom_formation, dates, tarif_ht, budget, "
    "semestre_validation, employes, commentaires) VALUES (?,?,?,?,?,?,?,?)"
)


def lire_excel(path: Path) -> pd.DataFrame:
    df = pd.read_excel(path, dtype=str, sheet_name=0)
    df.columns = df.columns.str.strip()
    missing = set(EXPECTED_COLS) - set(df.columns)
    if missing:
        raise ValueError(f"Colonnes manquantes: {', '.join(missing)}")
    logger.info("Lu %d lignes depuis %s", len(df), path)
    return df


def nettoyer(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["BUDGET"] = pd.to_numeric(df["BUDGET"], errors="coerce")
    df["TARIF HT"] = pd.to_numeric(df["TARIF HT"], errors="coerce")
    df["SEMESTRE DE VALIDATION"] = pd.to_numeric(df["SEMESTRE DE VALIDATION"], errors="coerce")
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
                r["organisme_formation"],
                r["nom_formation"],
                r["dates"],
                r["tarif_ht"],
                r["budget"],
                r["semestre_validation"],
                r["employes"],
                r["commentaires"],
            )
            for r in records
        ],
    )
    logger.info("Inséré %d lignes dans #TempBudget", len(records))


def main():
    ap = argparse.ArgumentParser(description="Import Budget Formation")
    ap.add_argument("excel", type=Path)
    ap.add_argument("--annee", type=int, required=True)
    args = ap.parse_args()

    df = nettoyer(lire_excel(args.excel))

    with db.get_connection() as conn:
        charger_temp(conn, df)
        db.call_stored_procedure("sp_ImporterBudgetFormation", args.annee)

    logger.info("Import Budget terminé")


if __name__ == "__main__":
    main()
