-- Script de procédures stockées pour l'importation des données
-- Pour Microsoft SQL Server

USE GestionFormation;
GO

-- Procédure pour importer les données depuis le fichier OLU
CREATE PROCEDURE sp_ImporterDonneesOLU
    @date_extraction DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Table temporaire pour stocker les données importées
    CREATE TABLE #TempOLU (
        id_utilisateur NVARCHAR(20),
        sexe_utilisateur NVARCHAR(10),
        manager_nom NVARCHAR(100),
        titre_formation NVARCHAR(255),
        statut NVARCHAR(20),
        date_inscription DATE,
        date_achevement DATE,
        heures_formation DECIMAL(8,2),
        type_formation NVARCHAR(50),
        assigne_par NVARCHAR(100)
    );
    
    -- NOTE: Dans un environnement réel, cette table serait remplie par un processus ETL
    -- qui lit le fichier Excel et insère les données dans cette table temporaire.
    -- Ici, nous allons supposer que les données sont déjà dans cette table.
    
    -- 1. Traitement des collaborateurs qui n'existent pas encore
    INSERT INTO Collaborateurs (id_collaborateur, genre, departement, type_contrat)
    SELECT DISTINCT 
        t.id_utilisateur, 
        ISNULL(t.sexe_utilisateur, 'Non spécifié'), 
        'À compléter', -- Département par défaut, à compléter ultérieurement
        'À compléter'  -- Type de contrat par défaut, à compléter ultérieurement
    FROM 
        #TempOLU t
    LEFT JOIN 
        Collaborateurs c ON t.id_utilisateur = c.id_collaborateur
    WHERE 
        c.id_collaborateur IS NULL;
    
    -- 2. Traitement des managers qui ne sont pas encore des collaborateurs
    INSERT INTO Collaborateurs (id_collaborateur, nom_complet, genre, departement, type_contrat)
    SELECT DISTINCT 
        'MGR_' + REPLACE(REPLACE(t.manager_nom, ' ', ''), ',', ''), -- Génération d'un ID manager temporaire
        t.manager_nom,
        'Non spécifié',
        'À compléter',
        'À compléter'
    FROM 
        #TempOLU t
    LEFT JOIN 
        Collaborateurs c ON t.manager_nom = c.nom_complet
    WHERE 
        c.id_collaborateur IS NULL
        AND t.manager_nom IS NOT NULL;
    
    -- 3. Mise à jour des liens manager-collaborateur
    UPDATE c
    SET c.id_manager = mgr.id_collaborateur
    FROM 
        Collaborateurs c
    INNER JOIN 
        #TempOLU t ON c.id_collaborateur = t.id_utilisateur
    INNER JOIN 
        Collaborateurs mgr ON t.manager_nom = mgr.nom_complet
    WHERE 
        c.id_manager IS NULL OR c.id_manager <> mgr.id_collaborateur;
    
    -- 4. Recherche ou création des organismes de formation (dans ce cas, OLU)
    IF NOT EXISTS (SELECT 1 FROM Organismes_Formation WHERE nom_organisme = 'Orange Learning University')
    BEGIN
        INSERT INTO Organismes_Formation (nom_organisme)
        VALUES ('Orange Learning University');
    END
    
    DECLARE @id_organisme_olu INT;
    SELECT @id_organisme_olu = id_organisme FROM Organismes_Formation WHERE nom_organisme = 'Orange Learning University';
    
    -- 5. Recherche ou création des catégories de formation
    EXEC sp_ImporterCategories;
    
    -- 6. Traitement des formations qui n'existent pas encore
    INSERT INTO Formations (nom_formation, id_categorie, id_organisme, type_formation, duree_heures)
    SELECT DISTINCT 
        t.titre_formation,
        (SELECT TOP 1 id_categorie FROM Categories_Formation WHERE nom_categorie = 'Technique - Métiers'), -- Catégorie par défaut
        @id_organisme_olu,
        t.type_formation,
        t.heures_formation
    FROM 
        #TempOLU t
    LEFT JOIN 
        Formations f ON t.titre_formation = f.nom_formation
    WHERE 
        f.id_formation IS NULL;
    
    -- 7. Création ou mise à jour des inscriptions
    MERGE INTO Inscriptions_Formation AS target
    USING (
        SELECT 
            t.id_utilisateur,
            f.id_formation,
            t.date_inscription,
            t.date_achevement,
            t.statut,
            t.heures_formation,
            t.assigne_par
        FROM 
            #TempOLU t
        INNER JOIN 
            Formations f ON t.titre_formation = f.nom_formation
    ) AS source (id_collaborateur, id_formation, date_inscription, date_achevement, statut, duree_reelle, assigne_par)
    ON (target.id_collaborateur = source.id_collaborateur 
        AND target.id_formation = source.id_formation 
        AND target.source_donnee = 'OLU')
    WHEN MATCHED THEN
        UPDATE SET 
            target.statut = source.statut,
            target.date_achevement = source.date_achevement,
            target.duree_reelle = source.duree_reelle
    WHEN NOT MATCHED THEN
        INSERT (id_collaborateur, id_formation, date_inscription, date_achevement, 
                statut, duree_reelle, source_donnee, assigne_par)
        VALUES (source.id_collaborateur, source.id_formation, source.date_inscription, 
                source.date_achevement, source.statut, source.duree_reelle, 'OLU', source.assigne_par);
    
    -- Nettoyage
    DROP TABLE #TempOLU;
    
    -- Journal d'importation
    INSERT INTO Journal_Importation (type_import, date_execution, nb_enregistrements)
    VALUES ('Import OLU', GETDATE(), @@ROWCOUNT);
END;
GO

-- Procédure pour importer les données depuis le fichier de suivi de formation
CREATE PROCEDURE sp_ImporterDonneesSuiviFormation
    @date_import DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Table temporaire pour stocker les données importées
    CREATE TABLE #TempSuivi (
        categorie NVARCHAR(100),
        id_collaborateur NVARCHAR(20),
        genre NVARCHAR(10),
        manager NVARCHAR(100),
        departement NVARCHAR(50),
        contrat NVARCHAR(20),
        organisme_formation NVARCHAR(100),
        nom_formation NVARCHAR(255),
        date_debut DATE,
        date_fin DATE,
        duree DECIMAL(8,2),
        tarif_ht DECIMAL(10,2),
        commentaires NVARCHAR(MAX)
    );
    
    -- NOTE: Dans un environnement réel, cette table serait remplie par un processus ETL
    
    -- 1. Mise à jour des collaborateurs existants ou création de nouveaux
    MERGE INTO Collaborateurs AS target
    USING (
        SELECT DISTINCT 
            id_collaborateur,
            genre,
            manager,
            departement,
            contrat
        FROM 
            #TempSuivi
    ) AS source
    ON target.id_collaborateur = source.id_collaborateur
    WHEN MATCHED THEN
        UPDATE SET 
            target.genre = source.genre,
            target.departement = source.departement,
            target.type_contrat = source.contrat
    WHEN NOT MATCHED THEN
        INSERT (id_collaborateur, genre, departement, type_contrat)
        VALUES (source.id_collaborateur, source.genre, source.departement, source.contrat);
    
    -- 2. Création ou mise à jour des organismes de formation
    MERGE INTO Organismes_Formation AS target
    USING (
        SELECT DISTINCT organisme_formation FROM #TempSuivi
    ) AS source (nom_organisme)
    ON target.nom_organisme = source.nom_organisme
    WHEN NOT MATCHED THEN
        INSERT (nom_organisme)
        VALUES (source.nom_organisme);
    
    -- 3. Traitement des catégories de formation
    MERGE INTO Categories_Formation AS target
    USING (
        SELECT DISTINCT categorie FROM #TempSuivi
    ) AS source (nom_categorie)
    ON target.nom_categorie = source.nom_categorie
    WHEN NOT MATCHED THEN
        INSERT (nom_categorie)
        VALUES (source.nom_categorie);
    
    -- 4. Création ou mise à jour des formations
    MERGE INTO Formations AS target
    USING (
        SELECT 
            ts.nom_formation,
            cat.id_categorie,
            org.id_organisme,
            'Type à définir' AS type_formation, -- À adapter selon les données réelles
            ts.duree,
            ts.tarif_ht
        FROM 
            #TempSuivi ts
        INNER JOIN 
            Categories_Formation cat ON ts.categorie = cat.nom_categorie
        INNER JOIN 
            Organismes_Formation org ON ts.organisme_formation = org.nom_organisme
        GROUP BY 
            ts.nom_formation, cat.id_categorie, org.id_organisme, ts.duree, ts.tarif_ht
    ) AS source
    ON target.nom_formation = source.nom_formation
    WHEN MATCHED THEN
        UPDATE SET 
            target.duree_heures = source.duree_heures,
            target.tarif_ht = source.tarif_ht
    WHEN NOT MATCHED THEN
        INSERT (nom_formation, id_categorie, id_organisme, type_formation, duree_heures, tarif_ht)
        VALUES (source.nom_formation, source.id_categorie, source.id_organisme, 
                source.type_formation, source.duree_heures, source.tarif_ht);
    
    -- 5. Création des inscriptions (si elles n'existent pas déjà en provenance d'OLU)
    INSERT INTO Inscriptions_Formation (
        id_collaborateur, id_formation, date_inscription, date_debut, date_fin,
        statut, duree_reelle, source_donnee)
    SELECT 
        ts.id_collaborateur,
        f.id_formation,
        ts.date_debut, -- Utilisation de la date de début comme date d'inscription
        ts.date_debut,
        ts.date_fin,
        CASE 
            WHEN ts.date_fin IS NULL THEN 'En cours'
            WHEN ts.date_fin < GETDATE() THEN 'Terminé'
            ELSE 'Inscrit'
        END AS statut,
        ts.duree,
        'SUIVI_INTERNE'
    FROM 
        #TempSuivi ts
    INNER JOIN 
        Formations f ON ts.nom_formation = f.nom_formation
    LEFT JOIN 
        Inscriptions_Formation i ON ts.id_collaborateur = i.id_collaborateur 
                               AND f.id_formation = i.id_formation
    WHERE 
        i.id_inscription IS NULL;
    
    -- Mise à jour des liens manager-collaborateur
    WITH ManagerData AS (
        SELECT DISTINCT
            c.id_collaborateur,
            m.id_collaborateur AS id_manager
        FROM 
            #TempSuivi ts
        INNER JOIN 
            Collaborateurs c ON ts.id_collaborateur = c.id_collaborateur
        INNER JOIN 
            Collaborateurs m ON ts.manager = m.nom_complet
    )
    UPDATE c
    SET c.id_manager = md.id_manager
    FROM 
        Collaborateurs c
    INNER JOIN 
        ManagerData md ON c.id_collaborateur = md.id_collaborateur
    WHERE 
        c.id_manager IS NULL OR c.id_manager <> md.id_manager;
    
    -- Nettoyage
    DROP TABLE #TempSuivi;
    
    -- Journal d'importation
    INSERT INTO Journal_Importation (type_import, date_execution, nb_enregistrements)
    VALUES ('Import Suivi Formations', GETDATE(), @@ROWCOUNT);
END;
GO

-- Procédure pour importer les données du plan de formation
CREATE PROCEDURE sp_ImporterPlanFormation
    @annee INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Table temporaire pour le plan de formation
    CREATE TABLE #TempPlan (
        categorie NVARCHAR(100),
        collaborateur NVARCHAR(100),
        id_collaborateur NVARCHAR(20),
        manager NVARCHAR(100),
        departement NVARCHAR(50),
        organisme_formation NVARCHAR(100),
        type_formation NVARCHAR(50),
        nom_formation NVARCHAR(255),
        priorite INT,
        sessions NVARCHAR(100),
        duree DECIMAL(8,2),
        tarif_ht DECIMAL(10,2),
        budget DECIMAL(10,2),
        obligatoire BIT,
        validee BIT,
        commentaires NVARCHAR(MAX)
    );
    
    -- Vérifier/créer le budget annuel
    IF NOT EXISTS (SELECT 1 FROM Budget_Annuel WHERE annee = @annee)
    BEGIN
        INSERT INTO Budget_Annuel (annee, montant_total)
        VALUES (@annee, 0); -- Montant à mettre à jour ultérieurement
    END
    
    DECLARE @id_budget INT;
    SELECT @id_budget = id_budget FROM Budget_Annuel WHERE annee = @annee;
    
    -- Création ou mise à jour des éléments du plan
    MERGE INTO Plan_Formation AS target
    USING (
        SELECT 
            @id_budget AS id_budget,
            f.id_formation,
            1 AS semestre_validation, -- Valeur par défaut, à adapter
            tp.sessions,
            tp.budget
        FROM 
            #TempPlan tp
        INNER JOIN 
            Formations f ON tp.nom_formation = f.nom_formation
    ) AS source
    ON target.id_budget = source.id_budget AND target.id_formation = source.id_formation
    WHEN MATCHED THEN
        UPDATE SET 
            target.session_prevue = source.session_prevue,
            target.budget_alloue = source.budget_alloue
    WHEN NOT MATCHED THEN
        INSERT (id_budget, id_formation, semestre_validation, session_prevue, budget_alloue)
        VALUES (source.id_budget, source.id_formation, source.semestre_validation, 
                source.session_prevue, source.budget_alloue);
    
    -- Créer les demandes validées correspondantes
    INSERT INTO Demandes_Formation (
        id_collaborateur, id_formation, priorite, date_demande, 
        session_souhaitee, validee, commentaires, id_budget)
    SELECT 
        c.id_collaborateur,
        f.id_formation,
        tp.priorite,
        GETDATE() AS date_demande,
        tp.sessions,
        tp.validee,
        tp.commentaires,
        @id_budget
    FROM 
        #TempPlan tp
    INNER JOIN 
        Collaborateurs c ON tp.id_collaborateur = c.id_collaborateur
    INNER JOIN 
        Formations f ON tp.nom_formation = f.nom_formation
    LEFT JOIN 
        Demandes_Formation d ON c.id_collaborateur = d.id_collaborateur 
                            AND f.id_formation = d.id_formation
                            AND d.id_budget = @id_budget
    WHERE 
        d.id_demande IS NULL;
    
    -- Mise à jour du budget annuel total
    UPDATE Budget_Annuel
    SET montant_total = (
        SELECT SUM(budget_alloue)
        FROM Plan_Formation
        WHERE id_budget = @id_budget
    )
    WHERE id_budget = @id_budget;
    
    -- Nettoyage
    DROP TABLE #TempPlan;
    
    -- Journal d'importation
    INSERT INTO Journal_Importation (type_import, date_execution, nb_enregistrements)
    VALUES ('Import Plan Formation ' + CAST(@annee AS NVARCHAR(4)), GETDATE(), @@ROWCOUNT);
END;
GO

-- Procédure pour importer les données du budget formation
CREATE PROCEDURE sp_ImporterBudgetFormation
    @annee INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Table temporaire pour le budget
    CREATE TABLE #TempBudget (
        organisme_formation NVARCHAR(100),
        nom_formation NVARCHAR(255),
        dates NVARCHAR(100),
        tarif_ht DECIMAL(10,2),
        budget DECIMAL(10,2),
        semestre_validation INT,
        employes NVARCHAR(MAX),
        commentaires NVARCHAR(MAX)
    );
    
    
-- Vérifier/créer le budget annuel
DECLARE @montant_total DECIMAL(12,2);
SELECT @montant_total = SUM(budget) FROM #TempBudget;

IF NOT EXISTS (SELECT 1 FROM Budget_Annuel WHERE annee = @annee)
BEGIN
    INSERT INTO Budget_Annuel (annee, montant_total)
    VALUES (@annee, @montant_total);
END
ELSE
BEGIN
    -- Mise à jour du montant total
    UPDATE Budget_Annuel
    SET montant_total = @montant_total
    WHERE annee = @annee;
END
    
    DECLARE @id_budget INT;
    SELECT @id_budget = id_budget FROM Budget_Annuel WHERE annee = @annee;
    
    -- Mise à jour des éléments du plan de formation
    MERGE INTO Plan_Formation AS target
    USING (
        SELECT 
            @id_budget AS id_budget,
            f.id_formation,
            tb.semestre_validation,
            tb.dates AS session_prevue,
            tb.budget
        FROM 
            #TempBudget tb
        INNER JOIN 
            Formations f ON tb.nom_formation = f.nom_formation
        INNER JOIN 
            Organismes_Formation o ON tb.organisme_formation = o.nom_organisme
    ) AS source
    ON target.id_budget = source.id_budget AND target.id_formation = source.id_formation
    WHEN MATCHED THEN
        UPDATE SET 
            target.semestre_validation = source.semestre_validation,
            target.session_prevue = source.session_prevue,
            target.budget_alloue = source.budget_alloue
    WHEN NOT MATCHED THEN
        INSERT (id_budget, id_formation, semestre_validation, session_prevue, budget_alloue)
        VALUES (source.id_budget, source.id_formation, source.semestre_validation, 
                source.session_prevue, source.budget_alloue);
    
    -- Nettoyage
    DROP TABLE #TempBudget;
    
    -- Journal d'importation
    INSERT INTO Journal_Importation (type_import, date_execution, nb_enregistrements)
    VALUES ('Import Budget Formation ' + CAST(@annee AS NVARCHAR(4)), GETDATE(), @@ROWCOUNT);
END;
GO

-- Procédure pour importer les données du recueil des besoins de formation
CREATE PROCEDURE sp_ImporterRecueilBesoins
    @annee INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Table temporaire pour le recueil des besoins
    CREATE TABLE #TempRecueil (
        categorie NVARCHAR(100),
        collaborateur NVARCHAR(100),
        id_collaborateur NVARCHAR(20),
        manager NVARCHAR(100),
        departement NVARCHAR(50),
        organisme_formation NVARCHAR(100),
        type_formation NVARCHAR(50),
        nom_formation NVARCHAR(255),
        priorite INT,
        sessions NVARCHAR(100),
        duree DECIMAL(8,2),
        tarif_ht DECIMAL(10,2),
        commentaires NVARCHAR(MAX)
    );
    
    -- Vérifier/créer le budget annuel
    IF NOT EXISTS (SELECT 1 FROM Budget_Annuel WHERE annee = @annee)
    BEGIN
        INSERT INTO Budget_Annuel (annee, montant_total)
        VALUES (@annee, 0); -- Montant à définir ultérieurement
    END
    
    DECLARE @id_budget INT;
    SELECT @id_budget = id_budget FROM Budget_Annuel WHERE annee = @annee;
    
    -- Création des demandes de formation
    INSERT INTO Demandes_Formation (
        id_collaborateur, id_formation, priorite, date_demande, 
        session_souhaitee, validee, commentaires, id_budget)
    SELECT 
        c.id_collaborateur,
        f.id_formation,
        tr.priorite,
        GETDATE() AS date_demande,
        tr.sessions,
        0 AS validee, -- Non validé par défaut
        tr.commentaires,
        @id_budget
    FROM 
        #TempRecueil tr
    INNER JOIN 
        Collaborateurs c ON tr.id_collaborateur = c.id_collaborateur
    INNER JOIN 
        Formations f ON tr.nom_formation = f.nom_formation
    LEFT JOIN 
        Demandes_Formation d ON c.id_collaborateur = d.id_collaborateur 
                            AND f.id_formation = d.id_formation
                            AND d.id_budget = @id_budget
    WHERE 
        d.id_demande IS NULL;
    
    -- Nettoyage
    DROP TABLE #TempRecueil;
    
    -- Journal d'importation
    INSERT INTO Journal_Importation (type_import, date_execution, nb_enregistrements)
    VALUES ('Import Recueil Besoins ' + CAST(@annee AS NVARCHAR(4)), GETDATE(), @@ROWCOUNT);
END;
GO

-- Procédure pour réconcilier les données entre OLU et le suivi interne
CREATE PROCEDURE sp_ReconcilierDonnees
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 1. Mettre à jour les inscriptions OLU avec les informations du suivi interne
    UPDATE olu
    SET olu.id_plan = si.id_plan
    FROM 
        Inscriptions_Formation olu
    INNER JOIN 
        Inscriptions_Formation si ON olu.id_collaborateur = si.id_collaborateur
                                AND olu.id_formation = si.id_formation
    WHERE 
        olu.source_donnee = 'OLU'
        AND si.source_donnee = 'SUIVI_INTERNE'
        AND si.id_plan IS NOT NULL
        AND olu.id_plan IS NULL;
    
    -- 2. Marquer comme terminées les formations achevées dans OLU mais pas dans le suivi interne
    UPDATE si
    SET si.statut = 'Terminé',
        si.date_achevement = olu.date_achevement
    FROM 
        Inscriptions_Formation si
    INNER JOIN 
        Inscriptions_Formation olu ON si.id_collaborateur = olu.id_collaborateur
                                  AND si.id_formation = olu.id_formation
    WHERE 
        si.source_donnee = 'SUIVI_INTERNE'
        AND olu.source_donnee = 'OLU'
        AND olu.statut = 'Terminé'
        AND si.statut <> 'Terminé';
    
    -- Journal de réconciliation
    INSERT INTO Journal_Importation (type_import, date_execution, nb_enregistrements)
    VALUES ('Réconciliation Données', GETDATE(), @@ROWCOUNT);
END;
GO

-- Table de journalisation des imports
CREATE TABLE Journal_Importation (
    id_journal INT IDENTITY(1,1) PRIMARY KEY,
    type_import NVARCHAR(100) NOT NULL,
    date_execution DATETIME2 NOT NULL,
    nb_enregistrements INT,
    statut NVARCHAR(20) DEFAULT 'Succès',
    message_erreur NVARCHAR(MAX)
);
GO

-- Procédure pour afficher l'état actuel de la base de données
CREATE PROCEDURE sp_AfficherEtatBase
AS
BEGIN
    -- Nombre de collaborateurs
    SELECT 'Collaborateurs' AS Table_Name, COUNT(*) AS Nombre FROM Collaborateurs;
    
    -- Nombre de formations
    SELECT 'Formations' AS Table_Name, COUNT(*) AS Nombre FROM Formations;
    
    -- Nombre d'inscriptions par source
    SELECT 'Inscriptions_' + source_donnee AS Table_Name, COUNT(*) AS Nombre 
    FROM Inscriptions_Formation
    GROUP BY source_donnee;
    
    -- Derniers imports
    SELECT TOP 5 type_import, date_execution, nb_enregistrements, statut
    FROM Journal_Importation
    ORDER BY date_execution DESC;
    
    -- Statistiques par département
    SELECT 
        departement,
        COUNT(DISTINCT c.id_collaborateur) AS Nb_Collaborateurs,
        COUNT(DISTINCT i.id_inscription) AS Nb_Inscriptions,
        SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS Formations_Terminees
    FROM 
        Collaborateurs c
    LEFT JOIN 
        Inscriptions_Formation i ON c.id_collaborateur = i.id_collaborateur
    GROUP BY 
        departement;
    
    -- État du budget
    SELECT 
        b.annee,
        b.montant_total AS Budget_Total,
        SUM(ISNULL(p.budget_alloue, 0)) AS Budget_Alloue,
        b.montant_total - SUM(ISNULL(p.budget_alloue, 0)) AS Budget_Restant
    FROM 
        Budget_Annuel b
    LEFT JOIN 
        Plan_Formation p ON b.id_budget = p.id_budget
    GROUP BY 
        b.annee, b.montant_total;
END;
GO