-- =====================================================================
-- Plateforme en ligne de gestion de souks de fruits et légumes
-- Base de données MySQL 8.0 ou plus récent
-- Contenu : 16 tables, 2 catégories, 1 compte admin, 1 compte livreur
-- Le script peut être relancé sans dupliquer les données de départ.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS souks_en_ligne
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE souks_en_ligne;

-- ---------------------------------------------------------------------
-- 1. Utilisateurs
-- ---------------------------------------------------------------------

-- Compte commun aux quatre rôles : admin, fournisseur, client et livreur.
CREATE TABLE IF NOT EXISTS users (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nom               VARCHAR(100) NOT NULL,
  prenom            VARCHAR(100) NOT NULL,
  email             VARCHAR(190) NOT NULL,
  telephone         VARCHAR(30)  NULL,
  mot_de_passe_hash VARCHAR(255) NOT NULL,
  role              ENUM('admin', 'fournisseur', 'client', 'livreur') NOT NULL,
  statut            ENUM('actif', 'suspendu') NOT NULL DEFAULT 'actif',
  created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email),
  KEY idx_users_role_statut (role, statut)
) ENGINE = InnoDB;

-- Informations propres au fournisseur.
CREATE TABLE IF NOT EXISTS fournisseurs (
  user_id         BIGINT UNSIGNED NOT NULL,
  nom_commerce    VARCHAR(150) NOT NULL,
  adresse_retrait VARCHAR(255) NOT NULL,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_fournisseurs_user
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- Informations propres au livreur.
CREATE TABLE IF NOT EXISTS livreurs (
  user_id    BIGINT UNSIGNED NOT NULL,
  vehicule   VARCHAR(100) NOT NULL,
  zone       VARCHAR(150) NOT NULL,
  disponible BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (user_id),
  KEY idx_livreurs_disponible (disponible),
  CONSTRAINT fk_livreurs_user
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- Adresses de livraison du client.
CREATE TABLE IF NOT EXISTS adresses (
  id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  client_id BIGINT UNSIGNED NOT NULL,
  libelle   VARCHAR(100) NOT NULL,
  adresse   VARCHAR(255) NOT NULL,
  ville     VARCHAR(100) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_adresses_client (client_id),
  CONSTRAINT fk_adresses_client
    FOREIGN KEY (client_id) REFERENCES users (id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 2. Catalogue
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS categories (
  id  SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nom VARCHAR(50) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_categories_nom (nom)
) ENGINE = InnoDB;

-- Un produit retiré passe à actif = FALSE et reste lié à son historique.
CREATE TABLE IF NOT EXISTS produits (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  fournisseur_id BIGINT UNSIGNED NOT NULL,
  categorie_id   SMALLINT UNSIGNED NOT NULL,
  nom            VARCHAR(150) NOT NULL,
  description    TEXT NULL,
  photo          VARCHAR(255) NULL,
  unite          ENUM('kg', 'piece', 'botte', 'caisse') NOT NULL DEFAULT 'kg',
  prix           DECIMAL(10, 2) NOT NULL,
  stock          DECIMAL(10, 3) NOT NULL DEFAULT 0.000,
  actif          BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                 ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_produits_fournisseur (fournisseur_id),
  KEY idx_produits_catalogue (categorie_id, actif),
  CONSTRAINT chk_produits_prix  CHECK (prix >= 0),
  CONSTRAINT chk_produits_stock CHECK (stock >= 0),
  CONSTRAINT fk_produits_fournisseur
    FOREIGN KEY (fournisseur_id) REFERENCES fournisseurs (user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_produits_categorie
    FOREIGN KEY (categorie_id) REFERENCES categories (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 3. Panier
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS paniers (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  client_id  BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_paniers_client (client_id),
  CONSTRAINT fk_paniers_client
    FOREIGN KEY (client_id) REFERENCES users (id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS panier_lignes (
  panier_id  BIGINT UNSIGNED NOT NULL,
  produit_id BIGINT UNSIGNED NOT NULL,
  quantite   DECIMAL(10, 3) NOT NULL,
  PRIMARY KEY (panier_id, produit_id),
  KEY idx_panier_lignes_produit (produit_id),
  CONSTRAINT chk_panier_lignes_quantite CHECK (quantite > 0),
  CONSTRAINT fk_panier_lignes_panier
    FOREIGN KEY (panier_id) REFERENCES paniers (id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_panier_lignes_produit
    FOREIGN KEY (produit_id) REFERENCES produits (id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 4. Commandes, paiement simulé et livraison
-- ---------------------------------------------------------------------

-- Une commande concerne un seul fournisseur.
-- adresse_livraison est une copie : l'historique ne change pas ensuite.
CREATE TABLE IF NOT EXISTS commandes (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  client_id         BIGINT UNSIGNED NOT NULL,
  fournisseur_id    BIGINT UNSIGNED NOT NULL,
  adresse_livraison VARCHAR(255) NOT NULL,
  montant_total     DECIMAL(10, 2) NOT NULL,
  statut            ENUM('en_cours', 'payee', 'annulee') NOT NULL DEFAULT 'en_cours',
  created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_commandes_client (client_id, created_at),
  KEY idx_commandes_fournisseur (fournisseur_id, statut),
  KEY idx_commandes_statut (statut),
  CONSTRAINT chk_commandes_montant CHECK (montant_total >= 0),
  CONSTRAINT fk_commandes_client
    FOREIGN KEY (client_id) REFERENCES users (id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_commandes_fournisseur
    FOREIGN KEY (fournisseur_id) REFERENCES fournisseurs (user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- nom_produit et prix_unitaire sont copiés au moment de la commande.
CREATE TABLE IF NOT EXISTS commande_lignes (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  commande_id   BIGINT UNSIGNED NOT NULL,
  produit_id    BIGINT UNSIGNED NOT NULL,
  nom_produit   VARCHAR(150) NOT NULL,
  prix_unitaire DECIMAL(10, 2) NOT NULL,
  quantite      DECIMAL(10, 3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_commande_lignes_produit (commande_id, produit_id),
  KEY idx_commande_lignes_produit (produit_id),
  CONSTRAINT chk_commande_lignes_prix CHECK (prix_unitaire >= 0),
  CONSTRAINT chk_commande_lignes_quantite CHECK (quantite > 0),
  CONSTRAINT fk_commande_lignes_commande
    FOREIGN KEY (commande_id) REFERENCES commandes (id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_commande_lignes_produit
    FOREIGN KEY (produit_id) REFERENCES produits (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- Paiement fictif : aucune donnée bancaire n'est conservée.
CREATE TABLE IF NOT EXISTS paiements_simules (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  commande_id BIGINT UNSIGNED NOT NULL,
  montant     DECIMAL(10, 2) NOT NULL,
  reference   VARCHAR(50) NOT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_paiements_commande (commande_id),
  UNIQUE KEY uq_paiements_reference (reference),
  CONSTRAINT chk_paiements_montant CHECK (montant >= 0),
  CONSTRAINT fk_paiements_commande
    FOREIGN KEY (commande_id) REFERENCES commandes (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS livraisons (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  commande_id  BIGINT UNSIGNED NOT NULL,
  livreur_id   BIGINT UNSIGNED NOT NULL,
  statut       ENUM('a_recuperer', 'en_livraison', 'livree', 'echec')
               NOT NULL DEFAULT 'a_recuperer',
  raison_echec VARCHAR(255) NULL,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  livree_le    TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_livraisons_commande (commande_id),
  KEY idx_livraisons_livreur (livreur_id, statut),
  CONSTRAINT chk_livraisons_echec
    CHECK (statut <> 'echec' OR raison_echec IS NOT NULL),
  CONSTRAINT fk_livraisons_commande
    FOREIGN KEY (commande_id) REFERENCES commandes (id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_livraisons_livreur
    FOREIGN KEY (livreur_id) REFERENCES livreurs (user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 5. Avis, signalements et suspensions
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS avis (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  commande_id BIGINT UNSIGNED NOT NULL,
  note        TINYINT UNSIGNED NOT NULL,
  commentaire TEXT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_avis_commande (commande_id),
  CONSTRAINT chk_avis_note CHECK (note BETWEEN 1 AND 5),
  CONSTRAINT fk_avis_commande
    FOREIGN KEY (commande_id) REFERENCES commandes (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS signalements (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  commande_id BIGINT UNSIGNED NOT NULL,
  motif       TEXT NOT NULL,
  statut      ENUM('ouvert', 'classe_sans_suite', 'retenu')
              NOT NULL DEFAULT 'ouvert',
  decision    TEXT NULL,
  traite_par  BIGINT UNSIGNED NULL,
  traite_le   TIMESTAMP NULL DEFAULT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_signalements_commande (commande_id),
  KEY idx_signalements_statut (statut),
  KEY idx_signalements_admin (traite_par),
  CONSTRAINT fk_signalements_commande
    FOREIGN KEY (commande_id) REFERENCES commandes (id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_signalements_admin
    FOREIGN KEY (traite_par) REFERENCES users (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- fin reste vide tant que la suspension est en vigueur.
CREATE TABLE IF NOT EXISTS suspensions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  fournisseur_id BIGINT UNSIGNED NOT NULL,
  admin_id       BIGINT UNSIGNED NOT NULL,
  motif          TEXT NOT NULL,
  debut          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fin            TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (id),
  KEY idx_suspensions_fournisseur (fournisseur_id, fin),
  KEY idx_suspensions_admin (admin_id),
  CONSTRAINT fk_suspensions_fournisseur
    FOREIGN KEY (fournisseur_id) REFERENCES fournisseurs (user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_suspensions_admin
    FOREIGN KEY (admin_id) REFERENCES users (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS demandes_reouverture (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  suspension_id BIGINT UNSIGNED NOT NULL,
  motif         TEXT NOT NULL,
  statut        ENUM('en_attente', 'acceptee', 'refusee')
                NOT NULL DEFAULT 'en_attente',
  traite_par    BIGINT UNSIGNED NULL,
  traite_le     TIMESTAMP NULL DEFAULT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_demandes_suspension (suspension_id),
  KEY idx_demandes_statut (statut),
  KEY idx_demandes_admin (traite_par),
  CONSTRAINT fk_demandes_suspension
    FOREIGN KEY (suspension_id) REFERENCES suspensions (id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_demandes_admin
    FOREIGN KEY (traite_par) REFERENCES users (id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 6. Données de départ
-- ---------------------------------------------------------------------

INSERT IGNORE INTO categories (nom) VALUES
  ('Fruits'),
  ('Légumes');

-- Comptes de démonstration, à changer avant la mise en production :
--   admin@souks.local    / Admin@2026!
--   livreur@souks.local  / Livreur@2026!
-- Les mots de passe sont stockés sous forme de hachage bcrypt.
INSERT IGNORE INTO users
  (nom, prenom, email, telephone, mot_de_passe_hash, role)
VALUES
  ('Admin', 'Principal', 'admin@souks.local', '0600000001',
   '$2y$12$qkS3EeGs8/Xhndo6bc7i1OXB8SS4DiKeisE9WV8zjcfE9DvxzAvbS', 'admin'),
  ('Livreur', 'Demo', 'livreur@souks.local', '0600000002',
   '$2y$12$XK1tn/FU5Ulf5kJeWyOmS.c3RBu1n7I9AFoVrMU/g.6HaFbFWd6pi', 'livreur');

INSERT IGNORE INTO livreurs (user_id, vehicule, zone)
SELECT id, 'Moto', 'Centre-ville'
FROM users
WHERE email = 'livreur@souks.local';

