-- =====================================================
-- Projeto: Banco de Dados 01
-- Repositório: banco-de-dados01
-- =====================================================

-- Crie o BD (substitua <Num>)
CREATE DATABASE IF NOT EXISTS equipe01
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
USE equipe01;

-- =========================
-- 1) Tabelas de referência
-- =========================
CREATE TABLE curso (
  cod_curso INT PRIMARY KEY,
  nome_curso VARCHAR(120) NOT NULL
);

CREATE TABLE categoria (
  cod_categoria INT PRIMARY KEY,
  descricao VARCHAR(120) NOT NULL
);

CREATE TABLE subcategoria (
  cod_subcategoria INT PRIMARY KEY,
  cod_categoria INT NOT NULL,
  descricao VARCHAR(120) NOT NULL,
  CONSTRAINT fk_subcat_cat
    FOREIGN KEY (cod_categoria) REFERENCES categoria(cod_categoria)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  UNIQUE KEY uk_subcat_cat_desc (cod_categoria, descricao)
);

-- =========================
-- 2) Acervo
-- =========================
CREATE TABLE livro (
  isbn VARCHAR(20) PRIMARY KEY,
  titulo VARCHAR(200) NOT NULL,
  ano_lancamento INT NOT NULL,
  editora VARCHAR(120) NOT NULL,
  cod_categoria INT NOT NULL,
  cod_subcategoria INT NOT NULL,

  CONSTRAINT fk_livro_categoria
    FOREIGN KEY (cod_categoria) REFERENCES categoria(cod_categoria)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_livro_subcategoria
    FOREIGN KEY (cod_subcategoria) REFERENCES subcategoria(cod_subcategoria)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

-- garante que a subcategoria do livro pertence à mesma categoria do livro
DELIMITER $$
CREATE TRIGGER trg_livro_subcat_mesma_categoria
BEFORE INSERT ON livro
FOR EACH ROW
BEGIN
  DECLARE v_cat_sub INT;
  SELECT cod_categoria INTO v_cat_sub
  FROM subcategoria
  WHERE cod_subcategoria = NEW.cod_subcategoria;

  IF v_cat_sub IS NULL OR v_cat_sub <> NEW.cod_categoria THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Subcategoria informada não pertence à categoria do livro.';
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_livro_subcat_mesma_categoria_upd
BEFORE UPDATE ON livro
FOR EACH ROW
BEGIN
  DECLARE v_cat_sub INT;
  SELECT cod_categoria INTO v_cat_sub
  FROM subcategoria
  WHERE cod_subcategoria = NEW.cod_subcategoria;

  IF v_cat_sub IS NULL OR v_cat_sub <> NEW.cod_categoria THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Subcategoria informada não pertence à categoria do livro.';
  END IF;
END$$
DELIMITER ;

-- Exemplar: PK (isbn, num_exemplar) => num_exemplar sequencial por livro
CREATE TABLE exemplar (
  isbn VARCHAR(20) NOT NULL,
  num_exemplar INT NOT NULL,
  status_exemplar ENUM('DISPONIVEL','EMPRESTADO','RESERVADO','INATIVO') NOT NULL DEFAULT 'DISPONIVEL',
  PRIMARY KEY (isbn, num_exemplar),
  CONSTRAINT fk_exemplar_livro
    FOREIGN KEY (isbn) REFERENCES livro(isbn)
    ON DELETE CASCADE ON UPDATE CASCADE
);

-- Autor e relacionamento N:N com livro, marcando autor principal
CREATE TABLE autor (
  id_autor INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(120) NOT NULL,
  email VARCHAR(120) NOT NULL,
  nacionalidade VARCHAR(80) NOT NULL,
  UNIQUE KEY uk_autor_email (email)
);

CREATE TABLE livro_autor (
  isbn VARCHAR(20) NOT NULL,
  id_autor INT NOT NULL,
  principal TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (isbn, id_autor),
  CONSTRAINT fk_la_livro
    FOREIGN KEY (isbn) REFERENCES livro(isbn)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_la_autor
    FOREIGN KEY (id_autor) REFERENCES autor(id_autor)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

-- garante 1 único autor principal por livro
DELIMITER $$
CREATE TRIGGER trg_um_autor_principal_por_livro
BEFORE INSERT ON livro_autor
FOR EACH ROW
BEGIN
  IF NEW.principal = 1 THEN
    IF EXISTS (
      SELECT 1 FROM livro_autor
      WHERE isbn = NEW.isbn AND principal = 1
    ) THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Já existe autor principal para este livro.';
    END IF;
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_um_autor_principal_por_livro_upd
BEFORE UPDATE ON livro_autor
FOR EACH ROW
BEGIN
  IF NEW.principal = 1 THEN
    IF EXISTS (
      SELECT 1 FROM livro_autor
      WHERE isbn = NEW.isbn AND principal = 1
        AND id_autor <> NEW.id_autor

> Ádrian,:
) THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Já existe autor principal para este livro.';
    END IF;
  END IF;
END$$
DELIMITER ;

-- =========================
-- 3) Usuários (superclasse + subclasses)
-- =========================
CREATE TABLE usuario (
  id_usuario INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(120) NOT NULL,
  endereco VARCHAR(200) NOT NULL,
  tipo ENUM('ALUNO','PROFESSOR','FUNCIONARIO') NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  data_cadastro DATE NOT NULL DEFAULT (CURRENT_DATE)
);

CREATE TABLE usuario_telefone (
  id_usuario INT NOT NULL,
  telefone VARCHAR(30) NOT NULL,
  PRIMARY KEY (id_usuario, telefone),
  CONSTRAINT fk_tel_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE aluno (
  id_usuario INT PRIMARY KEY,
  matricula VARCHAR(30) NOT NULL UNIQUE,
  cod_curso INT NOT NULL,
  data_ingresso DATE NOT NULL,
  data_conclusao_prevista DATE NOT NULL,
  CONSTRAINT fk_aluno_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_aluno_curso
    FOREIGN KEY (cod_curso) REFERENCES curso(cod_curso)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE professor (
  id_usuario INT PRIMARY KEY,
  mat_siape VARCHAR(30) NOT NULL UNIQUE,
  regime_trabalho ENUM('20H','40H','DE') NOT NULL,
  cod_curso INT NOT NULL,
  data_contratacao DATE NOT NULL,
  CONSTRAINT fk_prof_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_prof_curso
    FOREIGN KEY (cod_curso) REFERENCES curso(cod_curso)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE funcionario (
  id_usuario INT PRIMARY KEY,
  matricula_func VARCHAR(30) NOT NULL UNIQUE,
  CONSTRAINT fk_func_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
    ON DELETE CASCADE ON UPDATE CASCADE
);

-- trigger: ao cadastrar aluno, impedir se data_conclusao_prevista já foi atingida
DELIMITER $$
CREATE TRIGGER trg_bloqueia_aluno_formado
BEFORE INSERT ON aluno
FOR EACH ROW
BEGIN
  IF NEW.data_conclusao_prevista <= CURDATE() THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Cadastro de aluno não permitido: data_de_conclusão_prevista já foi atingida.';
  END IF;
END$$
DELIMITER ;

-- =========================
-- 4) Parâmetros por tipo (prazo, limite, multa)
-- =========================
CREATE TABLE tipo_politica (
  tipo ENUM('ALUNO','PROFESSOR','FUNCIONARIO') PRIMARY KEY,
  max_livros INT NOT NULL,
  prazo_dias INT NOT NULL,
  multa_dia DECIMAL(10,2) NOT NULL
);

INSERT INTO tipo_politica (tipo, max_livros, prazo_dias, multa_dia) VALUES
('ALUNO', 3, 15, 1.00),
('FUNCIONARIO', 4, 21, 1.50),
('PROFESSOR', 5, 30, 2.00);

-- =========================
-- 5) Reservas
-- =========================
CREATE TABLE reserva (
  id_reserva INT AUTO_INCREMENT PRIMARY KEY,
  id_usuario INT NOT NULL,
  isbn VARCHAR(20) NOT NULL,
  data_reserva DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status_reserva ENUM('ATIVA','CANCELADA','ATENDIDA') NOT NULL DEFAULT 'ATIVA',

  CONSTRAINT fk_reserva_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_reserva_livro
    FOREIGN KEY (isbn) REFERENCES livro(isbn)
    ON DELETE CASCADE ON UPDATE CASCADE
);

-- impedir reserva se usuário estiver inativo
DELIMITER $$
CREATE TRIGGER trg_reserva_usuario_ativo
BEFORE INSERT ON reserva
FOR EACH ROW
BEGIN
  IF NOT EXISTS (SELECT 1 FROM usuario u WHERE u.id_usuario = NEW.id_usuario AND u.ativo = 1) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Usuário inativo não pode fazer reservas.';
  END IF;
END$$
DELIMITER ;

-- =========================
-- 6) Empréstimos e devolução com multa
-- =========================
CREATE TABLE emprestimo (
  id_emprestimo INT AUTO_INCREMENT PRIMARY KEY,
  id_usuario_responsavel INT NOT NULL,
  data_inicio DATE NOT NULL DEFAULT (CURRENT_DATE),
  data_prevista DATE NOT NULL,

> Ádrian,:
status_emprestimo ENUM('ABERTO','FECHADO') NOT NULL DEFAULT 'ABERTO',

  CONSTRAINT fk_emp_usuario
    FOREIGN KEY (id_usuario_responsavel) REFERENCES usuario(id_usuario)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE emprestimo_item (
  id_emprestimo INT NOT NULL,
  isbn VARCHAR(20) NOT NULL,
  num_exemplar INT NOT NULL,
  data_devolucao_real DATE NULL,
  multa_valor DECIMAL(10,2) NOT NULL DEFAULT 0.00,

  PRIMARY KEY (id_emprestimo, isbn, num_exemplar),

  CONSTRAINT fk_item_emp
    FOREIGN KEY (id_emprestimo) REFERENCES emprestimo(id_emprestimo)
    ON DELETE CASCADE ON UPDATE CASCADE,

  CONSTRAINT fk_item_exemplar
    FOREIGN KEY (isbn, num_exemplar) REFERENCES exemplar(isbn, num_exemplar)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Regras:
-- (a) usuário precisa estar ativo pra emprestar
-- (b) respeitar limite max_livros por tipo (considerando itens em empréstimos ABERTOS)
DELIMITER $$
CREATE TRIGGER trg_valida_emprestimo_usuario_limite
BEFORE INSERT ON emprestimo
FOR EACH ROW
BEGIN
  DECLARE v_tipo ENUM('ALUNO','PROFESSOR','FUNCIONARIO');
  DECLARE v_max INT;
  DECLARE v_em_aberto INT;

  SELECT tipo INTO v_tipo
  FROM usuario
  WHERE id_usuario = NEW.id_usuario_responsavel;

  IF v_tipo IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuário responsável inválido.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM usuario u
    WHERE u.id_usuario = NEW.id_usuario_responsavel AND u.ativo = 1
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuário inativo não pode realizar empréstimos.';
  END IF;

  SELECT max_livros INTO v_max
  FROM tipo_politica
  WHERE tipo = v_tipo;

  SELECT COUNT(*) INTO v_em_aberto
  FROM emprestimo e
  JOIN emprestimo_item ei ON ei.id_emprestimo = e.id_emprestimo
  WHERE e.id_usuario_responsavel = NEW.id_usuario_responsavel
    AND e.status_emprestimo = 'ABERTO'
    AND ei.data_devolucao_real IS NULL;

  -- O empréstimo pode ter vários itens; o limite final é checado quando inserir itens.
  -- Aqui só garantimos que existe política e usuário ativo.
END$$
DELIMITER ;

-- Ao inserir item no empréstimo: checa limite e disponibilidade do exemplar
DELIMITER $$
CREATE TRIGGER trg_valida_item_emprestimo
BEFORE INSERT ON emprestimo_item
FOR EACH ROW
BEGIN
  DECLARE v_usuario INT;
  DECLARE v_tipo ENUM('ALUNO','PROFESSOR','FUNCIONARIO');
  DECLARE v_max INT;
  DECLARE v_em_aberto INT;
  DECLARE v_status_exemplar ENUM('DISPONIVEL','EMPRESTADO','RESERVADO','INATIVO');

  SELECT id_usuario_responsavel INTO v_usuario
  FROM emprestimo
  WHERE id_emprestimo = NEW.id_emprestimo;

  IF v_usuario IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Empréstimo inexistente.';
  END IF;

  SELECT tipo INTO v_tipo FROM usuario WHERE id_usuario = v_usuario;
  SELECT max_livros INTO v_max FROM tipo_politica WHERE tipo = v_tipo;

  SELECT COUNT(*) INTO v_em_aberto
  FROM emprestimo e
  JOIN emprestimo_item ei ON ei.id_emprestimo = e.id_emprestimo
  WHERE e.id_usuario_responsavel = v_usuario
    AND e.status_emprestimo = 'ABERTO'
    AND ei.data_devolucao_real IS NULL;

  IF (v_em_aberto + 1) > v_max THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Limite máximo de livros emprestados para o tipo de usuário foi atingido.';
  END IF;

  SELECT status_exemplar INTO v_status_exemplar
  FROM exemplar
  WHERE isbn = NEW.isbn AND num_exemplar = NEW.num_exemplar;

  IF v_status_exemplar <> 'DISPONIVEL' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Exemplar não está disponível para empréstimo.';
  END IF;
END$$
DELIMITER ;

-- Ao inserir item: marca exemplar como EMPRESTADO
DELIMITER $$
CREATE TRIGGER trg_marca_exemplar_emprestado
AFTER INSERT ON emprestimo_item
FOR EACH ROW
BEGIN
  UPDATE exemplar
  SET status_exemplar = 'EMPRESTADO'
  WHERE isbn = NEW.isbn AND num_exemplar = NEW.num_exemplar;
END$$
DELIMITER ;

-- Ao dar baixa (update data_devolucao_real): calcula multa e libera exemplar
DELIMITER $$
CREATE TRIGGER trg_calcula_multa_e_libera
BEFORE UPDATE ON emprestimo_item
FOR EACH ROW
BEGIN
  DECLARE v_prevista DATE;
  DECLARE v_usuario INT;

> Ádrian,:
DECLARE v_tipo ENUM('ALUNO','PROFESSOR','FUNCIONARIO');
  DECLARE v_taxa DECIMAL(10,2);
  DECLARE v_atraso INT;

  IF NEW.data_devolucao_real IS NOT NULL AND OLD.data_devolucao_real IS NULL THEN

    SELECT e.data_prevista, e.id_usuario_responsavel
      INTO v_prevista, v_usuario
    FROM emprestimo e
    WHERE e.id_emprestimo = NEW.id_emprestimo;

    SELECT u.tipo INTO v_tipo FROM usuario u WHERE u.id_usuario = v_usuario;
    SELECT multa_dia INTO v_taxa FROM tipo_politica WHERE tipo = v_tipo;

    SET v_atraso = DATEDIFF(NEW.data_devolucao_real, v_prevista);

    IF v_atraso > 0 THEN
      SET NEW.multa_valor = v_atraso * v_taxa;
    ELSE
      SET NEW.multa_valor = 0.00;
    END IF;

  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_libera_exemplar
AFTER UPDATE ON emprestimo_item
FOR EACH ROW
BEGIN
  IF NEW.data_devolucao_real IS NOT NULL AND OLD.data_devolucao_real IS NULL THEN
    UPDATE exemplar
    SET status_exemplar = 'DISPONIVEL'
    WHERE isbn = NEW.isbn AND num_exemplar = NEW.num_exemplar;
  END IF;
END$$
DELIMITER ;

-- (Opcional) Fechar empréstimo automaticamente quando todos os itens forem devolvidos
DELIMITER $$
CREATE TRIGGER trg_fecha_emprestimo
AFTER UPDATE ON emprestimo_item
FOR EACH ROW
BEGIN
  DECLARE v_pendentes INT;
  IF NEW.data_devolucao_real IS NOT NULL AND OLD.data_devolucao_real IS NULL THEN
    SELECT COUNT(*) INTO v_pendentes
    FROM emprestimo_item
    WHERE id_emprestimo = NEW.id_emprestimo
      AND data_devolucao_real IS NULL;

    IF v_pendentes = 0 THEN
      UPDATE emprestimo
      SET status_emprestimo = 'FECHADO'
      WHERE id_emprestimo = NEW.id_emprestimo;
    END IF;
  END IF;
END$$
DELIMITER ;

-- =========================
-- 7) Visões (lists pedidas)
-- =========================

-- Livros por categoria (com autores agrupados)
CREATE VIEW vw_livros_por_categoria AS
SELECT
  c.cod_categoria,
  c.descricao AS categoria,
  l.isbn,
  l.titulo,
  l.editora,
  l.ano_lancamento,
  GROUP_CONCAT(a.nome ORDER BY a.nome SEPARATOR ', ') AS autores
FROM livro l
JOIN categoria c ON c.cod_categoria = l.cod_categoria
LEFT JOIN livro_autor la ON la.isbn = l.isbn
LEFT JOIN autor a ON a.id_autor = la.id_autor
GROUP BY c.cod_categoria, c.descricao, l.isbn, l.titulo, l.editora, l.ano_lancamento;

CREATE VIEW vw_livros_por_subcategoria AS
SELECT
  sc.cod_subcategoria,
  sc.descricao AS subcategoria,
  c.descricao AS categoria,
  l.isbn,
  l.titulo,
  l.editora,
  l.ano_lancamento
FROM livro l
JOIN subcategoria sc ON sc.cod_subcategoria = l.cod_subcategoria
JOIN categoria c ON c.cod_categoria = sc.cod_categoria;

CREATE VIEW vw_livros_por_editora AS
SELECT
  l.editora,
  l.isbn,
  l.titulo,
  l.ano_lancamento,
  c.descricao AS categoria,
  sc.descricao AS subcategoria
FROM livro l
JOIN categoria c ON c.cod_categoria = l.cod_categoria
JOIN subcategoria sc ON sc.cod_subcategoria = l.cod_subcategoria;

CREATE VIEW vw_livros_por_ano AS
SELECT
  l.ano_lancamento,
  l.isbn,
  l.titulo,
  l.editora,
  c.descricao AS categoria
FROM livro l
JOIN categoria c ON c.cod_categoria = l.cod_categoria;

CREATE VIEW vw_livros_por_autor AS
SELECT
  a.id_autor,
  a.nome AS autor,
  l.isbn,
  l.titulo,
  l.editora,
  l.ano_lancamento,
  la.principal
FROM autor a
JOIN livro_autor la ON la.id_autor = a.id_autor
JOIN livro l ON l.isbn = la.isbn;

-- Professores por curso
CREATE VIEW vw_professores_por_curso AS
SELECT
  c.cod_curso,
  c.nome_curso,
  p.mat_siape,
  u.nome,
  p.regime_trabalho,
  p.data_contratacao
FROM professor p
JOIN usuario u ON u.id_usuario = p.id_usuario
JOIN curso c ON c.cod_curso = p.cod_curso;

-- Reservas por livro (consultável por ISBN/título via WHERE na aplicação)
CREATE VIEW vw_reservas_por_livro AS
SELECT
  r.isbn,
  l.titulo,
  r.data_reserva,
  r.status_reserva,
  u.id_usuario,
  u.nome AS usuario
FROM reserva r
JOIN livro l ON l.isbn = r.isbn
JOIN usuario u ON u.id_usuario = r.id_usuario;
