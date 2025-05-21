# Projet PlateForme RH - Documentation Technique

## Contexte du projet

La plateforme RH vise à automatiser l'importation des données de formation depuis 5 fichiers Excel distincts vers une base de données SQL Server centralisée appelée "GestionFormation". Actuellement, la gestion des formations se fait via plusieurs fichiers Excel qui nécessitent des reports manuels fastidieux et sources d'erreurs.

La solution développée permet d'importer les données via des scripts Python qui extraient, transforment et chargent les données en respectant des contraintes de sécurité et d'intégrité strictes.

### Contraintes majeures

- **Environnement réglementé** : La base de données SQL Server est soumise à des règles strictes
- **Aucune table temporaire** ne doit être créée côté Python (uniquement dans les procédures stockées)
- **Pas de requêtes SQL dynamiques directes** (utiliser exclusivement les procédures stockées)
- **Gestion sécurisée des identifiants** (pas de stockage en dur dans le code)
- **Traitement en mémoire** avec pandas pour tout l'ETL

## Architecture de la solution

### Structure de la base de données

La base "GestionFormation" comprend les tables principales suivantes :
- `Collaborateurs` (avec hiérarchie manager)
- `Categories_Formation`
- `Organismes_Formation`
- `Formations`
- `Budget_Annuel`
- `Plan_Formation`
- `Demandes_Formation`
- `Inscriptions_Formation`

Des vues et procédures stockées sont déjà en place pour les opérations d'importation et de reporting.

### Scripts d'importation

Les scripts Python développés suivent tous le même modèle :
1. Lecture du fichier Excel source
2. Validation et nettoyage des données en mémoire (pandas)
3. Insertion des données dans une table temporaire SQL (créée par la procédure stockée)
4. Appel à la procédure stockée correspondante
5. Journalisation des résultats

#### Scripts disponibles

1. `import_olu.py` : Importation du rapport OLU (Orange Learning University)
2. `import_suivi_formations.py` : Importation du fichier de suivi global des formations
3. `import_plan_formation.py` : Importation du plan de formation
4. `import_budget_formation.py` : Importation du budget des formations
5. `import_recueil_besoins.py` : Importation du recueil des besoins en formation

### Utilitaires

- `db.py` : Module centralisé pour la gestion des connexions SQL Server
- `config.ini.example` : Modèle de fichier de configuration

## État d'avancement du projet

### Réalisé

- ✅ Analyse des documents de spécification
- ✅ Implémentation des scripts d'importation basiques
- ✅ Centralisation de la logique de connexion à la base de données
- ✅ Mise en place de la validation des colonnes requises

### En cours / À faire

- ⏳ Tests unitaires et intégration
- ⏳ Gestion d'erreurs robuste
- ⏳ Documentation utilisateur finale
- ⏳ Optimisation des performances pour les gros volumes
- ⏳ Mise en place d'un scheduler

## Guide d'installation et d'utilisation

### Prérequis

- Python 3.8+
- SQL Server avec la base GestionFormation installée
- Tables et procédures stockées déjà configurées

### Installation

1. Cloner le dépôt
2. Installer les dépendances :
   ```bash
   pip install -r requirements.txt
   ```
3. Copier `config.ini.example` vers `config.ini` et configurer les paramètres de connexion

### Configuration

Le fichier `config.ini` doit contenir :

```ini
[sqlserver]
server = YOUR_SERVER_NAME
port = 1433
database = GestionFormation
username = sa
password = YOUR_PASSWORD
trusted_connection = no
encrypt = yes
trust_server_certificate = yes

timeout = 30
```

Alternativement, vous pouvez définir une variable d'environnement `PLATFORM_HR_CONFIG` pointant vers votre fichier de configuration.

### Utilisation des scripts

#### 1. Import OLU

```bash
python import_olu.py path/to/OLU_report.xlsx --date 2025-05-20
```

#### 2. Import Suivi Formations

```bash
python import_suivi_formations.py path/to/suivi.xlsx --date 2025-05-20
```

#### 3. Import Plan Formation

```bash
python import_plan_formation.py path/to/plan.xlsx --annee 2025
```

#### 4. Import Budget

```bash
python import_budget_formation.py path/to/budget.xlsx --annee 2025
```

#### 5. Import Recueil Besoins

```bash
python import_recueil_besoins.py path/to/recueil.xlsx --annee 2025
```

### Ordre d'exécution recommandé

1. `import_suivi_formations.py` (référence principale)
2. `import_olu.py` (complément e-learning)
3. `import_recueil_besoins.py` (demandes)
4. `import_plan_formation.py` (plan validé)
5. `import_budget_formation.py` (allocations budgétaires)

## Structure des fichiers Excel

Chaque fichier Excel attendu a une structure spécifique. Voici un aperçu des colonnes requises :

### 1. Rapport OLU
- Utilisateur - ID d'utilisateur (requis)
- Utilisateur - Sexe de l'utilisateur
- Utilisateur - Manager - Nom complet
- Formation - Titre de la formation (requis)
- Récapitulatif - Statut (requis: "En cours", "Terminé", "Inscrit")
- Récapitulatif - Date d'inscription (requis)
- Récapitulatif - Date d'achèvement
- Formation - Heures de formation
- Formation - Type de formation
- Récapitulatif - Assigné par

### 2. SUIVI FORMATIONS
- CATEGORIE (requis)
- ID COLLABORATEUR (requis)
- GENRE (requis: "Homme", "Femme")
- MANAGER
- DEPARTEMENT (requis)
- CONTRAT (requis)
- ORGANISME FORMATION
- NOM FORMATION (requis)
- DU (date début)
- AU (date fin)
- DUREE (requis)
- TARIF HT
- Commentaires

### 3. PLAN FORMATION
- CATEGORIE/OBJECTIF (requis)
- COLLABORATEUR
- ID COLLABORATEUR (requis si COLLABORATEUR non spécifié)
- MANAGER
- DEPARTEMENT
- ORGANISME FORMATION
- TYPE FORMATION
- NOM FORMATION (requis)
- PRIORITE (1-5)
- SESSIONS (dates prévisionnelles)
- DUREE
- TARIF HT
- BUDGET (montant alloué)
- OBLIGATOIRE OU NON (Oui/Non)
- VALIDEE (Oui/Non)
- Commentaires

### 4. BUDGET FORMATION
- BUDGET année (entête - année au format YYYY)
- ORGANISME FORMATION
- NOM FORMATION (requis)
- DATES (période)
- TARIF HT
- BUDGET (requis)
- SEMESTRE DE VALIDATION (1 ou 2)
- EMPLOYES (liste des collaborateurs concernés)
- Commentaires

### 5. RECUEIL FORMATIONS
- CATEGORIE/OBJECTIF
- COLLABORATEUR
- ID COLLABORATEUR (requis si COLLABORATEUR non spécifié)
- MANAGER (requis)
- DEPARTEMENT (requis)
- ORGANISME FORMATION
- TYPE FORMATION
- NOM FORMATION (requis)
- PRIORITE (1-5, requis)
- SESSIONS (dates souhaitées)
- DUREE
- TARIF HT
- Commentaires

## Recommandations pour le développement futur

1. **Tests** : Développer des tests unitaires et d'intégration avec pytest
2. **Logging centralisé** : Améliorer la journalisation avec rotation des logs
3. **Gestion d'erreurs** : Implémenter une stratégie de reprise sur erreur
4. **Monitoring** : Ajouter des métriques sur les performances et la qualité des données
5. **Automatisation** : Mettre en place un orchestrateur (crontab, Airflow, etc.)
6. **Validation avancée** : Ajouter des règles métier de validation des données plus sophistiquées

## Contacts et ressources

- Documentation SQL Server : `doc/baseDeDonnee.sql`, `doc/procedureStocke.sql`, `doc/procedureKPI.sql`
- Spécifications du projet : `doc/procedure.md`
- Support technique : [Contact à ajouter]

---

Document créé le 22 mai 2025
