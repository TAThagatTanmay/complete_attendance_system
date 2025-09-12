// Enhanced SQL Editor for Attendance System
let schemaContent = "";

// Load schema.sql file
document.getElementById("fileInput").addEventListener("change", function(e) {
    const file = e.target.files[0];
    if (file) {
        const reader = new FileReader();
        reader.onload = function(event) {
            schemaContent = event.target.result;
            document.getElementById("output").innerText = "Loaded schema.sql (" + file.name + ")";
        };
        reader.readAsText(file);
    }
});

function appendSQL(sql) {
    schemaContent += "\n" + sql;
    document.getElementById("output").innerText = sql;
}

function addPerson() {
    const name = document.getElementById("p_name").value.trim();
    const idn = document.getElementById("p_id_number").value.trim();
    const rfid = document.getElementById("p_rfid").value.trim();
    const role = document.getElementById("p_role").value;

    if (!name || !idn) { 
        alert("Name and ID Number are required"); 
        return; 
    }

    const rfidValue = rfid ? `'${rfid}'` : 'NULL';
    const hashedPass = btoa(idn); // Simple encoding for demo

    appendSQL(`INSERT INTO persons (name, id_number, rfid_tag, role, password) VALUES ('${name}', '${idn}', ${rfidValue}, '${role}', '${hashedPass}');`);
    alert("Person added successfully!");

    // Clear form
    document.getElementById("p_name").value = "";
    document.getElementById("p_id_number").value = "";
    document.getElementById("p_rfid").value = "";
}

function addSection() {
    const s = document.getElementById("s_name").value.trim();
    if (!s) { 
        alert("Enter section name"); 
        return; 
    }

    appendSQL(`INSERT INTO sections (section_name) VALUES ('${s}');`);
    alert("Section added successfully!");

    document.getElementById("s_name").value = "";
}

function addStudentSection() {
    const pid = document.getElementById("ss_pid").value;
    const sid = document.getElementById("ss_sid").value;

    if (!pid || !sid) { 
        alert("Both IDs are required"); 
        return; 
    }

    appendSQL(`INSERT INTO student_sections (person_id, section_id) VALUES (${pid}, ${sid});`);
    alert("Student-Section link added successfully!");

    document.getElementById("ss_pid").value = "";
    document.getElementById("ss_sid").value = "";
}

function addTeacherSection() {
    const pid = document.getElementById("ts_pid").value;
    const sid = document.getElementById("ts_sid").value;

    if (!pid || !sid) { 
        alert("Both IDs are required"); 
        return; 
    }

    appendSQL(`INSERT INTO teacher_sections (person_id, section_id) VALUES (${pid}, ${sid});`);
    alert("Teacher-Section link added successfully!");

    document.getElementById("ts_pid").value = "";
    document.getElementById("ts_sid").value = "";
}

function addClassroom() {
    const room = document.getElementById("c_room").value.trim();
    const location = document.getElementById("c_location").value.trim();
    const capacity = document.getElementById("c_capacity").value;

    if (!room) { 
        alert("Room number is required"); 
        return; 
    }

    const locationValue = location ? `'${location}'` : 'NULL';
    const capacityValue = capacity ? capacity : 'NULL';

    appendSQL(`INSERT INTO classrooms (room_number, location, capacity) VALUES ('${room}', ${locationValue}, ${capacityValue});`);
    alert("Classroom added successfully!");

    document.getElementById("c_room").value = "";
    document.getElementById("c_location").value = "";
    document.getElementById("c_capacity").value = "";
}

function addSchedule() {
    const sid = document.getElementById("sch_sid").value;
    const tid = document.getElementById("sch_tid").value;
    const cid = document.getElementById("sch_cid").value;
    const subject = document.getElementById("sch_subject").value.trim();
    const day = document.getElementById("sch_day").value;
    const st = document.getElementById("sch_start").value;
    const et = document.getElementById("sch_end").value;
    const meetingType = document.getElementById("sch_meeting_type").value;
    const meetingUrl = document.getElementById("sch_meeting_url").value.trim();

    if (!sid || !tid || !cid || !subject || !st || !et) { 
        alert("All required fields must be filled"); 
        return; 
    }

    const urlValue = meetingUrl ? `'${meetingUrl}'` : 'NULL';

    appendSQL(`INSERT INTO schedule (section_id, teacher_id, classroom_id, subject_name, day_of_week, start_time, end_time, meeting_type, meeting_url) VALUES (${sid}, ${tid}, ${cid}, '${subject}', '${day}', '${st}', '${et}', '${meetingType}', ${urlValue});`);
    alert("Schedule added successfully!");

    // Clear form
    document.getElementById("sch_sid").value = "";
    document.getElementById("sch_tid").value = "";
    document.getElementById("sch_cid").value = "";
    document.getElementById("sch_subject").value = "";
    document.getElementById("sch_start").value = "";
    document.getElementById("sch_end").value = "";
    document.getElementById("sch_meeting_url").value = "";
}

function addAttendance() {
    const pid = document.getElementById("a_pid").value;
    const scheduleId = document.getElementById("a_schedule_id").value;
    const ts = document.getElementById("a_time").value;
    const type = document.getElementById("a_type").value;

    if (!pid || !scheduleId || !ts) { 
        alert("All required fields must be filled"); 
        return; 
    }

    appendSQL(`INSERT INTO attendance (schedule_id, person_id, timestamp, attendance_type) VALUES (${scheduleId}, ${pid}, '${ts.replace("T", " ")}', '${type}');`);
    alert("RFID attendance record added successfully!");

    document.getElementById("a_pid").value = "";
    document.getElementById("a_schedule_id").value = "";
    document.getElementById("a_time").value = "";
}

function addFaceAttendance() {
    const scheduleId = document.getElementById("fa_schedule_id").value;
    const sessionId = document.getElementById("fa_session_id").value.trim();
    const pid = document.getElementById("fa_pid").value;
    const detectionCount = document.getElementById("fa_detection_count").value;
    const confidence = document.getElementById("fa_confidence").value;

    if (!scheduleId || !sessionId || !pid) {
        alert("Schedule ID, Session ID, and Person ID are required");
        return;
    }

    const status = detectionCount >= 3 ? 'present' : (detectionCount > 0 ? 'partial' : 'absent');

    appendSQL(`INSERT INTO face_attendance (schedule_id, person_id, session_id, detection_count, confidence_avg, status) VALUES (${scheduleId}, ${pid}, '${sessionId}', ${detectionCount || 0}, ${confidence || 0}, '${status}');`);
    alert("Face attendance record added successfully!");

    document.getElementById("fa_schedule_id").value = "";
    document.getElementById("fa_session_id").value = "";
    document.getElementById("fa_pid").value = "";
    document.getElementById("fa_detection_count").value = "0";
    document.getElementById("fa_confidence").value = "0.85";
}

function downloadFile() {
    if (!schemaContent.trim()) {
        alert("No content to download. Please add some data first.");
        return;
    }

    const blob = new Blob([schemaContent], { type: "text/sql" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = "enhanced_attendance_schema.sql";
    link.click();

    setTimeout(() => URL.revokeObjectURL(link.href), 100);
}

// Set current date/time for attendance inputs
document.addEventListener('DOMContentLoaded', function() {
    const now = new Date();
    const datetime = now.toISOString().slice(0, 16);
    document.getElementById('a_time').value = datetime;
});