-- Script de création de la base de données Formation
-- Pour Microsoft SQL Server

-- Création de la base de données
CREATE DATABASE GestionFormation;
GO

USE GestionFormation;
GO

-- Table des catégories de formation
CREATE TABLE Categories_Formation (
    id_categorie INT IDENTITY(1,1) PRIMARY KEY,
    nom_categorie NVARCHAR(100) NOT NULL,
    description NVARCHAR(255),
    categorie_parent INT,
    date_creation DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT FK_CategorieParent FOREIGN KEY (categorie_parent) 
        REFERENCES Categories_Formation(id_categorie)
);
GO

-- Table des organismes de formation
CREATE TABLE Organismes_Formation (
    id_organisme INT IDENTITY(1,1) PRIMARY KEY,
    nom_organisme NVARCHAR(100) NOT NULL,
    contact_principal NVARCHAR(100),
    email NVARCHAR(100),
    telephone NVARCHAR(20),
    date_creation DATETIME2 DEFAULT GETDATE()
);
GO

-- Table des collaborateurs
CREATE TABLE Collaborateurs (
    id_collaborateur NVARCHAR(20) PRIMARY KEY,
    nom_complet NVARCHAR(100),
    genre NVARCHAR(10) NOT NULL,
    id_manager NVARCHAR(20),
    departement NVARCHAR(50) NOT NULL,
    type_contrat NVARCHAR(20) NOT NULL,
    date_creation DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT FK_Manager FOREIGN KEY (id_manager) 
        REFERENCES Collaborateurs(id_collaborateur)
);
GO

-- Table des budgets annuels
CREATE TABLE Budget_Annuel (
    id_budget INT IDENTITY(1,1) PRIMARY KEY,
    annee INT NOT NULL,
    montant_total DECIMAL(12,2) NOT NULL,
    date_creation DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT UQ_Annee UNIQUE (annee)
);
GO

-- Table des formations
CREATE TABLE Formations (
    id_formation INT IDENTITY(1,1) PRIMARY KEY,
    nom_formation NVARCHAR(255) NOT NULL,
    id_categorie INT NOT NULL,
    id_organisme INT NOT NULL,
    type_formation NVARCHAR(50) NOT NULL,
    duree_heures DECIMAL(8,2) NOT NULL,
    tarif_ht DECIMAL(10,2),
    description NVARCHAR(MAX),
    obligatoire BIT DEFAULT 0,
    date_creation DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT FK_CategorieFormation FOREIGN KEY (id_categorie) 
        REFERENCES Categories_Formation(id_categorie),
    CONSTRAINT FK_OrganismeFormation FOREIGN KEY (id_organisme) 
        REFERENCES Organismes_Formation(id_organisme)
);
GO

-- Table des demandes de formation
CREATE TABLE Demandes_Formation (
    id_demande INT IDENTITY(1,1) PRIMARY KEY,
    id_collaborateur NVARCHAR(20) NOT NULL,
    id_formation INT NOT NULL,
    priorite INT,
    date_demande DATE NOT NULL,
    session_souhaitee NVARCHAR(100),
    validee BIT DEFAULT 0,
    commentaires NVARCHAR(MAX),
    id_budget INT,
    date_creation DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT FK_CollaborateurDemande FOREIGN KEY (id_collaborateur) 
        REFERENCES Collaborateurs(id_collaborateur),
    CONSTRAINT FK_FormationDemande FOREIGN KEY (id_formation) 
        REFERENCES Formations(id_formation),
    CONSTRAINT FK_BudgetDemande FOREIGN KEY (id_budget) 
        REFERENCES Budget_Annuel(id_budget)
);
GO

-- Table du plan de formation
CREATE TABLE Plan_Formation (
    id_plan INT IDENTITY(1,1) PRIMARY KEY,
    id_budget INT NOT NULL,
    id_formation INT NOT NULL,
    semestre_validation INT,
    session_prevue NVARCHAR(100),
    budget_alloue DECIMAL(10,2),
    date_creation DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT FK_BudgetPlan FOREIGN KEY (id_budget) 
        REFERENCES Budget_Annuel(id_budget),
    CONSTRAINT FK_FormationPlan FOREIGN KEY (id_formation) 
        REFERENCES Formations(id_formation)
);
GO

-- Table des inscriptions aux formations
CREATE TABLE Inscriptions_Formation (
    id_inscription INT IDENTITY(1,1) PRIMARY KEY,
    id_collaborateur NVARCHAR(20) NOT NULL,
    id_formation INT NOT NULL,
    id_plan INT,
    date_inscription DATE NOT NULL,
    date_debut DATE,
    date_fin DATE,
    date_achevement DATE,
    statut NVARCHAR(20) NOT NULL,
    duree_reelle DECIMAL(8,2),
    source_donnee NVARCHAR(50),
    assigne_par NVARCHAR(100),
    date_creation DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT FK_CollaborateurInscription FOREIGN KEY (id_collaborateur) 
        REFERENCES Collaborateurs(id_collaborateur),
    CONSTRAINT FK_FormationInscription FOREIGN KEY (id_formation) 
        REFERENCES Formations(id_formation),
    CONSTRAINT FK_PlanInscription FOREIGN KEY (id_plan) 
        REFERENCES Plan_Formation(id_plan)
);
GO

-- Création d'index pour optimiser les performances
CREATE INDEX IX_Collaborateurs_Manager ON Collaborateurs(id_manager);
CREATE INDEX IX_Collaborateurs_Departement ON Collaborateurs(departement);
CREATE INDEX IX_Formations_Categorie ON Formations(id_categorie);
CREATE INDEX IX_Formations_Organisme ON Formations(id_organisme);
CREATE INDEX IX_Inscriptions_Collaborateur ON Inscriptions_Formation(id_collaborateur);
CREATE INDEX IX_Inscriptions_Formation ON Inscriptions_Formation(id_formation);
CREATE INDEX IX_Inscriptions_Statut ON Inscriptions_Formation(statut);
CREATE INDEX IX_Demandes_Collaborateur ON Demandes_Formation(id_collaborateur);
CREATE INDEX IX_Demandes_Formation ON Demandes_Formation(id_formation);
CREATE INDEX IX_Demandes_Validee ON Demandes_Formation(validee);
CREATE INDEX IX_Plan_Budget ON Plan_Formation(id_budget);
CREATE INDEX IX_Plan_Formation ON Plan_Formation(id_formation);
GO

-- Création des vues pour faciliter le reporting

-- Vue récapitulative des formations par collaborateur
CREATE VIEW vw_Formations_Par_Collaborateur AS
SELECT 
    c.id_collaborateur,
    c.nom_complet,
    c.genre,
    c.departement,
    c.type_contrat,
    mgr.nom_complet AS manager,
    f.nom_formation,
    cat.nom_categorie,
    org.nom_organisme,
    i.date_inscription,
    i.date_achevement,
    i.statut,
    i.duree_reelle,
    i.source_donnee
FROM 
    Collaborateurs c
    INNER JOIN Inscriptions_Formation i ON c.id_collaborateur = i.id_collaborateur
    INNER JOIN Formations f ON i.id_formation = f.id_formation
    INNER JOIN Categories_Formation cat ON f.id_categorie = cat.id_categorie
    INNER JOIN Organismes_Formation org ON f.id_organisme = org.id_organisme
    LEFT JOIN Collaborateurs mgr ON c.id_manager = mgr.id_collaborateur;
GO

-- Vue du plan de formation avec budget
CREATE VIEW vw_Plan_Formation_Budget AS
SELECT 
    p.id_plan,
    b.annee,
    f.nom_formation,
    cat.nom_categorie,
    org.nom_organisme,
    p.session_prevue,
    p.budget_alloue,
    f.duree_heures,
    COUNT(DISTINCT i.id_inscription) AS nombre_inscrits,
    SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS nombre_termines
FROM 
    Plan_Formation p
    INNER JOIN Budget_Annuel b ON p.id_budget = b.id_budget
    INNER JOIN Formations f ON p.id_formation = f.id_formation
    INNER JOIN Categories_Formation cat ON f.id_categorie = cat.id_categorie
    INNER JOIN Organismes_Formation org ON f.id_organisme = org.id_organisme
    LEFT JOIN Inscriptions_Formation i ON p.id_formation = i.id_formation AND i.id_plan = p.id_plan
GROUP BY 
    p.id_plan, b.annee, f.nom_formation, cat.nom_categorie, org.nom_organisme, 
    p.session_prevue, p.budget_alloue, f.duree_heures;
GO

-- Vue des KPIs de formation par département
CREATE VIEW vw_KPI_Formation_Departement AS
SELECT 
    c.departement,
    COUNT(DISTINCT c.id_collaborateur) AS nombre_collaborateurs,
    COUNT(DISTINCT i.id_inscription) AS nombre_inscriptions,
    SUM(CASE WHEN i.statut = 'Terminé' THEN 1 ELSE 0 END) AS formations_terminees,
    SUM(CASE WHEN i.statut = 'En cours' THEN 1 ELSE 0 END) AS formations_en_cours,
    SUM(i.duree_reelle) AS heures_formation_totales,
    AVG(i.duree_reelle) AS moyenne_heures_par_formation
FROM 
    Collaborateurs c
    LEFT JOIN Inscriptions_Formation i ON c.id_collaborateur = i.id_collaborateur
GROUP BY 
    c.departement;
GO

-- Vue du suivi budgétaire
CREATE VIEW vw_Suivi_Budget AS
SELECT 
    b.annee,
    b.montant_total AS budget_total,
    SUM(p.budget_alloue) AS budget_alloue,
    b.montant_total - SUM(ISNULL(p.budget_alloue, 0)) AS budget_restant,
    (SUM(ISNULL(p.budget_alloue, 0)) / b.montant_total) * 100 AS pourcentage_consommation
FROM 
    Budget_Annuel b
    LEFT JOIN Plan_Formation p ON b.id_budget = p.id_budget
GROUP BY 
    b.annee, b.montant_total;
GO

-- Vue des demandes de formation en attente
CREATE VIEW vw_Demandes_En_Attente AS
SELECT 
    d.id_demande,
    c.nom_complet AS collaborateur,
    m.nom_complet AS manager,
    c.departement,
    f.nom_formation,
    cat.nom_categorie,
    d.priorite,
    d.date_demande,
    d.session_souhaitee,
    d.commentaires
FROM 
    Demandes_Formation d
    INNER JOIN Collaborateurs c ON d.id_collaborateur = c.id_collaborateur
    INNER JOIN Collaborateurs m ON c.id_manager = m.id_collaborateur
    INNER JOIN Formations f ON d.id_formation = f.id_formation
    INNER JOIN Categories_Formation cat ON f.id_categorie = cat.id_categorie
WHERE 
    d.validee = 0;
GO

-- Procédure stockée pour réconcilier les données OLU avec les données existantes
CREATE PROCEDURE sp_ReconcilierDonneesOLU 
    @id_collaborateur NVARCHAR(20),
    @nom_formation NVARCHAR(255),
    @date_inscription DATE,
    @date_achevement DATE = NULL,
    @statut NVARCHAR(20),
    @duree_heures DECIMAL(8,2) = NULL
AS
BEGIN
    DECLARE @id_formation INT;
    DECLARE @inscription_existante INT;
    
    -- Trouver l'ID de formation correspondant
    SELECT @id_formation = id_formation 
    FROM Formations 
    WHERE nom_formation = @nom_formation;
    
    -- Si la formation n'existe pas, sortir avec un message d'erreur
    IF @id_formation IS NULL
    BEGIN
        RAISERROR('Formation non trouvée: %s', 16, 1, @nom_formation);
        RETURN;
    END
    
    -- Vérifier si l'inscription existe déjà
    SELECT @inscription_existante = id_inscription
    FROM Inscriptions_Formation
    WHERE id_collaborateur = @id_collaborateur 
      AND id_formation = @id_formation
      AND source_donnee = 'OLU';
      
    -- Si l'inscription existe, mettre à jour son statut et ses dates
    IF @inscription_existante IS NOT NULL
    BEGIN
        UPDATE Inscriptions_Formation
        SET statut = @statut,
            date_achevement = @date_achevement,
            duree_reelle = ISNULL(@duree_heures, duree_reelle)
        WHERE id_inscription = @inscription_existante;
    END
    -- Sinon, créer une nouvelle inscription
    ELSE
    BEGIN
        INSERT INTO Inscriptions_Formation 
            (id_collaborateur, id_formation, date_inscription, date_achevement, 
             statut, duree_reelle, source_donnee)
        VALUES 
            (@id_collaborateur, @id_formation, @date_inscription, @date_achevement,
             @statut, @duree_heures, 'OLU');
    END
END;
GO

-- Procédure stockée pour importer les catégories de formation
CREATE PROCEDURE sp_ImporterCategories
AS
BEGIN
    -- Insérer les catégories standards si elles n'existent pas déjà
    MERGE INTO Categories_Formation AS target
    USING (VALUES 
        (N'Langues', N'Anglais, etc'),
        (N'Informatique - Bureautique', N'Pack Office, etc'),
        (N'Management - GRH', N'Manager et fonctions RH'),
        (N'Finances - Comptabilité - Droit', NULL),
        (N'Qualité - ISO - Sécurité', N'Directement liées à la sécurité'),
        (N'Technique - Métiers', N'Relatives au métier'),
        (N'Adaptation au poste de travail', N'Apprentissage de nouvelles fonctions')
    ) AS source (nom_categorie, description)
    ON target.nom_categorie = source.nom_categorie
    WHEN NOT MATCHED THEN
        INSERT (nom_categorie, description)
        VALUES (source.nom_categorie, source.description);
END;
GO

-- Exécution des procédures d'initialisation
EXEC sp_ImporterCategories;
GO