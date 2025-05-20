## Note importante sur l'environnement réglementé

La base de données SQL Server utilisée pour ce projet est soumise à des règles strictes et des contraintes de sécurité importantes. Par conséquent, les développeurs doivent impérativement respecter les consignes suivantes:

1. **Aucune table temporaire ne doit être créée dans la base de données**
   - Le traitement des données doit se faire intégralement en mémoire dans Python
   - N'utilisez pas de syntaxe comme `CREATE TABLE #Temp...` ou équivalent

2. **Restriction sur les opérations DDL/DML directes**
   - N'exécutez jamais de requêtes SQL dynamiques directes (via string formatting)
   - Utilisez exclusivement les procédures stockées existantes avec des paramètres

3. **Gestion de la sécurité**
   - Utilisez toujours des requêtes paramétrées pour prévenir les injections SQL
   - Ne stockez jamais les identifiants de connexion en dur dans le code
   - Utilisez un fichier de configuration externe ou des variables d'environnement

4. **Approche recommandée**
   - Lire les fichiers Excel avec pandas
   - Traiter/nettoyer les données en mémoire
   - Exécuter les procédures stockées ligne par ligne ou par lots avec des paramètres
   - Journaliser chaque opération sans écrire dans la base de données 

Ces restrictions sont non négociables et doivent être respectées rigoureusement.# Guide pour le développement des scripts d'importation des fichiers Excel vers la base de données GestionFormation

## Contexte

Ce projet vise à automatiser l'importation des données de formation depuis 5 fichiers Excel distincts vers une base de données SQL Server centralisée appelée "GestionFormation". Actuellement, la gestion des formations se fait via plusieurs fichiers Excel qui nécessitent des reports manuels fastidieux et sources d'erreurs.

Chaque fichier Excel a sa propre structure et son propre rôle dans le processus de gestion des formations. L'objectif est de créer un script Python dédié à chaque fichier pour extraire, transformer et charger les données dans la base de données via les procédures stockées SQL déjà implémentées.

## Description des fichiers Excel et spécifications d'importation

### 1. Rapport - ALL OLU TRAINING

**Description**: Extraction brute depuis la plateforme Orange Learning University (OLU) qui contient les formations suivies par les collaborateurs dans l'outil d'e-learning.

**Structure**:
- Utilisateur - ID d'utilisateur
- Utilisateur - Sexe de l'utilisateur (partiellement renseigné)
- Utilisateur - Manager - Nom complet
- Formation - Titre de la formation
- Récapitulatif - Statut (En cours, Terminé, Inscrit)
- Récapitulatif - Date d'inscription
- Récapitulatif - Date d'achèvement
- Formation - Heures de formation
- Formation - Type de formation
- Récapitulatif - Assigné par

**Procédure stockée cible**: `sp_ImporterDonneesOLU`

**Défis spécifiques**:
- Données incomplètes pour le genre des utilisateurs
- Absence d'informations sur le département et type de contrat
- Besoin de créer de nouveaux utilisateurs s'ils n'existent pas encore
- Gérer la mise à jour des statuts pour les inscriptions existantes

### 2. SUIVI FORMATIONS

**Description**: Fichier global de suivi maintenu par le service RH, qui centralise toutes les informations de formation. C'est le fichier principal à partir duquel l'analyse est faite actuellement.

**Structure**:
- CATEGORIE: Type de formation (Technique - Métiers, Management - GRH, etc.)
- ID COLLABORATEUR: Identifiant unique
- GENRE: Sexe du collaborateur (Homme/Femme)
- MANAGER: Nom du responsable
- DEPARTEMENT: Service d'appartenance (B2C, Human Ressources, etc.)
- CONTRAT: Type de contrat (CDI, etc.)
- ORGANISME FORMATION: Prestataire
- NOM FORMATION: Intitulé de la formation
- Dates DU/AU: Début et fin de formation
- DUREE: Durée en heures
- TARIF HT: Coût de la formation
- Commentaires: Notes diverses

**Procédure stockée cible**: `sp_ImporterDonneesSuiviFormation`

**Défis spécifiques**:
- Source de vérité pour les informations collaborateurs (à privilégier en cas de conflit)
- Besoin de réconcilier avec les données OLU
- Gérer les doublons potentiels d'inscriptions

### 3. PLAN DE FORMATION

**Description**: Template de planification des formations pour l'année en cours ou à venir, utilisé pour anticiper et budgétiser les formations.

**Structure**:
- BUDGET année: Information budgétaire globale
- CATEGORIE/OBJECTIF: Type de formation
- COLLABORATEUR: Personne à former
- MANAGER: Responsable
- DEPARTEMENT: Service
- ORGANISME FORMATION: Prestataire
- TYPE FORMATION: Modalité
- NOM FORMATION: Intitulé
- PRIORITE: Niveau d'importance
- SESSIONS: Dates prévues
- DUREE: Durée prévue
- TARIF HT: Coût estimé
- BUDGET: Montant alloué
- OBLIGATOIRE OU NON: Caractère obligatoire
- VALIDEE: Statut de validation

**Procédure stockée cible**: `sp_ImporterPlanFormation`

**Défis spécifiques**:
- Création ou mise à jour du budget annuel
- Liaison avec les demandes de formation
- Gestion des validations de formation

### 4. BUDGET FORMATION

**Description**: Fichier de suivi détaillé du budget formation, permettant de suivre les allocations et consommations.

**Structure**:
- BUDGET année: Enveloppe globale
- Budget consommé/restant: Montants et pourcentages
- ORGANISME FORMATION: Prestataire
- NOM FORMATION: Intitulé
- DATES: Période
- TARIF HT: Coût
- BUDGET: Allocation
- SEMESTRE DE VALIDATION: Période de validation
- EMPLOYES: Collaborateurs concernés

**Procédure stockée cible**: `sp_ImporterBudgetFormation`

**Défis spécifiques**:
- Calcul et mise à jour des budgets consommés
- Liaison avec le plan de formation
- Gestion des révisions budgétaires

### 5. RECUEIL FORMATIONS

**Description**: Template rempli par les managers pour exprimer les besoins en formation de leurs équipes.

**Structure**:
- CATEGORIE/OBJECTIF: Type de formation
- COLLABORATEUR: Personne à former
- MANAGER: Responsable émettant la demande
- DEPARTEMENT: Service
- ORGANISME FORMATION: Prestataire souhaité
- TYPE FORMATION: Modalité souhaitée
- NOM FORMATION: Intitulé
- PRIORITE: Niveau d'importance
- SESSIONS: Dates souhaitées
- DUREE: Durée estimée
- TARIF HT: Coût estimé
- Commentaires: Précisions sur la demande

**Procédure stockée cible**: `sp_ImporterRecueilBesoins`

**Défis spécifiques**:
- Création des formations si elles n'existent pas encore
- Association au bon budget annuel
- Gestion des statuts de demande (non validée par défaut)

## Spécifications techniques pour les scripts Python

### Exigences communes à tous les scripts

1. **Bibliothèques à utiliser**:
   - `pandas` pour la manipulation des fichiers Excel
   - `pyodbc` pour la connexion à SQL Server
   - `logging` pour la journalisation

2. **Structure générale**:
   ```python
   # Connexion à la base de données
   # Lecture du fichier Excel
   # Nettoyage et transformation des données en mémoire (avec pandas)
   # Exécution des procédures stockées avec des paramètres directs
   # Journalisation des résultats
   # Fermeture des connexions
   ```

   **IMPORTANT**: En raison des restrictions dans l'environnement SQL Server réglementé, tout le traitement des données doit se faire en mémoire dans Python. N'utilisez PAS de tables temporaires SQL. Les procédures stockées doivent être appelées directement avec des paramètres.

3. **Paramètres d'entrée**:
   - Chemin du fichier Excel
   - Paramètres de connexion à la base de données
   - Date d'importation ou année concernée (selon le fichier)

4. **Gestion des erreurs**:
   - Vérifier l'existence et la validité du fichier Excel
   - Valider la structure du fichier (colonnes attendues)
   - Capturer et journaliser toutes les erreurs SQL
   - Permettre une reprise sur erreur

5. **Journalisation**:
   - Nombre d'enregistrements traités
   - Nombre d'enregistrements créés/mis à jour
   - Erreurs et avertissements
   - Durée d'exécution

### Spécifications spécifiques par script

#### Script 1: import_olu.py

- Lire les données avec pandas et les traiter en mémoire
- Appeler la procédure `sp_ImporterDonneesOLU` avec la date d'extraction comme paramètre
- Cette procédure gère l'ensemble du processus d'importation des données OLU
- Ne pas créer de tables temporaires SQL Server
- Gérer les ID utilisateurs incomplets ou manquants
- Nettoyer les formats de date (convertir en format SQL Server)
- Journaliser les utilisateurs créés automatiquement

#### Script 2: import_suivi_formations.py

- Lire et traiter les données avec pandas en mémoire
- Appeler les procédures d'insertion/mise à jour pour chaque enregistrement ou par lots
- Éviter toute création de tables temporaires dans la base de données
- Vérifier la cohérence des données entre départements, managers et collaborateurs
- Traiter les commentaires et caractères spéciaux
- Journaliser les réconciliations effectuées avec OLU

#### Script 3: import_plan_formation.py

- Traiter toutes les données en mémoire avec pandas
- Appeler les procédures appropriées ligne par ligne ou par lots
- Aucune table temporaire SQL ne doit être créée
- Valider les données budgétaires (numériques, positives)
- Traiter les onglets multiples si présents
- Journaliser le plan créé et les mises à jour

#### Script 4: import_budget_formation.py

- Effectuer tout le traitement en mémoire
- Utiliser des appels de procédure directs avec paramètres
- Aucune création de tables dans la base de données
- Valider la cohérence des montants (total = somme des allocations)
- Gérer les formats monétaires (conversion en décimal)
- Journaliser les mises à jour budgétaires

#### Script 5: import_recueil_besoins.py

- Procéder au traitement entier en mémoire avec pandas
- Utiliser uniquement des appels aux procédures avec paramètres
- Strictement aucune table temporaire SQL
- Gérer les formats de priorité (conversion en entier)
- Traiter les demandes avec formations non existantes
- Journaliser les nouvelles demandes créées

## Flux de travail recommandé

1. Commencer par importer le fichier de suivi global (`import_suivi_formations.py`) pour établir la base de référence
2. Importer les données OLU (`import_olu.py`) pour compléter le suivi des formations en ligne
3. Importer le recueil des besoins (`import_recueil_besoins.py`) pour les nouvelles demandes
4. Importer le plan de formation (`import_plan_formation.py`) pour établir le plan validé
5. Importer le budget (`import_budget_formation.py`) pour finaliser les allocations

## Tests recommandés

1. **Tests unitaires** pour chaque fonction de transformation
2. **Tests d'intégration** avec un petit ensemble de données de test
3. **Validation des données** post-importation via les procédures:
   ```sql
   EXEC sp_AfficherEtatBase;
   EXEC sp_TableauDeBord;
   ```


## Résultats attendus

Pour chaque script:
- Fichier Python commenté et documenté
- Documentation d'utilisation (paramètres, exemples)
- Rapport de tests
