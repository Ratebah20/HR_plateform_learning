"""Utilitaires centralisés pour les connexions et appels au serveur SQL.

Les identifiants sont lus depuis un fichier de configuration ou des variables
d'environnement pour éviter de coder en dur des données sensibles.
"""
from __future__ import annotations

import configparser
import logging
import os
from pathlib import Path
from typing import Any, Iterable, Mapping

import pyodbc

logger = logging.getLogger(__name__)

CONFIG_LOCATIONS = [
    Path(__file__).with_suffix(".ini"),
    Path(__file__).parent / "config.ini",
    Path(__file__).parent.parent / "config.ini",
]


def _load_config() -> configparser.SectionProxy:
    """Trouve et charge le premier fichier de configuration lisible.

    Priorité : variable d'env ``PLATFORM_HR_CONFIG`` > emplacements par défaut.
    """
    location = os.getenv("PLATFORM_HR_CONFIG")
    if location:
        cfg_path = Path(location)
        if not cfg_path.exists():
            raise FileNotFoundError(cfg_path)
    else:
        cfg_path = next((p for p in CONFIG_LOCATIONS if p.exists()), None)

    if cfg_path is None:
        raise FileNotFoundError(
            "No config.ini found – copy config.ini.example and edit credentials"
        )

    parser = configparser.ConfigParser()
    parser.read(cfg_path, encoding="utf-8")
    return parser["sqlserver"]


def get_connection(autocommit: bool = False) -> pyodbc.Connection:
    """Retourne une nouvelle connexion pyodbc en utilisant le fichier de config/variables d'env."""

    cfg = _load_config()
    driver = cfg.get("driver", "ODBC Driver 17 for SQL Server")
    trusted = cfg.getboolean("trusted_connection", fallback=False)
    
    # Construction de la chaîne de connexion simplifiée
    if trusted:
        # Si le port est spécifié, l'inclure dans la chaîne de connexion
        if 'port' in cfg:
            server_str = f"{cfg['server']},{cfg['port']}"
        else:
            server_str = cfg['server']
            
        conn_str = (
            f"DRIVER={{{driver}}};SERVER={server_str};"
            f"DATABASE={cfg['database']};Trusted_Connection=yes;"
        )
    else:
        # Si le port est spécifié, l'inclure dans la chaîne de connexion
        if 'port' in cfg:
            server_str = f"{cfg['server']},{cfg['port']}"
        else:
            server_str = cfg['server']
            
        conn_str = (
            f"DRIVER={{{driver}}};SERVER={server_str};"
            f"DATABASE={cfg['database']};UID={cfg['username']};PWD={cfg['password']};"
        )

    # Ajouter les options de sécurité si elles sont spécifiées
    if 'encrypt' in cfg:
        conn_str += f"Encrypt={cfg['encrypt']};"
    
    if 'trust_server_certificate' in cfg:
        conn_str += f"TrustServerCertificate={cfg['trust_server_certificate']};"

    timeout = int(cfg.get("timeout", 30))
    logger.debug("Connexion à SQL Server %s/%s", cfg["server"], cfg["database"])
    logger.debug("Chaîne de connexion: %s", conn_str)
    return pyodbc.connect(conn_str, timeout=timeout, autocommit=autocommit)


def call_stored_procedure(
    name: str, *params: Any, fetch: bool = False, **kw_params: Any
) -> list[tuple] | None:
    """Exécute une procédure stockée et (optionnellement) retourne le jeu de résultats.

    Les paramètres positionnels viennent en premier, suivis des paramètres nommés (``@param=valeur``).
    """
    placeholders: list[str] = []
    for _ in params:
        placeholders.append("?")
    for k in kw_params:
        placeholders.append(f"@{k}=?")

    sql = f"EXEC {name} {', '.join(placeholders)}"
    all_params: Iterable[Any] = list(params) + list(kw_params.values())

    with get_connection() as conn:
        with conn.cursor() as cursor:
            logger.info("EXEC %s", name)
            cursor.execute(sql, *all_params)
            if fetch:
                rows = cursor.fetchall()
                logger.debug("Fetched %d rows from %s", len(rows), name)
                return rows
            return None
