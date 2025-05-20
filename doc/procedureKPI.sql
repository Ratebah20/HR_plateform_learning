-- Script de création des procédures pour les KPIs et reporting
-- Pour Microsoft SQL Server

USE GestionFormation;
GO

-- Vue: KPIs globaux sur les formations
CREATE VIEW vw_KPI_Global AS
SELECT
    (SELECT COUNT(id_collaborateur) FROM Collaborateurs) AS nombre_total_collaborateurs,
    (SELECT COUNT(id_formation) FROM Formations) AS nombre_total_formations,
    (SELECT COUNT(id_inscription) FROM Inscriptions_Formation) AS nombre_total_inscriptions,
    (SELECT COUNT(id_inscription) FROM Inscriptions_Formation WHERE statut = 'Terminé') AS nombre_formations_terminees,
    (SELECT COUNT(id_inscription) FROM Inscriptions_Formation WHERE statut = 'En cours') AS nombre_formations_en_cours,
    (SELECT COUNT(id_inscription) FROM Inscriptions_Formation WHERE statut = 'Inscrit') AS nombre_formations_inscrites,
    (SELECT SUM(duree_reelle) FROM Inscriptions_Formation WHERE statut = 'Terminé') AS heures_formation_totales,
    (SELECT AVG(duree_reelle) FROM Inscriptions_Formation WHERE statut = 'Terminé') AS moyenne_heures_par_formation;
GO

-- Vue: Top 10 des formations les plus suivies
CREATE VIEW vw_Top10_Formations AS
SELECT TOP 10
    f.nom_formation,
    cat.nom_categorie,
    COUNT(i.id_inscription) AS nombre_inscrits,
    SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_termines,
    AVG(CASE WHEN i.statut = 'Terminé' THEN i.duree_reelle ELSE NULL END) AS duree_moyenne
FROM 
    Formations f
    INNER JOIN Categories_Formation cat ON f.id_categorie = cat.id_categorie
    INNER JOIN Inscriptions_Formation i ON f.id_formation = i.id_formation
GROUP BY 
    f.nom_formation, cat.nom_categorie
ORDER BY 
    nombre_inscrits DESC;
GO

-- Vue: Taux de réalisation du plan de formation
CREATE VIEW vw_Taux_Realisation_Plan AS
SELECT
    b.annee,
    COUNT(DISTINCT p.id_plan) AS nombre_formations_planifiees,
    COUNT(DISTINCT i.id_inscription) AS nombre_inscriptions_realisees,
    SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_formations_terminees,
    CAST(COUNT(DISTINCT i.id_inscription) * 100.0 / NULLIF(COUNT(DISTINCT p.id_plan), 0) AS DECIMAL(5,2)) AS taux_inscriptions,
    CAST(SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(DISTINCT p.id_plan), 0) AS DECIMAL(5,2)) AS taux_realisation
FROM 
    Budget_Annuel b
    INNER JOIN Plan_Formation p ON b.id_budget = p.id_budget
    LEFT JOIN Inscriptions_Formation i ON p.id_formation = i.id_formation AND i.id_plan = p.id_plan
GROUP BY 
    b.annee;
GO

-- Vue: Répartition des formations par catégorie
CREATE VIEW vw_Repartition_Categorie AS
SELECT
    cat.nom_categorie,
    COUNT(DISTINCT f.id_formation) AS nombre_formations,
    COUNT(DISTINCT i.id_inscription) AS nombre_inscriptions,
    SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_termines,
    CAST(COUNT(DISTINCT i.id_inscription) * 100.0 / (SELECT COUNT(*) FROM Inscriptions_Formation) AS DECIMAL(5,2)) AS pourcentage_inscriptions
FROM 
    Categories_Formation cat
    LEFT JOIN Formations f ON cat.id_categorie = f.id_categorie
    LEFT JOIN Inscriptions_Formation i ON f.id_formation = i.id_formation
GROUP BY 
    cat.nom_categorie;
GO

-- Vue: Formations par département
CREATE VIEW vw_Formations_Departement AS
SELECT
    c.departement,
    COUNT(DISTINCT c.id_collaborateur) AS nombre_collaborateurs,
    COUNT(DISTINCT i.id_inscription) AS nombre_inscriptions,
    SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_termines,
    AVG(CASE WHEN i.statut = 'Terminé' THEN i.duree_reelle ELSE NULL END) AS duree_moyenne_par_formation,
    SUM(CASE WHEN i.statut = 'Terminé' THEN i.duree_reelle ELSE 0 END) / COUNT(DISTINCT c.id_collaborateur) AS heures_par_collaborateur
FROM 
    Collaborateurs c
    LEFT JOIN Inscriptions_Formation i ON c.id_collaborateur = i.id_collaborateur
GROUP BY 
    c.departement;
GO

-- Vue: Formations par manager
CREATE VIEW vw_Formations_Manager AS
SELECT
    m.nom_complet AS manager,
    COUNT(DISTINCT c.id_collaborateur) AS nombre_collaborateurs,
    COUNT(DISTINCT i.id_inscription) AS nombre_inscriptions,
    SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_termines,
    COUNT(DISTINCT i.id_inscription) / COUNT(DISTINCT c.id_collaborateur) AS ratio_inscriptions_par_collaborateur
FROM 
    Collaborateurs m
    INNER JOIN Collaborateurs c ON m.id_collaborateur = c.id_manager
    LEFT JOIN Inscriptions_Formation i ON c.id_collaborateur = i.id_collaborateur
GROUP BY 
    m.nom_complet;
GO

-- Vue: Comparaison source OLU vs suivi interne
CREATE VIEW vw_Comparaison_Sources AS
SELECT
    f.nom_formation,
    SUM(CASE WHEN i.source_donnee = 'OLU' THEN 1 ELSE 0 END) AS inscriptions_olu,
    SUM(CASE WHEN i.source_donnee = 'SUIVI_INTERNE' THEN 1 ELSE 0 END) AS inscriptions_suivi_interne,
    SUM(CASE WHEN i.source_donnee = 'OLU' AND i.statut = 'Terminé' THEN 1 ELSE 0 END) AS terminees_olu,
    SUM(CASE WHEN i.source_donnee = 'SUIVI_INTERNE' AND i.statut = 'Terminé' THEN 1 ELSE 0 END) AS terminees_suivi_interne
FROM 
    Formations f
    INNER JOIN Inscriptions_Formation i ON f.id_formation = i.id_formation
GROUP BY 
    f.nom_formation
HAVING 
    SUM(CASE WHEN i.source_donnee = 'OLU' THEN 1 ELSE 0 END) > 0
    AND SUM(CASE WHEN i.source_donnee = 'SUIVI_INTERNE' THEN 1 ELSE 0 END) > 0;
GO

-- Vue: Évolution mensuelle des formations
CREATE VIEW vw_Evolution_Mensuelle AS
SELECT
    YEAR(i.date_inscription) AS annee,
    MONTH(i.date_inscription) AS mois,
    COUNT(i.id_inscription) AS nouvelles_inscriptions,
    SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS formations_terminees,
    AVG(CASE WHEN i.statut = 'Terminé' THEN i.duree_reelle ELSE NULL END) AS duree_moyenne
FROM 
    Inscriptions_Formation i
GROUP BY 
    YEAR(i.date_inscription), MONTH(i.date_inscription);

GO

-- Vue: Taux de formation par genre
CREATE VIEW vw_Taux_Formation_Genre AS
SELECT
    c.genre,
    COUNT(DISTINCT c.id_collaborateur) AS nombre_collaborateurs,
    COUNT(DISTINCT i.id_inscription) AS nombre_inscriptions,
    SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_termines,
    CAST(COUNT(DISTINCT i.id_inscription) * 100.0 / COUNT(DISTINCT c.id_collaborateur) AS DECIMAL(5,2)) AS inscriptions_par_collaborateur,
    CAST(SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT c.id_collaborateur) AS DECIMAL(5,2)) AS formations_terminees_par_collaborateur
FROM 
    Collaborateurs c
    LEFT JOIN Inscriptions_Formation i ON c.id_collaborateur = i.id_collaborateur
GROUP BY 
    c.genre;
GO

-- Vue: Taux de formation par type de contrat
CREATE VIEW vw_Taux_Formation_Contrat AS
SELECT
    c.type_contrat,
    COUNT(DISTINCT c.id_collaborateur) AS nombre_collaborateurs,
    COUNT(DISTINCT i.id_inscription) AS nombre_inscriptions,
    SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_termines,
    CAST(COUNT(DISTINCT i.id_inscription) * 100.0 / COUNT(DISTINCT c.id_collaborateur) AS DECIMAL(5,2)) AS inscriptions_par_collaborateur,
    CAST(SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT c.id_collaborateur) AS DECIMAL(5,2)) AS formations_terminees_par_collaborateur
FROM 
    Collaborateurs c
    LEFT JOIN Inscriptions_Formation i ON c.id_collaborateur = i.id_collaborateur
GROUP BY 
    c.type_contrat;
GO

-- Procédure stockée: Produire un rapport de formation par collaborateur
CREATE PROCEDURE sp_RapportFormationCollaborateur
    @id_collaborateur NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Informations de base sur le collaborateur
    SELECT 
        c.id_collaborateur,
        c.nom_complet,
        c.genre,
        c.departement,
        c.type_contrat,
        m.nom_complet AS manager
    FROM 
        Collaborateurs c
        LEFT JOIN Collaborateurs m ON c.id_manager = m.id_collaborateur
    WHERE 
        c.id_collaborateur = @id_collaborateur;
    
    -- Liste des formations suivies
    SELECT 
        f.nom_formation,
        cat.nom_categorie,
        org.nom_organisme,
        i.date_inscription,
        i.date_achevement,
        i.statut,
        i.duree_reelle,
        i.source_donnee
    FROM 
        Inscriptions_Formation i
        INNER JOIN Formations f ON i.id_formation = f.id_formation
        INNER JOIN Categories_Formation cat ON f.id_categorie = cat.id_categorie
        INNER JOIN Organismes_Formation org ON f.id_organisme = org.id_organisme
    WHERE 
        i.id_collaborateur = @id_collaborateur
    ORDER BY 
        i.date_inscription DESC;
    
    -- Statistiques des formations
    SELECT 
        COUNT(i.id_inscription) AS nombre_total_formations,
        SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_formations_terminees,
        SUM(CASE WHEN i.statut = 'En cours' THEN 1 ELSE 0 END) AS nombre_formations_en_cours,
        SUM(CASE WHEN i.statut = 'Inscrit' THEN 1 ELSE 0 END) AS nombre_formations_inscrites,
        SUM(CASE WHEN i.statut = 'Terminé' THEN i.duree_reelle ELSE 0 END) AS heures_formation_totales
    FROM 
        Inscriptions_Formation i
    WHERE 
        i.id_collaborateur = @id_collaborateur;
    
    -- Distribution par catégorie
    SELECT 
        cat.nom_categorie,
        COUNT(i.id_inscription) AS nombre_formations,
        SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_terminees
    FROM 
        Inscriptions_Formation i
        INNER JOIN Formations f ON i.id_formation = f.id_formation
        INNER JOIN Categories_Formation cat ON f.id_categorie = cat.id_categorie
    WHERE 
        i.id_collaborateur = @id_collaborateur
    GROUP BY 
        cat.nom_categorie
    ORDER BY 
        nombre_formations DESC;
    
    -- Demandes de formation en attente
    SELECT 
        f.nom_formation,
        cat.nom_categorie,
        d.priorite,
        d.date_demande,
        d.session_souhaitee,
        d.commentaires,
        b.annee AS annee_budget
    FROM 
        Demandes_Formation d
        INNER JOIN Formations f ON d.id_formation = f.id_formation
        INNER JOIN Categories_Formation cat ON f.id_categorie = cat.id_categorie
        INNER JOIN Budget_Annuel b ON d.id_budget = b.id_budget
    WHERE 
        d.id_collaborateur = @id_collaborateur
        AND d.validee = 0
    ORDER BY 
        d.priorite;
END;
GO

-- Procédure stockée: Produire un rapport sur les formations par département
CREATE PROCEDURE sp_RapportFormationDepartement
    @departement NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Nombre de collaborateurs dans le département
    SELECT COUNT(*) AS nombre_collaborateurs
    FROM Collaborateurs
    WHERE departement = @departement;
    
    -- Résumé des formations
    SELECT 
        COUNT(DISTINCT i.id_inscription) AS nombre_inscriptions,
        SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_terminees,
        SUM(CASE WHEN i.statut = 'En cours' THEN 1 ELSE 0 END) AS nombre_en_cours,
        SUM(CASE WHEN i.statut = 'Inscrit' THEN 1 ELSE 0 END) AS nombre_inscrites,
        SUM(CASE WHEN i.statut = 'Terminé' THEN i.duree_reelle ELSE 0 END) AS heures_formation_totales,
        AVG(CASE WHEN i.statut = 'Terminé' THEN i.duree_reelle ELSE NULL END) AS duree_moyenne_par_formation
    FROM 
        Collaborateurs c
        INNER JOIN Inscriptions_Formation i ON c.id_collaborateur = i.id_collaborateur
    WHERE 
        c.departement = @departement;
    
    -- Répartition par catégorie
    SELECT 
        cat.nom_categorie,
        COUNT(DISTINCT i.id_inscription) AS nombre_inscriptions,
        SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_terminees,
        SUM(CASE WHEN i.statut = 'Terminé' THEN i.duree_reelle ELSE 0 END) AS heures_formation_totales
    FROM 
        Collaborateurs c
        INNER JOIN Inscriptions_Formation i ON c.id_collaborateur = i.id_collaborateur
        INNER JOIN Formations f ON i.id_formation = f.id_formation
        INNER JOIN Categories_Formation cat ON f.id_categorie = cat.id_categorie
    WHERE 
        c.departement = @departement
    GROUP BY 
        cat.nom_categorie
    ORDER BY 
        nombre_inscriptions DESC;
    
    -- Top 10 des formations par nombre d'inscriptions
    SELECT TOP 10
        f.nom_formation,
        cat.nom_categorie,
        COUNT(DISTINCT i.id_inscription) AS nombre_inscriptions,
        SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_terminees
    FROM 
        Collaborateurs c
        INNER JOIN Inscriptions_Formation i ON c.id_collaborateur = i.id_collaborateur
        INNER JOIN Formations f ON i.id_formation = f.id_formation
        INNER JOIN Categories_Formation cat ON f.id_categorie = cat.id_categorie
    WHERE 
        c.departement = @departement
    GROUP BY 
        f.nom_formation, cat.nom_categorie
    ORDER BY 
        nombre_inscriptions DESC;
    
    -- Répartition par manager
    SELECT 
        m.nom_complet AS manager,
        COUNT(DISTINCT c.id_collaborateur) AS nombre_collaborateurs,
        COUNT(DISTINCT i.id_inscription) AS nombre_inscriptions,
        SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_terminees,
        SUM(CASE WHEN i.statut = 'Terminé' THEN i.duree_reelle ELSE 0 END) AS heures_formation_totales,
        SUM(CASE WHEN i.statut = 'Terminé' THEN i.duree_reelle ELSE 0 END) / COUNT(DISTINCT c.id_collaborateur) AS heures_par_collaborateur
    FROM 
        Collaborateurs c
        INNER JOIN Collaborateurs m ON c.id_manager = m.id_collaborateur
        LEFT JOIN Inscriptions_Formation i ON c.id_collaborateur = i.id_collaborateur
    WHERE 
        c.departement = @departement
    GROUP BY 
        m.nom_complet
    ORDER BY 
        nombre_collaborateurs DESC;
    
    -- Demandes de formation en attente
    SELECT 
        f.nom_formation,
        COUNT(d.id_demande) AS nombre_demandes,
        AVG(d.priorite) AS priorite_moyenne
    FROM 
        Demandes_Formation d
        INNER JOIN Collaborateurs c ON d.id_collaborateur = c.id_collaborateur
        INNER JOIN Formations f ON d.id_formation = f.id_formation
    WHERE 
        c.departement = @departement
        AND d.validee = 0
    GROUP BY 
        f.nom_formation
    ORDER BY 
        nombre_demandes DESC;
END;
GO

-- Procédure stockée: Produire un rapport de budget formation
CREATE PROCEDURE sp_RapportBudgetFormation
    @annee INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @id_budget INT;
    SELECT @id_budget = id_budget FROM Budget_Annuel WHERE annee = @annee;
    
    -- Informations générales sur le budget
    SELECT 
        b.annee,
        b.montant_total AS budget_total,
        SUM(p.budget_alloue) AS budget_alloue,
        b.montant_total - SUM(ISNULL(p.budget_alloue, 0)) AS budget_restant,
        (SUM(ISNULL(p.budget_alloue, 0)) / b.montant_total) * 100 AS pourcentage_consommation
    FROM 
        Budget_Annuel b
        LEFT JOIN Plan_Formation p ON b.id_budget = p.id_budget
    WHERE 
        b.id_budget = @id_budget
    GROUP BY 
        b.annee, b.montant_total;
    
    -- Répartition du budget par catégorie
    SELECT 
        cat.nom_categorie,
        COUNT(p.id_plan) AS nombre_formations,
        SUM(p.budget_alloue) AS budget_alloue,
        (SUM(p.budget_alloue) / (SELECT montant_total FROM Budget_Annuel WHERE id_budget = @id_budget)) * 100 AS pourcentage_budget
    FROM 
        Plan_Formation p
        INNER JOIN Formations f ON p.id_formation = f.id_formation
        INNER JOIN Categories_Formation cat ON f.id_categorie = cat.id_categorie
    WHERE 
        p.id_budget = @id_budget
    GROUP BY 
        cat.nom_categorie
    ORDER BY 
        budget_alloue DESC;
    
    -- Top 10 des formations par budget alloué
    SELECT TOP 10
        f.nom_formation,
        cat.nom_categorie,
        org.nom_organisme,
        p.budget_alloue,
        COUNT(i.id_inscription) AS nombre_inscrits,
        SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_termines
    FROM 
        Plan_Formation p
        INNER JOIN Formations f ON p.id_formation = f.id_formation
        INNER JOIN Categories_Formation cat ON f.id_categorie = cat.id_categorie
        INNER JOIN Organismes_Formation org ON f.id_organisme = org.id_organisme
        LEFT JOIN Inscriptions_Formation i ON p.id_formation = i.id_formation AND i.id_plan = p.id_plan
    WHERE 
        p.id_budget = @id_budget
    GROUP BY 
        f.nom_formation, cat.nom_categorie, org.nom_organisme, p.budget_alloue
    ORDER BY 
        p.budget_alloue DESC;
    
    -- Répartition du budget par département (basé sur les inscriptions)
    SELECT 
        c.departement,
        COUNT(DISTINCT c.id_collaborateur) AS nombre_collaborateurs,
        COUNT(DISTINCT i.id_inscription) AS nombre_inscriptions,
        SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_terminees,
        SUM(p.budget_alloue) / COUNT(DISTINCT i.id_inscription) AS cout_moyen_par_inscription
    FROM 
        Plan_Formation p
        INNER JOIN Inscriptions_Formation i ON p.id_formation = i.id_formation AND i.id_plan = p.id_plan
        INNER JOIN Collaborateurs c ON i.id_collaborateur = c.id_collaborateur
    WHERE 
        p.id_budget = @id_budget
    GROUP BY 
        c.departement
    ORDER BY 
        nombre_inscriptions DESC;
    
    -- ROI estimé (basé sur le nombre de formations terminées)
    SELECT 
        cat.nom_categorie,
        SUM(p.budget_alloue) AS budget_alloue,
        SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_terminees,
        CASE 
            WHEN SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) > 0 
            THEN SUM(p.budget_alloue) / SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END)
            ELSE 0
        END AS cout_par_formation_terminee
    FROM 
        Plan_Formation p
        INNER JOIN Formations f ON p.id_formation = f.id_formation
        INNER JOIN Categories_Formation cat ON f.id_categorie = cat.id_categorie
        LEFT JOIN Inscriptions_Formation i ON p.id_formation = i.id_formation AND i.id_plan = p.id_plan
    WHERE 
        p.id_budget = @id_budget
    GROUP BY 
        cat.nom_categorie
    ORDER BY 
        cout_par_formation_terminee;
END;
GO

-- Procédure stockée: Tableaux de bord consolidés
CREATE PROCEDURE sp_TableauDeBord
AS
BEGIN
    SET NOCOUNT ON;
    
    -- KPIs globaux
    SELECT * FROM vw_KPI_Global;
    
    -- Répartition des formations par catégorie
    SELECT * FROM vw_Repartition_Categorie;
    
    -- Top 5 des formations
    SELECT TOP 5 * FROM vw_Top10_Formations;
    
    -- Répartition par département
    SELECT * FROM vw_Formations_Departement;
    
    -- Répartition par genre
    SELECT * FROM vw_Taux_Formation_Genre;
    
    -- Évolution mensuelle (dernier semestre)
    SELECT TOP 6 * 
    FROM vw_Evolution_Mensuelle
    ORDER BY annee DESC, mois DESC;
    
    -- État du budget de l'année en cours
    DECLARE @annee_courante INT = YEAR(GETDATE());
    
    SELECT 
        b.annee,
        b.montant_total AS budget_total,
        SUM(ISNULL(p.budget_alloue, 0)) AS budget_alloue,
        b.montant_total - SUM(ISNULL(p.budget_alloue, 0)) AS budget_restant,
        (SUM(ISNULL(p.budget_alloue, 0)) / b.montant_total) * 100 AS pourcentage_consommation
    FROM 
        Budget_Annuel b
        LEFT JOIN Plan_Formation p ON b.id_budget = p.id_budget
    WHERE 
        b.annee = @annee_courante
    GROUP BY 
        b.annee, b.montant_total;
    
    -- Comparaison entre sources de données (OLU vs Suivi interne)
    SELECT TOP 5 * FROM vw_Comparaison_Sources;
    
    -- Demandes de formation en attente
    SELECT TOP 10 * FROM vw_Demandes_En_Attente;
    
    -- Alertes (formations obligatoires non suivies, budget dépassé, etc.)
    SELECT 
        'Formations obligatoires non suivies' AS alerte,
        COUNT(*) AS nombre
    FROM 
        Formations f
        CROSS JOIN Collaborateurs c
        LEFT JOIN Inscriptions_Formation i ON f.id_formation = i.id_formation 
                                          AND c.id_collaborateur = i.id_collaborateur
    WHERE 
        f.obligatoire = 1
        AND i.id_inscription IS NULL
    
    UNION ALL
    
    SELECT 
        'Budget dépassé' AS alerte,
        COUNT(*) AS nombre
    FROM 
        Budget_Annuel b
    WHERE 
        (SELECT SUM(budget_alloue) FROM Plan_Formation WHERE id_budget = b.id_budget) > b.montant_total
    
    UNION ALL
    
    SELECT 
        'Formations en retard' AS alerte,
        COUNT(*) AS nombre
    FROM 
        Inscriptions_Formation
    WHERE 
        statut = 'En cours'
        AND DATEDIFF(DAY, date_inscription, GETDATE()) > 90;
END;
GO