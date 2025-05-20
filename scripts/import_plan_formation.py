"""Importer le fichier PLAN DE FORMATION dans GestionFormation.
Appelle `sp_ImporterPlanFormation` (@annee INT).
"""
from __future__ import annotations

import argparse
import logging
from pathlib import Path

import pandas as pd

from . import db

logger = logging.getLogger("import_plan")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

EXPECTED_COLS = [
    "CATEGORIE/OBJECTIF",
    "COLLABORATEUR",
    "ID COLLABORATEUR",
    "MANAGER",
    "DEPARTEMENT",
    "ORGANISME FORMATION",
    "TYPE FORMATION",
    "NOM FORMATION",
    "PRIORITE",
    "SESSIONS",
    "DUREE",
    "TARIF HT",
    "BUDGET",
    "OBLIGATOIRE OU NON",
    "VALIDEE",
    "Commentaires",
]

COL_MAP = {
    "CATEGORIE/OBJECTIF": "categorie",
    "COLLABORATEUR": "collaborateur",
    "ID COLLABORATEUR": "id_collaborateur",
    "MANAGER": "manager",
    "DEPARTEMENT": "departement",
    "ORGANISME FORMATION": "organisme_formation",
    "TYPE FORMATION": "type_formation",
    "NOM FORMATION": "nom_formation",
    "PRIORITE": "priorite",
    "SESSIONS": "sessions",
    "DUREE": "duree",
    "TARIF HT": "tarif_ht",
    "BUDGET": "budget",
    "OBLIGATOIRE OU NON": "obligatoire",
    "VALIDEE": "validee",
    "Commentaires": "commentaires",
}

INSERT_SQL = (
    "INSERT INTO #TempPlan (categorie, collaborateur, id_collaborateur, manager, departement, "
    "organisme_formation, type_formation, nom_formation, priorite, sessions, duree, tarif_ht, budget, "
    "obligatoire, validee, commentaires) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"
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
    # Nettoyages simples
    df["PRIORITE"] = pd.to_numeric(df["PRIORITE"], errors="coerce")
    df["BUDGET"] = pd.to_numeric(df["BUDGET"], errors="coerce")
    df["DUREE"] = pd.to_numeric(df["DUREE"], errors="coerce")
    df["OBLIGATOIRE OU NON"] = (
        df["OBLIGATOIRE OU NON"].fillna("").str.lower().str.startswith("o")
    )
    df["VALIDEE"] = df["VALIDEE"].fillna("").str.lower().str.startswith("o")
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
                r["collaborateur"],
                r["id_collaborateur"],
                r["manager"],
                r["departement"],
                r["organisme_formation"],
                r["type_formation"],
                r["nom_formation"],
                r["priorite"],
                r["sessions"],
                r["duree"],
                r["tarif_ht"],
                r["budget"],
                r["obligatoire"],
                r["validee"],
                r["commentaires"],
            )
            for r in records
        ],
    )
    logger.info("Inséré %d lignes dans #TempPlan", len(records))


def main():
    ap = argparse.ArgumentParser(description="Import Plan Formation")
    ap.add_argument("excel", type=Path)
    ap.add_argument("--annee", type=int, required=True, help="Année du budget (YYYY)")
    args = ap.parse_args()

    df = nettoyer(lire_excel(args.excel))

    with db.get_connection() as conn:
        charger_temp(conn, df)
        db.call_stored_procedure("sp_ImporterPlanFormation", args.annee)

    logger.info("Import Plan terminé")


if __name__ == "__main__":
    main()
