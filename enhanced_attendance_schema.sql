-- ================================
-- ENHANCED Attendance System Database Schema
-- Support for both RFID and Facial Recognition
-- ================================

-- Drop tables in reverse order of dependencies (for clean rebuilds)
DROP TABLE IF EXISTS face_attendance CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS schedule CASCADE;
DROP TABLE IF EXISTS teacher_sections CASCADE;
DROP TABLE IF EXISTS student_sections CASCADE;
DROP TABLE IF EXISTS classrooms CASCADE;
DROP TABLE IF EXISTS sections CASCADE;
DROP TABLE IF EXISTS face_encodings CASCADE;
DROP TABLE IF EXISTS persons CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ================================
-- 1. Persons (Students + Teachers)
-- ================================
CREATE TABLE persons (
    person_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    rfid_tag VARCHAR(100) UNIQUE,
    role VARCHAR(20) CHECK (role IN ('student', 'teacher')) NOT NULL,
    id_number VARCHAR(20) UNIQUE,
    password VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 2. Face Encodings (For Face Recognition)
-- ================================
CREATE TABLE face_encodings (
    encoding_id SERIAL PRIMARY KEY,
    person_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    face_descriptor JSONB NOT NULL,
    confidence_score FLOAT DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- ================================
-- 3. Users (For Authentication)
-- ================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) CHECK (role IN ('teacher','admin')) DEFAULT 'teacher',
    person_id INT REFERENCES persons(person_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 4. Sections
-- ================================
CREATE TABLE sections (
    section_id SERIAL PRIMARY KEY,
    section_name VARCHAR(50) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 5. Student → Section Mapping
-- ================================
CREATE TABLE student_sections (
    person_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    section_id INT REFERENCES sections(section_id) ON DELETE CASCADE,
    PRIMARY KEY (person_id, section_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 6. Teacher → Section Mapping
-- ================================
CREATE TABLE teacher_sections (
    person_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    section_id INT REFERENCES sections(section_id) ON DELETE CASCADE,
    PRIMARY KEY (person_id, section_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 7. Classrooms
-- ================================
CREATE TABLE classrooms (
    classroom_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) UNIQUE NOT NULL,
    location VARCHAR(100),
    capacity INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 8. Schedule (Flexible Timetable)
-- ================================
CREATE TABLE schedule (
    schedule_id SERIAL PRIMARY KEY,
    section_id INT REFERENCES sections(section_id) ON DELETE CASCADE,
    teacher_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    classroom_id INT REFERENCES classrooms(classroom_id) ON DELETE CASCADE,
    subject_name VARCHAR(100) NOT NULL,
    day_of_week VARCHAR(10) CHECK (day_of_week IN 
        ('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    meeting_type VARCHAR(20) CHECK (meeting_type IN ('physical', 'online', 'hybrid')) DEFAULT 'online',
    meeting_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 9. RFID/NFC Attendance (Original System)
-- ================================
CREATE TABLE attendance (
    attendance_id SERIAL PRIMARY KEY,
    schedule_id INT REFERENCES schedule(schedule_id) ON DELETE CASCADE,
    person_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    rfid_tag VARCHAR(100),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(10) CHECK (status IN ('present', 'absent')) DEFAULT 'present',
    attendance_type VARCHAR(10) CHECK (attendance_type IN ('rfid', 'nfc', 'manual')) DEFAULT 'rfid',
    UNIQUE (schedule_id, person_id, DATE(timestamp))
);

-- ================================
-- 10. Face Recognition Attendance (New System)
-- ================================
CREATE TABLE face_attendance (
    face_attendance_id SERIAL PRIMARY KEY,
    schedule_id INT REFERENCES schedule(schedule_id) ON DELETE CASCADE,
    person_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    session_id VARCHAR(100) NOT NULL,
    detection_count INT DEFAULT 0,
    total_captures INT DEFAULT 5,
    confidence_avg FLOAT DEFAULT 0.0,
    first_detection TIMESTAMP,
    last_detection TIMESTAMP,
    status VARCHAR(10) CHECK (status IN ('present', 'absent', 'partial')) DEFAULT 'absent',
    meeting_duration_minutes INT DEFAULT 50,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (schedule_id, person_id, session_id)
);

-- ================================
-- 11. Face Detection Logs (Detailed tracking)
-- ================================
CREATE TABLE face_detection_logs (
    log_id SERIAL PRIMARY KEY,
    face_attendance_id INT REFERENCES face_attendance(face_attendance_id) ON DELETE CASCADE,
    person_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    detection_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    confidence_score FLOAT NOT NULL,
    bounding_box JSONB,
    session_minute INT,
    capture_number INT
);

-- ================================
-- Add indexes for better performance
-- ================================
CREATE INDEX idx_persons_rfid_tag ON persons(rfid_tag);
CREATE INDEX idx_persons_id_number ON persons(id_number);
CREATE INDEX idx_face_encodings_person_id ON face_encodings(person_id);
CREATE INDEX idx_face_encodings_active ON face_encodings(is_active);
CREATE INDEX idx_attendance_schedule_id ON attendance(schedule_id);
CREATE INDEX idx_attendance_person_id ON attendance(person_id);
CREATE INDEX idx_attendance_timestamp ON attendance(timestamp);
CREATE INDEX idx_face_attendance_schedule_id ON face_attendance(schedule_id);
CREATE INDEX idx_face_attendance_session_id ON face_attendance(session_id);
CREATE INDEX idx_face_attendance_person_id ON face_attendance(person_id);

-- ================================
-- Sample Data
-- ================================

-- Insert sample persons
INSERT INTO persons (name, rfid_tag, role, id_number, password) VALUES
('Nitin Singh', 'B2F7AF6A', 'student', '2500032073', '$2a$10$xqvlgnoqwdiIbauJrYUuC.aL34qhVoLaTeJ6yxqN6RMaLE0.FyCVK'),
('Abhijeet Arjeet', '717C423C', 'student', '2500031388', '$2a$10$Cl1HUEi42jS2R1NzRe9QVOSLF9Yg78fcUhPGa6sIm1pNwyOyaXev2'),
('Ayan Roy', '313F333D', 'student', '2500031529', '$2a$10$OIgEpa6yZ2.EpGywNklktuPBN6PRD53i5WA.7MB4yy3TM0A9yxHNS'),
('Dr. Teacher', 'TEACH001', 'teacher', 'T001', '$2a$10$iGjkALmc251rAC.B9GCCrez3cYD7xzhFYNP.bxiM2Uz7xKBtsNITy');

-- Insert sample users
INSERT INTO users (username, password, role, person_id) VALUES
('admin', '$2a$10$xqvlgnoqwdiIbauJrYUuC.aL34qhVoLaTeJ6yxqN6RMaLE0.FyCVK', 'admin', NULL),
('teacher', '$2a$10$iGjkALmc251rAC.B9GCCrez3cYD7xzhFYNP.bxiM2Uz7xKBtsNITy', 'teacher', 4),
('2500032073', '$2a$10$xqvlgnoqwdiIbauJrYUuC.aL34qhVoLaTeJ6yxqN6RMaLE0.FyCVK', 'teacher', 1);

-- Insert sections
INSERT INTO sections (section_name) VALUES
('S33'), ('S34'), ('S35'), ('S36'), ('S37'), ('S38');

-- Link students to sections
INSERT INTO student_sections (person_id, section_id) VALUES
(1, 1), (2, 1), (3, 1);

-- Link teacher to sections
INSERT INTO teacher_sections (person_id, section_id) VALUES
(4, 1), (4, 2), (1, 1);

-- Insert sample classrooms
INSERT INTO classrooms (room_number, location, capacity) VALUES
('Online Room 1', 'Zoom Platform', 50),
('Online Room 2', 'Teams Platform', 40),
('Lab 101', 'Computer Science Building', 30);

-- Insert sample schedule
INSERT INTO schedule (section_id, teacher_id, classroom_id, subject_name, day_of_week, start_time, end_time, meeting_type, meeting_url) VALUES
(1, 4, 1, 'Computer Science Fundamentals', 'Monday', '09:00:00', '09:50:00', 'online', 'https://zoom.us/j/123456789'),
(1, 4, 1, 'Data Structures', 'Wednesday', '10:00:00', '10:50:00', 'online', 'https://zoom.us/j/987654321'),
(2, 4, 2, 'Database Systems', 'Tuesday', '11:00:00', '11:50:00', 'online', 'https://teams.microsoft.com/meeting1');