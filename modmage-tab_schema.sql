DROP TABLE experiment CASCADE;
DROP TABLE experiment_prop CASCADE;
DROP TABLE protocol CASCADE;
DROP TABLE applied_protocol CASCADE;
DROP TABLE experiment_applied_protocol CASCADE;
DROP TABLE data CASCADE;
DROP TABLE applied_protocol_data CASCADE;
DROP TABLE attribute CASCADE;
DROP TABLE protocol_attribute CASCADE;
DROP TABLE data_attribute CASCADE;

CREATE TABLE experiment (
  experiment_id SERIAL PRIMARY KEY,
  description TEXT
);

CREATE TABLE experiment_prop (
  experiment_prop_id SERIAL PRIMARY KEY,
  experiment_id INTEGER NOT NULL REFERENCES experiment(experiment_id) ON DELETE CASCADE,
  type_id INTEGER NOT NULL REFERENCES cvterm(cvterm_id),
  value TEXT,
  rank INTEGER NOT NULL DEFAULT 0,
  UNIQUE(experiment_id, type_id, rank)
);

CREATE TABLE protocol (
  protocol_id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL UNIQUE,
  description TEXT,
  dbxref_id INTEGER REFERENCES dbxref(dbxref_id) ON DELETE RESTRICT
);

CREATE TABLE applied_protocol (
  applied_protocol_id SERIAL PRIMARY KEY,
  protocol_id INTEGER NOT NULL REFERENCES protocol(protocol_id) ON DELETE CASCADE,
  UNIQUE(applied_protocol_id, protocol_id)
);

CREATE TABLE experiment_applied_protocol (
  experiment_applied_protocol_id SERIAL PRIMARY KEY,
  experiment_id INTEGER NOT NULL REFERENCES experiment(experiment_id) ON DELETE CASCADE,
  first_applied_protocol_id INTEGER NOT NULL REFERENCES applied_protocol(applied_protocol_id) ON DELETE CASCADE,
  UNIQUE(experiment_id, first_applied_protocol_id)
);

CREATE TABLE data (
  data_id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  heading VARCHAR(255) NOT NULL,
  value TEXT,
  type_id INTEGER REFERENCES cvterm(cvterm_id) ON DELETE RESTRICT,
  dbxref_id INTEGER REFERENCES dbxref(dbxref_id) ON DELETE RESTRICT
);

CREATE TABLE applied_protocol_data (
  applied_protocol_data_id SERIAL PRIMARY KEY,
  applied_protocol_id INTEGER NOT NULL REFERENCES applied_protocol(applied_protocol_id) ON DELETE CASCADE,
  data_id INTEGER NOT NULL REFERENCES data(data_id) ON DELETE CASCADE,
  direction CHAR(6) CHECK (direction IN ('input', 'output')) NOT NULL,
  UNIQUE(applied_protocol_id, data_id, direction)
);

CREATE TABLE attribute (
  attribute_id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  heading VARCHAR(255) NOT NULL,
  value TEXT,
  type_id INTEGER REFERENCES cvterm(cvterm_id) ON DELETE RESTRICT,
  dbxref_id INTEGER REFERENCES dbxref(dbxref_id) ON DELETE RESTRICT
);

CREATE TABLE protocol_attribute (
  protocol_attribute_id SERIAL PRIMARY KEY,
  protocol_id INTEGER NOT NULL REFERENCES protocol(protocol_id),
  attribute_id INTEGER NOT NULL REFERENCES attribute(attribute_id),
  UNIQUE(protocol_id, attribute_id)
);

CREATE TABLE data_attribute (
  data_attribute_id SERIAL PRIMARY KEY,
  data_id INTEGER NOT NULL REFERENCES data(data_id),
  attribute_id INTEGER NOT NULL REFERENCES attribute(attribute_id),
  UNIQUE(data_id, attribute_id)
);

