-- ================================
-- COMPLETE Enhanced Attendance System Database Schema
-- Compatible with Render PostgreSQL
-- Support for both RFID and Facial Recognition
-- ================================

-- Drop tables in reverse order of dependencies (for clean rebuilds)
DROP TABLE IF EXISTS face_detection_logs CASCADE;
DROP TABLE IF EXISTS face_attendance CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS schedule CASCADE;
DROP TABLE IF EXISTS teacher_sections CASCADE;
DROP TABLE IF EXISTS student_sections CASCADE;
DROP TABLE IF EXISTS classrooms CASCADE;
DROP TABLE IF EXISTS sections CASCADE;
DROP TABLE IF EXISTS face_encodings CASCADE;
DROP TABLE IF EXISTS users CASCADE;
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
    attendance_type VARCHAR(10) CHECK (attendance_type IN ('rfid', 'nfc', 'manual', 'qr')) DEFAULT 'rfid',
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
-- Sample Data
-- ================================

-- Insert sample persons (Students and Teachers)
INSERT INTO persons (name, rfid_tag, role, id_number, password, email) VALUES
('Nitin Singh', 'B2F7AF6A', 'student', '2500032073', '$2a$10$xqvlgnoqwdiIbauJrYUuC.aL34qhVoLaTeJ6yxqN6RMaLE0.FyCVK', 'nitin@student.edu'),
('Abhijeet Arjeet', '717C423C', 'student', '2500031388', '$2a$10$Cl1HUEi42jS2R1NzRe9QVOSLF9Yg78fcUhPGa6sIm1pNwyOyaXev2', 'abhijeet@student.edu'),
('Ayan Roy', '313F333D', 'student', '2500031529', '$2a$10$OIgEpa6yZ2.EpGywNklktuPBN6PRD53i5WA.7MB4yy3TM0A9yxHNS', 'ayan@student.edu'),
('Pushkar Roy', 'B16C3A3D', 'student', '2500030922', '$2a$10$Rk3uD8v5i8vKiK3AitTRX.3Lz7G4Yh5QlGT7gK8Nq4LZqJ9aF6Nh2', 'pushkar@student.edu'),
('Raunak Gupta', '315F7C3C', 'student', '2500031322', '$2a$10$Tk9sL4vKhJl3mKpOiYu7R.8Gf2V5Xk6Pl9Zc3NdMs8aF7Qr4Er5Wt', 'raunak@student.edu'),
('Aman Raj', 'D171283C', 'student', '2500030448', '$2a$10$Vl7kF2vNdJm4oQsLj9w8T.6Hy8J3Zx5Qo2aB6Mn7gF4Kp1Er9Tv3Yu', 'aman@student.edu'),
('Prateek Lohiya', '71A2463C', 'student', '2500032264', '$2a$10$Xp6kG1vFhKl2qUsOm8x4V.4Iz5L7Zy2Rp8cD4No3hG6Mp7Fr5Vx8Zw', 'prateek@student.edu'),
('Divyanshu Goyal', 'C1A82F3C', 'student', '2500031363', '$2a$10$Yq4jH8vGiNm6rVtPn7y9X.2Jw3M9Az6Sq7dE8Op4iH5Nq6Gs8Wy7Av', 'divyanshu@student.edu'),
('Ayush Kumar', '41F5263C', 'student', '2500032102', '$2a$10$Zr2kJ5vHjOo4sXuQo9z6Y.8Kx7N4Ba2Tr5eF3Pq9jI7Or4Ht6Vz5Bx', 'ayush@student.edu'),
('Dr. Computer Teacher', 'TEACH001', 'teacher', 'T001', '$2a$10$iGjkALmc251rAC.B9GCCrez3cYD7xzhFYNP.bxiM2Uz7xKBtsNITy', 'teacher@college.edu'),
('Prof. Data Science', 'TEACH002', 'teacher', 'T002', '$2a$10$kHlmBNod362sAD.C8HDDsfz4dYE8yaiGZOP.cyiN3Vz8yLCtsOJUz', 'datascience@college.edu');

-- Insert users for authentication
INSERT INTO users (username, password, role, person_id) VALUES
('admin', '$2a$10$xqvlgnoqwdiIbauJrYUuC.aL34qhVoLaTeJ6yxqN6RMaLE0.FyCVK', 'admin', NULL),
('teacher', '$2a$10$iGjkALmc251rAC.B9GCCrez3cYD7xzhFYNP.bxiM2Uz7xKBtsNITy', 'teacher', 10),
('2500032073', '$2a$10$xqvlgnoqwdiIbauJrYUuC.aL34qhVoLaTeJ6yxqN6RMaLE0.FyCVK', 'student', 1),
('datascience', '$2a$10$kHlmBNod362sAD.C8HDDsfz4dYE8yaiGZOP.cyiN3Vz8yLCtsOJUz', 'teacher', 11);

-- Insert sections
INSERT INTO sections (section_name, description, academic_year, semester, capacity) VALUES
('S33', 'Computer Science Section 33', '2024-25', 'Fall', 30),
('S34', 'Computer Science Section 34', '2024-25', 'Fall', 30),
('S35', 'Computer Science Section 35', '2024-25', 'Fall', 30),
('S36', 'Data Science Section 36', '2024-25', 'Fall', 25),
('S37', 'Information Technology Section 37', '2024-25', 'Fall', 35),
('S38', 'Software Engineering Section 38', '2024-25', 'Fall', 28);

-- Link students to sections
INSERT INTO student_sections (person_id, section_id) VALUES
(1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (8, 1), (9, 1), -- S33
(1, 2), (2, 2), -- Some students in multiple sections
(4, 4), (5, 4), (6, 4); -- Some students in Data Science section

-- Link teachers to sections
INSERT INTO teacher_sections (person_id, section_id, is_primary) VALUES
(10, 1, TRUE), (10, 2, TRUE), (10, 3, FALSE), -- Computer Teacher for S33, S34, S35
(11, 4, TRUE), (11, 5, FALSE), -- Data Science Teacher for S36, S37
(1, 1, FALSE); -- Student as TA

-- Insert sample classrooms
INSERT INTO classrooms (room_number, building, location, capacity, is_online) VALUES
('Online Room 1', 'Virtual', 'Zoom Platform', 50, TRUE),
('Online Room 2', 'Virtual', 'Teams Platform', 40, TRUE),
('Online Room 3', 'Virtual', 'Meet Platform', 35, TRUE),
('Lab 101', 'CS Building', 'Computer Science Building Floor 1', 30, FALSE),
('Lab 102', 'CS Building', 'Computer Science Building Floor 1', 25, FALSE),
('Lecture Hall A', 'Main Building', 'Main Academic Building Floor 2', 80, FALSE),
('Seminar Room 201', 'CS Building', 'Computer Science Building Floor 2', 20, FALSE);

-- Insert sample schedule
INSERT INTO schedule (section_id, teacher_id, classroom_id, subject_name, day_of_week, start_time, end_time, meeting_type, meeting_url, duration_minutes, academic_year, semester) VALUES
(1, 10, 1, 'Computer Science Fundamentals', 'Monday', '09:00:00', '09:50:00', 'online', 'https://zoom.us/j/123456789', 50, '2024-25', 'Fall'),
(1, 10, 1, 'Data Structures and Algorithms', 'Wednesday', '10:00:00', '10:50:00', 'online', 'https://zoom.us/j/987654321', 50, '2024-25', 'Fall'),
(1, 10, 4, 'Programming Lab', 'Friday', '14:00:00', '15:50:00', 'physical', NULL, 110, '2024-25', 'Fall'),
(2, 10, 2, 'Database Management Systems', 'Tuesday', '11:00:00', '11:50:00', 'online', 'https://teams.microsoft.com/meeting1', 50, '2024-25', 'Fall'),
(4, 11, 3, 'Machine Learning', 'Thursday', '15:00:00', '15:50:00', 'online', 'https://meet.google.com/abc-defg-hij', 50, '2024-25', 'Fall'),
(4, 11, 5, 'Data Analytics Lab', 'Saturday', '10:00:00', '11:50:00', 'physical', NULL, 110, '2024-25', 'Fall');

-- Insert sample RFID attendance records
INSERT INTO attendance (schedule_id, person_id, rfid_tag, timestamp, status, attendance_type) VALUES
(1, 1, 'B2F7AF6A', '2024-09-12 09:05:00', 'present', 'rfid'),
(1, 2, '717C423C', '2024-09-12 09:03:00', 'present', 'rfid'),
(1, 3, '313F333D', '2024-09-12 09:15:00', 'late', 'rfid'),
(2, 1, 'B2F7AF6A', '2024-09-11 11:02:00', 'present', 'rfid'),
(2, 2, '717C423C', '2024-09-11 11:08:00', 'present', 'rfid');

-- Insert sample face encodings (placeholder descriptors)
INSERT INTO face_encodings (person_id, face_descriptor, confidence_score, enrollment_method) VALUES
(1, '[-0.123, 0.456, -0.789, 0.234, -0.567, 0.891, -0.345, 0.678]', 0.95, 'webcam'),
(2, '[-0.234, 0.567, -0.891, 0.345, -0.678, 0.912, -0.456, 0.789]', 0.92, 'webcam'),
(3, '[-0.345, 0.678, -0.912, 0.456, -0.789, 0.123, -0.567, 0.891]', 0.89, 'uploaded'),
(4, '[-0.456, 0.789, -0.123, 0.567, -0.891, 0.234, -0.678, 0.912]', 0.94, 'webcam');

-- Insert sample face attendance records
INSERT INTO face_attendance (schedule_id, person_id, session_id, detection_count, total_captures, confidence_avg, status, meeting_duration_minutes, video_source) VALUES
(1, 1, 'session_20240912_090000', 4, 5, 0.87, 'present', 50, 'screen'),
(1, 2, 'session_20240912_090000', 3, 5, 0.82, 'present', 50, 'screen'),
(1, 3, 'session_20240912_090000', 2, 5, 0.79, 'partial', 50, 'screen'),
(1, 4, 'session_20240912_090000', 0, 5, 0.0, 'absent', 50, 'screen');

-- Insert sample face detection logs
INSERT INTO face_detection_logs (face_attendance_id, person_id, confidence_score, session_minute, capture_number) VALUES
(1, 1, 0.89, 5, 1),
(1, 1, 0.85, 15, 2),
(1, 1, 0.91, 25, 3),
(1, 1, 0.83, 35, 4),
(2, 2, 0.78, 10, 2),
(2, 2, 0.86, 20, 3),
(2, 2, 0.82, 40, 5);

-- ================================
-- Add Constraints and Triggers (Optional)
-- ================================

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at columns
CREATE TRIGGER update_persons_updated_at BEFORE UPDATE ON persons
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_face_encodings_updated_at BEFORE UPDATE ON face_encodings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_face_attendance_updated_at BEFORE UPDATE ON face_attendance
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ================================
-- Views for Common Queries
-- ================================

-- View for student attendance summary
CREATE VIEW student_attendance_summary AS
SELECT 
    p.person_id,
    p.name,
    p.id_number,
    s.section_name,
    COUNT(CASE WHEN a.status = 'present' THEN 1 END) as rfid_present,
    COUNT(CASE WHEN fa.status = 'present' THEN 1 END) as face_present,
    COUNT(CASE WHEN a.status = 'present' OR fa.status = 'present' THEN 1 END) as total_present,
    COUNT(a.attendance_id) + COUNT(fa.face_attendance_id) as total_sessions
FROM persons p
JOIN student_sections ss ON p.person_id = ss.person_id
JOIN sections s ON ss.section_id = s.section_id
LEFT JOIN attendance a ON p.person_id = a.person_id
LEFT JOIN face_attendance fa ON p.person_id = fa.person_id
WHERE p.role = 'student'
GROUP BY p.person_id, p.name, p.id_number, s.section_name;

-- View for teacher dashboard
CREATE VIEW teacher_dashboard AS
SELECT 
    t.person_id as teacher_id,
    t.name as teacher_name,
    sec.section_name,
    sch.subject_name,
    sch.day_of_week,
    sch.start_time,
    sch.end_time,
    sch.meeting_type,
    cr.room_number,
    COUNT(ss.person_id) as enrolled_students,
    COUNT(CASE WHEN a.status = 'present' THEN 1 END) as rfid_attendance_today,
    COUNT(CASE WHEN fa.status = 'present' THEN 1 END) as face_attendance_today
FROM persons t
JOIN teacher_sections ts ON t.person_id = ts.person_id
JOIN sections sec ON ts.section_id = sec.section_id
JOIN schedule sch ON sec.section_id = sch.section_id AND sch.teacher_id = t.person_id
JOIN classrooms cr ON sch.classroom_id = cr.classroom_id
JOIN student_sections ss ON sec.section_id = ss.section_id
LEFT JOIN attendance a ON sch.schedule_id = a.schedule_id 
    AND DATE(a.timestamp) = CURRENT_DATE
LEFT JOIN face_attendance fa ON sch.schedule_id = fa.schedule_id 
    AND DATE(fa.created_at) = CURRENT_DATE
WHERE t.role = 'teacher'
GROUP BY t.person_id, t.name, sec.section_name, sch.subject_name, 
         sch.day_of_week, sch.start_time, sch.end_time, sch.meeting_type, cr.room_number;

-- ================================
-- Grant Permissions (for application user)
-- ================================

-- Grant usage on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO PUBLIC;

-- Success message
SELECT 'Enhanced Attendance System Database Schema Created Successfully!' as status,
       'Tables: ' || count(*) as table_count
FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
