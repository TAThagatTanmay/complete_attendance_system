DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS face_attendance CASCADE;
DROP TABLE IF EXISTS face_detection_logs CASCADE;
DROP TABLE IF EXISTS face_encodings CASCADE;
DROP TABLE IF EXISTS schedule CASCADE;
DROP TABLE IF EXISTS teacher_sections CASCADE;
DROP TABLE IF EXISTS student_sections CASCADE;
DROP TABLE IF EXISTS classrooms CASCADE;
DROP TABLE IF EXISTS sections CASCADE;
DROP TABLE IF EXISTS persons CASCADE;

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
    email VARCHAR(100),
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 2. Users (For Authentication)
-- ================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) CHECK (role IN ('teacher','admin','student')) DEFAULT 'teacher',
    person_id INT REFERENCES persons(person_id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 3. Face Encodings (For Face Recognition)
-- ================================
CREATE TABLE face_encodings (
    encoding_id SERIAL PRIMARY KEY,
    person_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    face_descriptor JSONB NOT NULL,
    confidence_score FLOAT DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    enrollment_method VARCHAR(20) DEFAULT 'manual',
    photo_url VARCHAR(255)
);

-- ================================
-- 4. Sections
-- ================================
CREATE TABLE sections (
    section_id SERIAL PRIMARY KEY,
    section_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    academic_year VARCHAR(20),
    semester VARCHAR(20),
    capacity INT DEFAULT 50,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 5. Student → Section Mapping
-- ================================
CREATE TABLE student_sections (
    person_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    section_id INT REFERENCES sections(section_id) ON DELETE CASCADE,
    enrollment_date DATE DEFAULT CURRENT_DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'transferred')),
    PRIMARY KEY (person_id, section_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 6. Teacher → Section Mapping
-- ================================
CREATE TABLE teacher_sections (
    person_id INT REFERENCES persons(person_id) ON DELETE CASCADE,
    section_id INT REFERENCES sections(section_id) ON DELETE CASCADE,
    assignment_date DATE DEFAULT CURRENT_DATE,
    is_primary BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (person_id, section_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- 7. Classrooms
-- ================================
CREATE TABLE classrooms (
    classroom_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) UNIQUE NOT NULL,
    building VARCHAR(50),
    location VARCHAR(100),
    capacity INT DEFAULT 0,
    equipment TEXT,
    is_online BOOLEAN DEFAULT FALSE,
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
    meeting_url VARCHAR(500),
    duration_minutes INT,
    is_recurring BOOLEAN DEFAULT TRUE,
    academic_year VARCHAR(20),
    semester VARCHAR(20),
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
    status VARCHAR(10) CHECK (status IN ('present', 'absent', 'late', 'excused')) DEFAULT 'present',
    attendance_type VARCHAR(10) CHECK (attendance_type IN ('rfid', 'nfc', 'manual', 'face')) DEFAULT 'rfid',
    notes TEXT,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    device_info VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
    confidence_min FLOAT DEFAULT 0.0,
    confidence_max FLOAT DEFAULT 0.0,
    first_detection TIMESTAMP,
    last_detection TIMESTAMP,
    status VARCHAR(10) CHECK (status IN ('present', 'absent', 'partial', 'uncertain')) DEFAULT 'absent',
    meeting_duration_minutes INT DEFAULT 50,
    video_source VARCHAR(20) CHECK (video_source IN ('webcam', 'screen', 'uploaded')) DEFAULT 'webcam',
    device_info VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
    face_landmarks JSONB,
    session_minute INT,
    capture_number INT,
    video_frame_time FLOAT,
    detection_method VARCHAR(20) DEFAULT 'live',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================
-- Add Indexes for Better Performance
-- ================================

-- Persons indexes
CREATE INDEX idx_persons_rfid_tag ON persons(rfid_tag);
CREATE INDEX idx_persons_id_number ON persons(id_number);
CREATE INDEX idx_persons_role ON persons(role);

-- Users indexes
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_person_id ON users(person_id);

-- Face encodings indexes
CREATE INDEX idx_face_encodings_person_id ON face_encodings(person_id);
CREATE INDEX idx_face_encodings_active ON face_encodings(is_active);

-- Schedule indexes
CREATE INDEX idx_schedule_section_id ON schedule(section_id);
CREATE INDEX idx_schedule_teacher_id ON schedule(teacher_id);
CREATE INDEX idx_schedule_day_time ON schedule(day_of_week, start_time);

-- RFID Attendance indexes
CREATE INDEX idx_attendance_schedule_id ON attendance(schedule_id);
CREATE INDEX idx_attendance_person_id ON attendance(person_id);
CREATE INDEX idx_attendance_timestamp ON attendance(timestamp);
CREATE INDEX idx_attendance_date ON attendance((DATE(timestamp)));

-- Face Attendance indexes
CREATE INDEX idx_face_attendance_schedule_id ON face_attendance(schedule_id);
CREATE INDEX idx_face_attendance_session_id ON face_attendance(session_id);
CREATE INDEX idx_face_attendance_person_id ON face_attendance(person_id);
CREATE INDEX idx_face_attendance_status ON face_attendance(status);
CREATE INDEX idx_face_attendance_created_at ON face_attendance(created_at);

-- Face Detection Logs indexes
CREATE INDEX idx_face_detection_logs_face_attendance_id ON face_detection_logs(face_attendance_id);
CREATE INDEX idx_face_detection_logs_person_id ON face_detection_logs(person_id);
CREATE INDEX idx_face_detection_logs_timestamp ON face_detection_logs(detection_timestamp);

-- ================================
-- Add Unique Constraints (Using Indexes)
-- ================================

-- Ensure only one attendance record per student per day per schedule (RFID)
CREATE UNIQUE INDEX idx_attendance_unique_per_day
ON attendance (schedule_id, person_id, (DATE(timestamp)));

-- Ensure unique face attendance per session per student
CREATE UNIQUE INDEX idx_face_attendance_unique_session
ON face_attendance (schedule_id, person_id, session_id);

-- ================================
-- MINIMAL Sample Data (Core System Testing)
-- ================================

-- Insert core persons (reduced from original datasets)
INSERT INTO persons (name, rfid_tag, role, id_number, password, email) VALUES
('Nitin Singh', 'B2F7AF6A', 'student', '2500032073', '$2a$10$xqvlgnoqwdiIbauJrYUuC.aL34qhVoLaTeJ6yxqN6RMaLE0.FyCVK', '2500032073@kluniversity.in'),
('Abhijeet Arjeet', '717C423C', 'student', '2500031388', '$2a$10$Cl1HUEi42jS2R1NzRe9QVOSLF9Yg78fcUhPGa6sIm1pNwyOyaXev2', '2500031388@kluniversity.in'),
('Aryan Sharma', '313F333D', 'student', '2500031465', '$2a$10$OIgEpa6yZ2.EpGywNklktuPBN6PRD53i5WA.7MB4yy3TM0A9yxHNS', '2500031465@kluniversity.in'),
('Mahalakshmi', '11B8513C', 'student', '2500030810', '$2a$10$pqB6Od7bJYeLe6IG2pZzVuIkTdBFcxOkyQ2oMbrtnJhYCj85eVtjC', '2500030922@kluniversity.in'),
('Dr. Computer Teacher', 'TEACH001', 'teacher', 'T001', '$2a$10$iGjkALmc251rAC.B9GCCrez3cYD7xzhFYNP.bxiM2Uz7xKBtsNITy', 'teacher@kluniversity.in');

-- Insert users for authentication
INSERT INTO users (username, password, role, person_id) VALUES
('admin', '$2a$10$xqvlgnoqwdiIbauJrYUuC.aL34qhVoLaTeJ6yxqN6RMaLE0.FyCVK', 'admin', NULL),
('teacher', '$2a$10$iGjkALmc251rAC.B9GCCrez3cYD7xzhFYNP.bxiM2Uz7xKBtsNITy', 'teacher', 5),
('2500032073', '$2a$10$xqvlgnoqwdiIbauJrYUuC.aL34qhVoLaTeJ6yxqN6RMaLE0.FyCVK', 'student', 1);

-- Insert essential sections
INSERT INTO sections (section_name, description, academic_year, semester, capacity) VALUES
('S33', 'Computer Science Section 33', '2024-25', 'Fall', 30),
('S34', 'Computer Science Section 34', '2024-25', 'Fall', 30),
('S35', 'Data Science Section 35', '2024-25', 'Fall', 25);

-- Link students to sections
INSERT INTO student_sections (person_id, section_id) VALUES
(1, 1), (2, 1), (3, 1), (4, 1), -- S33
(1, 2), (2, 2); -- Some students in multiple sections

-- Link teachers to sections
INSERT INTO teacher_sections (person_id, section_id, is_primary) VALUES
(5, 1, TRUE), (5, 2, TRUE), (5, 3, FALSE); -- Teacher for all sections

-- Insert essential classrooms
INSERT INTO classrooms (room_number, building, location, capacity, is_online) VALUES
('Online Room 1', 'Virtual', 'Zoom Platform', 50, TRUE),
('Lab 101', 'CS Building', 'Computer Science Building Floor 1', 30, FALSE),
('Lecture Hall A', 'Main Building', 'Main Academic Building Floor 2', 80, FALSE);

-- Insert core schedule
INSERT INTO schedule (section_id, teacher_id, classroom_id, subject_name, day_of_week, start_time, end_time, meeting_type, meeting_url, duration_minutes, academic_year, semester) VALUES
(1, 5, 1, 'Computer Science Fundamentals', 'Monday', '09:00:00', '09:50:00', 'online', 'https://zoom.us/j/123456789', 50, '2024-25', 'Fall'),
(1, 5, 2, 'Programming Lab', 'Friday', '14:00:00', '15:50:00', 'physical', NULL, 110, '2024-25', 'Fall'),
(2, 5, 1, 'Database Management Systems', 'Tuesday', '11:00:00', '11:50:00', 'online', 'https://zoom.us/j/987654321', 50, '2024-25', 'Fall');

-- Insert minimal face encodings (only for first two students)
INSERT INTO face_encodings (person_id, face_descriptor, confidence_score, enrollment_method) VALUES
(1, '[-0.16486585140228271, 0.057039935141801834, 0.0317169651389122, -0.06053433567285538, -0.06996824592351913, -0.11818995326757431, 0.019278310239315033, -0.11030413955450058, 0.22233353555202484, -0.12788806855678558]', 0.8837114900997568, 'manual'),
(2, '[-0.11347576975822449, 0.08831794559955597, 0.0430089496076107, -0.07151175290346146, -0.08615626394748688, -0.01381430123001337, 0.004693902097642422, -0.053863562643527985, 0.21785472333431244, -0.12253648787736893]', 0.9503277483981866, 'manual');

-- Success message
SELECT 'Merged Attendance System Database Schema Created Successfully!' as status,
'✓ RFID/NFC attendance system (original)' as feature_1,
'✓ Face recognition attendance system (experimental)' as feature_2,
'✓ Unified authentication and user management' as feature_3,
'✓ Backward compatibility maintained' as compatibility,
'✓ Sample data cleaned and minimized' as data_cleanup;