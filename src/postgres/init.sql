CREATE TABLE IF NOT EXISTS institutions (
  id INTEGER PRIMARY KEY ,
  name TEXT,
  address TEXT,
  phone TEXT,
  fax TEXT,
  email TEXT,
  internet TEXT
);

COPY institutions FROM '/dump_data/extracted_institution_data.csv' DELIMITER ',' CSV HEADER;
CREATE INDEX institutions_idx ON institutions (id);

CREATE TABLE IF NOT EXISTS peopleTemp (
  num INTEGER,
  id INTEGER NOT NULL,
  name TEXT,
  address TEXT,
  phone TEXT,
  fax TEXT,
  email TEXT,
  internet TEXT,
  institution_name TEXT,
  institution_id INTEGER REFERENCES institutions(id)
);

COPY peopleTemp FROM '/dump_data/people_joined_with_institutions.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE IF NOT EXISTS people (
  id INTEGER PRIMARY KEY ,
  name TEXT NOT NULL
);

INSERT INTO people (id, name)
SELECT DISTINCT id, name
FROM peopleTemp;

CREATE INDEX people_idx ON people (id);

CREATE TABLE IF NOT EXISTS peopleInstitutions (
  people_id INTEGER REFERENCES people(id),
  address TEXT,
  phone TEXT,
  fax TEXT,
  email TEXT,
  internet TEXT,
  institution_name TEXT,
  institution_id INTEGER REFERENCES institutions(id)
);

INSERT INTO peopleInstitutions (people_id, address, phone, fax, email, internet, institution_name, institution_id)
SELECT DISTINCT id, address, phone, fax, email, internet, institution_name, institution_id
FROM peopleTemp;

DROP TABLE peopleTemp;

CREATE TABLE IF NOT EXISTS projects (
  id INTEGER PRIMARY KEY ,
  title TEXT,
  project_abstract TEXT,
  dfg_process TEXT,
  funding_start_year TEXT,
  funding_end_year TEXT,
  parent_project_id INTEGER REFERENCES projects(id),
  participating_subject_areas TEXT,
  description TEXT
);

COPY projects FROM '/dump_data/extracted_project_data.csv' DELIMITER ',' CSV HEADER;
CREATE INDEX projects_idx ON projects (id);

CREATE TABLE IF NOT EXISTS subjects (
  subject_area TEXT PRIMARY KEY ,
  review_board TEXT NOT NULL,
  research_area TEXT NOT NULL
);

COPY subjects FROM '/dump_data/subject_areas.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE IF NOT EXISTS countryCodes (
  country TEXT PRIMARY KEY,
  code TEXT NOT NULL
);

COPY countryCodes FROM '/dump_data/country_code.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE IF NOT EXISTS projectsCountries (
  project_id INTEGER REFERENCES projects(id),
  country TEXT REFERENCES countryCodes(country)
);

COPY projectsCountries FROM '/dump_data/projects_international_connections.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE IF NOT EXISTS projectsParticipatingSubjects (
  project_id INTEGER REFERENCES projects(id),
  subject TEXT NOT NULL
);

COPY projectsParticipatingSubjects FROM '/dump_data/project_ids_to_participating_subject_areas.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE IF NOT EXISTS projectsInstitutions (
  project_id INTEGER REFERENCES projects(id),
  institution_id INTEGER REFERENCES institutions(id),
  relation_type TEXT
);

COPY projectsInstitutions FROM '/dump_data/project_institution_relations.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE IF NOT EXISTS institutionsProjects (
  institution_id INTEGER REFERENCES institutions(id),
  project_id INTEGER REFERENCES projects(id)
);

COPY institutionsProjects FROM '/dump_data/projects_listed_on_institution_detail_pages.csv' DELIMITER ',' CSV HEADER;

INSERT INTO projectsInstitutions (project_id, institution_id, relation_type)
SELECT project_id, institution_id, 'UNKNOWN'
FROM institutionsProjects;

DROP TABLE institutionsProjects;

CREATE TABLE IF NOT EXISTS projectsPeople (
  project_id INTEGER REFERENCES projects(id),
  person_id INTEGER REFERENCES people(id),
  relation_type TEXT
);

COPY projectsPeople FROM '/dump_data/project_person_relations.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE IF NOT EXISTS projectsSubjects (
  project_id INTEGER REFERENCES projects(id),
  subject_area TEXT
);

COPY projectsSubjects FROM '/dump_data/project_ids_to_subject_areas.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE IF NOT EXISTS institutionsGeolocations (
  institution_id INTEGER REFERENCES institutions(id),
  lat FLOAT8,
  long FLOAT8
);

-- Create a function that always returns the first non-NULL item
CREATE OR REPLACE FUNCTION public.first_agg ( anyelement, anyelement )
RETURNS anyelement LANGUAGE SQL IMMUTABLE STRICT AS $$
        SELECT $1;
$$;
 
-- And then wrap an aggregate around it
CREATE AGGREGATE public.FIRST (
        sfunc    = public.first_agg,
        basetype = anyelement,
        stype    = anyelement
);
 
-- Create a function that always returns the last non-NULL item
CREATE OR REPLACE FUNCTION public.last_agg ( anyelement, anyelement )
RETURNS anyelement LANGUAGE SQL IMMUTABLE STRICT AS $$
        SELECT $2;
$$;
 
-- And then wrap an aggregate around it
CREATE AGGREGATE public.LAST (
        sfunc    = public.last_agg,
        basetype = anyelement,
        stype    = anyelement
);

CREATE MATERIALIZED VIEW project_view AS
    SELECT proj.id AS id,
    FIRST(projectsinstitutions.institution_id) AS institution_id,
    ARRAY_AGG(DISTINCT countryCode.code) AS region,
    ARRAY_AGG(DISTINCT peopleinstitutions.institution_id) AS cooperating_institutions,
    FIRST(subjects.subject_area) AS subject_area,
    FIRST(subjects.review_board) AS review_board,
    FIRST(subjects.research_area) AS research_area,
    'Anonym' AS applicant,
    'DFG' AS sponsor,
    ARRAY_AGG(DISTINCT p.subject) AS side_topics,
    'Anonym' AS project_leader,
    FIRST(proj.funding_start_year) AS start_date,
    FIRST(proj.funding_end_year) AS end_date,
    FIRST(proj.title) AS title,
    FIRST(proj.project_abstract) AS abstract,
    CONCAT('http://gepris.dfg.de/gepris/projekt/', proj.id) AS href,
    '1' AS synergy


  FROM projects AS proj

  -- Match the hosting institution to projects
  LEFT JOIN projectsinstitutions
  ON proj.id = projectsinstitutions.project_id

  -- Match the participatingsubject areas to projects
  LEFT JOIN projectsparticipatingsubjects p
  ON proj.id = p.project_id

  -- Match the country codes to projects
  LEFT JOIN projectsCountries AS countries
  ON proj.id = countries.project_id
  LEFT JOIN countryCodes AS countryCode
  ON countries.country = countryCode.country

  -- Match participating people to projects
  LEFT JOIN projectsPeople
  ON proj.id = projectsPeople.project_id
  LEFT JOIN people
  ON projectsPeople.person_id = people.id
  LEFT JOIN peopleinstitutions
  ON people.id = peopleinstitutions.people_id

  -- Match taxonomy
  LEFT JOIN projectsSubjects AS subj
  ON proj.id = subj.project_id
  LEFT JOIN subjects
  ON subj.subject_area = subjects.subject_area

  GROUP BY proj.id
  ORDER BY proj.id;

CREATE INDEX project_view_idx ON project_view (institution_id);



