##############################################################
# Mobile API Documentation
# ERPNext School — REST API for Mobile Apps
# Phase 8: Mobile Access
##############################################################

ERPNext exposes a complete REST API compatible with any mobile framework.

## Authentication

### Method 1: Session-based (Web)

POST /api/method/login
Content-Type: application/json

{
  "usr": "teacher@school.com",
  "pwd": "password123"
}

Response:
{
  "message": "Logged In",
  "home_page": "/desk",
  "full_name": "Teacher Name"
}

### Method 2: API Key (Recommended for mobile)

1. Go to: ERPNext → Settings → Users → Your User
2. Click "API Access" tab
3. Generate API Keys
4. Store securely on mobile device

Authorization header:
Authorization: token api_key:api_secret

### Method 3: OAuth2 (Enterprise)

ERPNext supports OAuth2 for SSO integration.
Token endpoint: /api/method/frappe.integrations.oauth2.get_token

## Core API Endpoints

### Student Endpoints

GET  /api/resource/Student
GET  /api/resource/Student/{id}
GET  /api/resource/Student?filters=[["student_name","like","%John%"]]
POST /api/resource/Student

### Attendance Endpoints

GET  /api/resource/Student Attendance
POST /api/resource/Student Attendance
GET  /api/method/education.api.get_student_attendance?student={id}

### Fee Endpoints

GET  /api/resource/Fees
GET  /api/resource/Fees?filters=[["student",  "=","{student_id}"]]
POST /api/resource/Fees

### Assessment / Exam Endpoints

GET  /api/resource/Assessment Result
GET  /api/resource/Assessment Plan
GET  /api/resource/Assessment Result?filters=[["student","=","{id}"]]

### Timetable Endpoints

GET  /api/resource/Course Schedule
GET  /api/resource/Course Schedule?filters=[["instructor","=","{instructor_id}"]]

### Announcement Endpoints

GET  /api/resource/LMS Announcement
POST /api/resource/LMS Announcement

## Mobile App Architecture

### Parent App

Screens:
- Login (API Key auth)
- Dashboard (attendance summary, fee status, exam results)
- Child Profile
- Attendance history
- Fee payment (Razorpay/Stripe integration)
- Exam results
- School notices

API flows:
1. Auth → store token
2. GET /api/resource/Student?filters=[["guardian","=","parent@email.com"]]
3. GET /api/resource/Student Attendance?filters=[["student","=","{id}"]]
4. GET /api/resource/Fees?filters=[["student","=","{id}"],["outstanding_amount",">","0"]]

### Teacher App

Screens:
- Login
- My Classes
- Mark Attendance
- Gradebook
- Announcements
- Student profiles

API flows:
1. GET /api/resource/Course Schedule?filters=[["instructor","=","{instructor_id}"]]
2. POST /api/resource/Student Attendance (bulk attendance)
3. GET /api/resource/Student?filters=[["custom_program","=","Grade 5"]]

### Student App

Screens:
- Login
- My Dashboard
- Timetable
- Attendance
- Results
- LMS Courses
- Library account

API flows:
1. GET /api/resource/Student/{my_student_id}
2. GET /api/resource/Course Schedule (my timetable)
3. GET /api/resource/Assessment Result?student={id}
4. GET /api/resource/Fees?student={id}

## Token Management

Store API tokens securely:
- iOS: Keychain Services
- Android: EncryptedSharedPreferences / Android Keystore

Token refresh: Not required for API key auth (permanent until revoked)

For OAuth2:
- Access token expires in 3600s
- Use refresh token to get new access token
- POST /api/method/frappe.integrations.oauth2.get_token with grant_type=refresh_token

## Rate Limiting

ERPNext enforces:
- 300 requests/minute per IP
- Configurable in site_config.json (rate_limit.requests_per_minute)

Mobile apps should implement:
- Request queuing
- Exponential backoff on 429 responses
- Local caching of read-heavy data

## Webhook Integration

Configure webhooks for push notifications:
- Settings → Webhook
- Document Type: Student Attendance
- Condition: doc.status == "Absent"
- Request URL: your-notification-server/webhook

## Offline Support

Recommended offline-first strategy:
1. Cache student list on login
2. Queue attendance records locally
3. Sync when network available
4. Conflict resolution: server wins for historical data

## Sample API Calls (cURL)

# Login and get session
curl -X POST https://erp.school.example.com/api/method/login \
  -H "Content-Type: application/json" \
  -d '{"usr":"admin@school.com","pwd":"password"}'

# Get students with API Key auth
curl https://erp.school.example.com/api/resource/Student \
  -H "Authorization: token key:secret" \
  -H "Content-Type: application/json"

# Mark attendance
curl -X POST https://erp.school.example.com/api/resource/Student%20Attendance \
  -H "Authorization: token key:secret" \
  -H "Content-Type: application/json" \
  -d '{
    "student": "EDU-STU-00001",
    "course_schedule": "CSH-00001",
    "status": "Present",
    "date": "2026-06-16"
  }'
