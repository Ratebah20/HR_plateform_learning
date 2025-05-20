"""Exemple d'utilisation de la connexion à la base de données SQL Server
en utilisant le module db.py et le fichier config.ini
"""
from __future__ import annotations

import logging
from pathlib import Path

from db import get_connection, call_stored_procedure

# Configuration du logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("exemple_connexion")

def afficher_info_db():
    """Affiche des informations sur la base de données."""
    try:
        # Obtenir une connexion à la base de données
        logger.info("Connexion à la base de données...")
        conn = get_connection()
        
        # Exécuter une requête simple
        cursor = conn.cursor()
        
        # Récupérer la liste des tables
        logger.info("Récupération de la liste des tables...")
        cursor.execute("""
            SELECT TABLE_NAME, TABLE_TYPE 
            FROM INFORMATION_SCHEMA.TABLES 
            ORDER BY TABLE_NAME
        """)
        
        # Afficher les résultats
        logger.info("Tables dans la base de données:")
        for i, (table_name, table_type) in enumerate(cursor.fetchall(), 1):
            logger.info(f"  {i}. {table_name} ({table_type})")
        
        # Fermer la connexion
        conn.close()
        logger.info("Connexion fermée avec succès.")
        
        return True
    except Exception as e:
        logger.error(f"Erreur lors de l'accès à la base de données: {e}")
        return False

def exemple_procedure_stockee():
    """Exemple d'appel à une procédure stockée (si disponible)."""
    try:
        # Exemple d'appel à une procédure stockée (à adapter selon vos procédures disponibles)
        logger.info("Tentative d'appel à une procédure stockée...")
        
        # Lister les procédures stockées disponibles
        with get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT ROUTINE_NAME 
                FROM INFORMATION_SCHEMA.ROUTINES 
                WHERE ROUTINE_TYPE = 'PROCEDURE'
                ORDER BY ROUTINE_NAME
            """)
            procedures = [row[0] for row in cursor.fetchall()]
        
        if procedures:
            logger.info(f"Procédures stockées disponibles: {', '.join(procedures[:5])}...")
            
            # Vous pouvez décommenter cette section si vous souhaitez tester un appel réel
            # Exemple: call_stored_procedure("nom_procedure", param1, param2, fetch=True)
        else:
            logger.info("Aucune procédure stockée trouvée dans la base de données.")
        
        return True
    except Exception as e:
        logger.error(f"Erreur lors de l'appel à une procédure stockée: {e}")
        return False

if __name__ == "__main__":
    logger.info("=== Exemple d'utilisation de la connexion à la base de données ===")
    afficher_info_db()
    exemple_procedure_stockee()
    logger.info("=== Fin de l'exemple ===")
