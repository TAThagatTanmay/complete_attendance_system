# Enhanced Facial Recognition Attendance System

## 🎯 Overview

A comprehensive attendance management system that combines traditional RFID/NFC scanning with modern facial recognition technology for both online and offline educational environments.

## ✨ Features

### 🔍 Dual Recognition System
- **RFID/NFC Scanning**: Traditional attendance for physical classrooms
- **Facial Recognition**: AI-powered attendance for online meetings (Zoom, Teams, etc.)
- **Hybrid Support**: Seamless integration of both systems

### 📊 Smart Attendance Logic
- Captures faces 5 times during 50-minute sessions
- Marks students present if detected 3+ times
- Handles partial attendance (1-2 detections)
- Batch processing for 80-90 students

### 🎛️ Teacher Dashboard
- Easy login and session management
- Video source selection (Screen Capture/Webcam)
- Real-time attendance monitoring
- Comprehensive analytics and reporting

## 🚀 Quick Start

### Prerequisites
- Node.js 16+
- PostgreSQL 12+
- Modern web browser (Chrome/Firefox)

### 1. Database Setup
```bash
# Create database and run schema
psql "your-connection-string" < enhanced_attendance_schema.sql
```

### 2. Backend Setup
```bash
npm install
cp .env.example .env
# Edit .env with your database credentials
npm start
```

### 3. Frontend Access
Open `index.html` in your browser and login:
- Username: `teacher`
- Password: `teach123`

## 📁 Project Structure

```
├── face_attendance_api.js      # Backend Node.js server
├── package.json               # Dependencies and scripts
├── .env.example              # Environment configuration
├── index.html                # Main frontend interface
├── app.js                    # Face recognition logic
├── enhanced_attendance_schema.sql  # Database schema
├── add_index_corrected.html  # Admin tools
├── add_index_corrected.js    # Admin logic
└── README.md                 # This file
```

## 🔧 Configuration

### Environment Variables
```bash
DATABASE_URL=postgresql://username:password@localhost:5432/attendance_db
JWT_SECRET=your-super-secret-key
PORT=5000
NODE_ENV=production
```

### System Settings
- **Capture Interval**: 10 minutes (configurable)
- **Session Duration**: 50 minutes (configurable)
- **Required Detections**: 3 out of 5 for present status
- **Supported Students**: 80-90 per class

## 🎮 Usage Guide

### For Teachers

1. **Login** to the system
2. **Select Video Source**:
   - **Screen Capture**: For Zoom meetings
   - **Webcam**: For in-person classes
3. **Start Session**: Configure subject and section
4. **Monitor**: Real-time attendance tracking
5. **End & Upload**: Review and submit to database

### For Administrators

Use the admin tools (`add_index_corrected.html`) to:
- Add students with RFID tags
- Create sections and schedules
- Link students to classes
- Generate SQL statements

## 📊 Database Schema

### Core Tables
- `persons` - Student and teacher profiles
- `face_encodings` - Facial recognition data
- `face_attendance` - Session-based attendance
- `attendance` - RFID/NFC attendance
- `sections` - Class sections
- `schedule` - Class timetables

## 🔐 Security Features

- JWT authentication
- Rate limiting
- CORS protection
- Encrypted face data storage
- SQL injection prevention

## 📱 Deployment

### Free Hosting (Render)
1. Push code to GitHub
2. Create PostgreSQL database on Render
3. Deploy backend as Web Service
4. Deploy frontend as Static Site
5. Configure environment variables

### Local Development
```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Run on port 5000
npm start
```

## 🔍 API Endpoints

- `POST /login` - Authentication
- `GET /students` - List students
- `POST /attendance/batch-submit` - Submit attendance
- `GET /attendance/analytics` - View reports
- `GET /health` - System status

## 🛠️ Troubleshooting

### Common Issues

**Face Detection Not Working**
- Ensure camera permissions are granted
- Use Chrome or Firefox browsers
- Check lighting conditions
- Verify face-api.js models are loaded

**Database Connection Errors**
- Verify DATABASE_URL format
- Check PostgreSQL service status
- Ensure SSL settings match environment

**Performance Issues**
- Reduce video resolution for large classes
- Optimize face detection parameters
- Use batch processing for uploads

## 📈 Analytics Features

- Section-wise attendance comparison
- Individual student performance tracking
- Historical attendance trends
- Real-time session monitoring
- Exportable reports (CSV/Excel)

## 🔄 Integration

### RFID System Compatibility
- Maintains existing RFID workflows
- Backward compatible with current data
- Seamless migration path
- Dual-system operation

### Video Conferencing
- Works with Zoom, Teams, Meet
- Screen capture technology
- No platform-specific integration needed
- Privacy-focused local processing

## 🆘 Support

### Documentation
- [Deployment Guide](DEPLOYMENT.md)
- [API Documentation](API.md)
- [User Manual](USER_GUIDE.md)

### Contact
- GitHub Issues: [Report bugs](https://github.com/your-repo/issues)
- Email: support@yourschool.edu
- Wiki: [Knowledge base](https://github.com/your-repo/wiki)

## 📄 License

MIT License - see LICENSE file for details

## 🎓 Educational Impact

- **Time Savings**: 10-15 minutes per class
- **Accuracy**: Eliminates proxy attendance
- **Insights**: Student engagement analytics
- **Modernization**: Digital transformation support

---

**Built with ❤️ for educational institutions worldwide**