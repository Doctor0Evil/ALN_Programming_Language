-- Table: projects
CREATE TABLE projects (
    project_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    compliance_passed BOOLEAN DEFAULT FALSE,
    compliance_date TEXT,
    last_audit_ts TEXT,
    project_owner TEXT,
    notes TEXT
);

-- Table: compliance_checks
CREATE TABLE compliance_checks (
    check_id TEXT PRIMARY KEY,
    project_id TEXT,
    check_type TEXT,
    passed BOOLEAN,
    checked_by TEXT,
    checked_on TEXT,
    protocol_ref TEXT,
    details TEXT,
    FOREIGN KEY(project_id) REFERENCES projects(project_id)
);

-- Table: safety_protocols
CREATE TABLE safety_protocols (
    protocol_id TEXT PRIMARY KEY,
    protocol_name TEXT,
    protocol_type TEXT,
    description TEXT,
    activation_criteria TEXT,
    cryptographic_hash TEXT,
    last_evaluated TEXT
);

-- Table: sandbox_policy_matrix
CREATE TABLE sandbox_policy_matrix (
    matrix_id TEXT PRIMARY KEY,
    project_id TEXT,
    containment_level TEXT,
    allowed_operations TEXT,
    forbidden_operations TEXT,
    ai_override_permitted BOOLEAN,
    escalation_policy TEXT,
    notes TEXT,
    FOREIGN KEY(project_id) REFERENCES projects(project_id)
);

-- Table: audit_trail
CREATE TABLE audit_trail (
    audit_id TEXT PRIMARY KEY,
    project_id TEXT,
    event_type TEXT,
    event_desc TEXT,
    event_time TEXT,
    actor TEXT,
    authenticity_verified BOOLEAN,
    cryptographic_reference TEXT
);
