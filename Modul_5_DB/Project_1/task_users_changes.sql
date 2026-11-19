-- ============================================
-- ЧАСТЬ 1. ТРЕНИРОВКА (не для сдачи)
-- ============================================

CREATE TABLE students (
    id SERIAL PRIMARY KEY,
    name TEXT,
    age INTEGER,
    city TEXT
);

CREATE TABLE students_audit (
    id SERIAL PRIMARY KEY,
    student_id INTEGER,
    field_changed TEXT,
    old_value TEXT,
    new_value TEXT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION log_student_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.name IS DISTINCT FROM NEW.name THEN
        INSERT INTO students_audit (student_id, field_changed, old_value, new_value)
        VALUES (NEW.id, 'name', OLD.name, NEW.name);
    END IF;
    IF OLD.city IS DISTINCT FROM NEW.city THEN
        INSERT INTO students_audit (student_id, field_changed, old_value, new_value)
        VALUES (NEW.id, 'city', OLD.city, NEW.city);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_log_student_change
AFTER UPDATE ON students
FOR EACH ROW
EXECUTE FUNCTION log_student_change();

-- ============================================
-- ЧАСТЬ 2. ТЗ (для сдачи)
-- ============================================

-- --------------------------------------------
-- Шаг 1. Таблицы
-- --------------------------------------------

DROP TABLE IF EXISTS users_history CASCADE;
DROP TABLE IF EXISTS users CASCADE;

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name TEXT,
    email TEXT,
    role TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE users_audit (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by TEXT,
    field_changed TEXT,
    old_value TEXT,
    new_value TEXT
);

CREATE OR REPLACE FUNCTION log_user_change()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. Проверяем name
    IF OLD.name IS DISTINCT FROM NEW.name THEN
        INSERT INTO users_audit (user_id, changed_by, field_changed, old_value, new_value)
        VALUES (NEW.id, current_user, 'name', OLD.name, NEW.name);
    END IF;

    -- 2. Проверяем email
    IF OLD.email IS DISTINCT FROM NEW.email THEN
        INSERT INTO users_audit (user_id, changed_by, field_changed, old_value, new_value)
        VALUES (NEW.id, current_user, 'email', OLD.email, NEW.email);
    END IF;

    -- 3. Проверяем role
    IF OLD.role IS DISTINCT FROM NEW.role THEN
        INSERT INTO users_audit (user_id, changed_by, field_changed, old_value, new_value)
        VALUES (NEW.id, current_user, 'role', OLD.role, NEW.role);
    END IF;

    -- 4. Обновляем updated_at
    NEW.updated_at := NOW();

    -- 5. Возвращаем строку
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;