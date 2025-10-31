CREATE TABLE industries (
    industry_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE employment_types (
    type_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE education_levels (
    level_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE locations (
    location_id SERIAL PRIMARY KEY,
    country VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL
);

CREATE TABLE skills (
    skill_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(100)
);

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role VARCHAR(20) CHECK (role IN ('candidate', 'employer', 'admin')) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE companies (
    company_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    industry_id INTEGER REFERENCES industries(industry_id),
    size VARCHAR(20) CHECK (size IN ('1-10', '11-50', '51-200', '201-500', '501-1000', '1000+')),
    website VARCHAR(255),
    logo_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE candidates (
    candidate_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    photo_url TEXT,
    birth_date DATE,
    desired_position VARCHAR(255),
    desired_salary INTEGER,
    employment_type_id INTEGER REFERENCES employment_types(type_id),
    location_id INTEGER REFERENCES locations(location_id),
    about TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE employers (
    employer_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    position VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE vacancies (
    vacancy_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    position VARCHAR(255) NOT NULL,
    description TEXT,
    requirements TEXT,
    responsibilities TEXT,
    conditions TEXT,
    salary_from INTEGER,
    salary_to INTEGER,
    employment_type_id INTEGER REFERENCES employment_types(type_id),
    location_id INTEGER REFERENCES locations(location_id),
    status VARCHAR(20) CHECK (status IN ('draft', 'published', 'closed')) DEFAULT 'draft',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE education (
    education_id SERIAL PRIMARY KEY,
    candidate_id INTEGER NOT NULL REFERENCES candidates(candidate_id) ON DELETE CASCADE,
    institution VARCHAR(255) NOT NULL,
    degree_id INTEGER REFERENCES education_levels(level_id),
    field_of_study VARCHAR(255),
    start_date DATE,
    end_date DATE,
    description TEXT
);

CREATE TABLE experience (
    experience_id SERIAL PRIMARY KEY,
    candidate_id INTEGER NOT NULL REFERENCES candidates(candidate_id) ON DELETE CASCADE,
    company VARCHAR(255) NOT NULL,
    position VARCHAR(255) NOT NULL,
    start_date DATE,
    end_date DATE,
    current_job BOOLEAN DEFAULT FALSE,
    description TEXT,
    achievements TEXT
);

CREATE TABLE candidate_skills (
    candidate_skill_id SERIAL PRIMARY KEY,
    candidate_id INTEGER NOT NULL REFERENCES candidates(candidate_id) ON DELETE CASCADE,
    skill_id INTEGER NOT NULL REFERENCES skills(skill_id) ON DELETE CASCADE,
    level VARCHAR(20) CHECK (level IN ('beginner', 'intermediate', 'advanced', 'expert')),
    UNIQUE(candidate_id, skill_id)
);

CREATE TABLE vacancy_skills (
    vacancy_skill_id SERIAL PRIMARY KEY,
    vacancy_id INTEGER NOT NULL REFERENCES vacancies(vacancy_id) ON DELETE CASCADE,
    skill_id INTEGER NOT NULL REFERENCES skills(skill_id) ON DELETE CASCADE,
    requirement_level VARCHAR(20) CHECK (requirement_level IN ('required', 'preferred')),
    min_level VARCHAR(20) CHECK (min_level IN ('beginner', 'intermediate', 'advanced', 'expert')),
    UNIQUE(vacancy_id, skill_id)
);

CREATE TABLE applications (
    application_id SERIAL PRIMARY KEY,
    candidate_id INTEGER NOT NULL REFERENCES candidates(candidate_id) ON DELETE CASCADE,
    vacancy_id INTEGER NOT NULL REFERENCES vacancies(vacancy_id) ON DELETE CASCADE,
    cover_letter TEXT,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) CHECK (status IN ('pending', 'reviewed', 'rejected', 'accepted')) DEFAULT 'pending',
    match_score INTEGER,
    UNIQUE(candidate_id, vacancy_id)
);

CREATE TABLE stages (
    stage_id SERIAL PRIMARY KEY,
    application_id INTEGER NOT NULL REFERENCES applications(application_id) ON DELETE CASCADE,
    stage_type VARCHAR(50) CHECK (stage_type IN ('phone_screen', 'technical_interview', 'hr_interview', 'test_task', 'offer')),
    scheduled_at TIMESTAMP,
    completed_at TIMESTAMP,
    result VARCHAR(20) CHECK (result IN ('passed', 'failed', 'cancelled')),
    notes TEXT,
    interviewer_id INTEGER REFERENCES employers(employer_id)
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_candidates_user_id ON candidates(user_id);
CREATE INDEX idx_candidates_location ON candidates(location_id);
CREATE INDEX idx_vacancies_company_status ON vacancies(company_id, status);
CREATE INDEX idx_vacancies_location ON vacancies(location_id);
CREATE INDEX idx_vacancies_employment_type ON vacancies(employment_type_id);
CREATE INDEX idx_vacancies_salary ON vacancies(salary_from, salary_to);
CREATE INDEX idx_applications_vacancy_status ON applications(vacancy_id, status);
CREATE INDEX idx_applications_candidate_date ON applications(candidate_id, applied_at);
CREATE INDEX idx_candidate_skills_skill_level ON candidate_skills(skill_id, level);
CREATE INDEX idx_vacancy_skills_skill ON vacancy_skills(skill_id);



--*******************************

--get-vacations (with filters)
SELECT 
    v.vacancy_id,
    v.position,
    c.name as company_name,
    v.salary_from,
    v.salary_to,
    et.name as employment_type,
    l.city,
    l.country,
    STRING_AGG(s.name, ', ') as required_skills
FROM vacancies v
JOIN companies c ON v.company_id = c.company_id
LEFT JOIN employment_types et ON v.employment_type_id = et.type_id
LEFT JOIN locations l ON v.location_id = l.location_id
LEFT JOIN vacancy_skills vs ON v.vacancy_id = vs.vacancy_id
LEFT JOIN skills s ON vs.skill_id = s.skill_id
WHERE v.status = 'published'
    AND (v.position ILIKE '%developer%' OR v.description ILIKE '%developer%')
    AND v.salary_from >= 50000
    AND et.name = 'full-time'
    AND l.city = 'Moscow'
GROUP BY v.vacancy_id, c.name, et.name, l.city, l.country
ORDER BY v.created_at DESC;


--get-candidates
SELECT 
    cand.candidate_id,
    cand.first_name,
    cand.last_name,
    cand.desired_position,
    cand.desired_salary,
    STRING_AGG(DISTINCT s.name || ' (' || cs.level || ')', ', ') as skills,
    COUNT(DISTINCT cs.skill_id) as skills_count
FROM candidates cand
JOIN candidate_skills cs ON cand.candidate_id = cs.candidate_id
JOIN skills s ON cs.skill_id = s.skill_id
WHERE cs.skill_id IN (1, 5, 8)
    AND cs.level IN ('advanced', 'expert')
    AND cand.desired_salary <= 100000
GROUP BY cand.candidate_id
HAVING COUNT(DISTINCT cs.skill_id) >= 2
ORDER BY skills_count DESC;

---


