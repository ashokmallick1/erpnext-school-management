# School Configuration Guide

> Complete K-12 School Management Configuration via ERPNext UI

---

## Navigation Conventions

All paths start from the ERPNext desk. Navigation format:
`Module → DocType → Action`

Example: **Education → Student → New** means:
1. Click "Education" in the module selector
2. Click "Student" in the left sidebar
3. Click "New" button

---

## 1. Company Setup

### 1.1 Configure Your School

**Settings → Company → [Your Company]**

| Field | Example Value |
|-------|--------------|
| Company Name | St. Mary's School |
| Abbreviation | SMS |
| Default Currency | INR |
| Country | India |
| Domain | Education |
| Email | admin@stmarys.edu |
| Phone | +91-XXX-XXXXXXX |
| Address | Your school address |

### 1.2 School Logo

Upload your school logo in the Company form → Logo field.

---

## 2. Academic Year & Terms

### 2.1 Create Academic Year

**Education → Setup → Academic Year → New**

| Field | Value |
|-------|-------|
| Academic Year Name | 2026-2027 |
| Year Start Date | 01-04-2026 |
| Year End Date | 31-03-2027 |

### 2.2 Create Academic Terms

**Education → Setup → Academic Term → New** (repeat for each term)

**Term 1:**
| Field | Value |
|-------|-------|
| Term Name | Term 1 2026-2027 |
| Academic Year | 2026-2027 |
| Term Start Date | 01-04-2026 |
| Term End Date | 31-08-2026 |

**Term 2:**
| Term Name | Term 2 2026-2027 |
| Academic Year | 2026-2027 |
| Term Start Date | 01-09-2026 |
| Term End Date | 31-01-2027 |

**Term 3:**
| Term Name | Term 3 2026-2027 |
| Academic Year | 2026-2027 |
| Term Start Date | 01-02-2027 |
| Term End Date | 31-03-2027 |

---

## 3. Programs (Grade Levels)

**Education → Setup → Program → New** (repeat for each grade)

Create these programs:

| Program Name | Abbreviation |
|-------------|--------------|
| Nursery | NUR |
| LKG | LKG |
| UKG | UKG |
| Grade 1 | G1 |
| Grade 2 | G2 |
| Grade 3 | G3 |
| Grade 4 | G4 |
| Grade 5 | G5 |
| Grade 6 | G6 |
| Grade 7 | G7 |
| Grade 8 | G8 |
| Grade 9 | G9 |
| Grade 10 | G10 |
| Grade 11 - Science | G11-SCI |
| Grade 11 - Commerce | G11-COM |
| Grade 12 - Science | G12-SCI |
| Grade 12 - Commerce | G12-COM |

---

## 4. Courses (Subjects)

**Education → Setup → Course → New**

| Course Name | Abbreviation |
|------------|--------------|
| English | ENG |
| Hindi | HIN |
| Mathematics | MATH |
| Science | SCI |
| Social Science | SS |
| Computer Science | CS |
| Physics | PHY |
| Chemistry | CHEM |
| Biology | BIO |
| History | HIST |
| Geography | GEO |
| Economics | ECO |
| Physical Education | PE |
| Music | MUS |
| Environmental Science | EVS |

---

## 5. Instructors (Teachers)

**Education → Instructor → New**

For each teacher:

| Field | Description |
|-------|-------------|
| Instructor Name | Full name |
| Instructor Email | School email address |
| Department | Subject specialization |
| Designation | "Teacher", "HOD", "Principal" |
| Employee | Link to HR Employee record |

### 5.1 Link to Employee

If using HRMS, first create an Employee record:

**HRMS → Employee → New**

Then link in Instructor form → Employee field.

---

## 6. Student Management

### 6.1 Student Admission (Manual)

**Education → Student → New**

| Field | Description |
|-------|-------------|
| First Name | Student first name |
| Last Name | Student last name |
| Date of Birth | DD-MM-YYYY |
| Gender | Male/Female/Other |
| Blood Group | Select from dropdown |
| Student Email | Student email (for portal access) |
| Joining Date | Date of admission |

### 6.2 Guardians

In the Student form → **Guardian Details** section:

| Field | Description |
|-------|-------------|
| Guardian Name | Full name |
| Relation | Father/Mother/Guardian |
| Mobile Number | Contact number |
| Email | Email (for parent portal login) |
| Occupation | Optional |
| Guardian Of | Linked to this student |

### 6.3 Bulk Student Import

**Data → Import Data → Student**

Download the template, fill it, and import.

### 6.4 Student Admission (Online Applications)

**Education → Admission → Student Applicant → New**

Configure admission workflow:
1. **Apply** → Applicant submits form
2. **Admission Pending** → Staff reviews
3. **Admitted** → Accepted
4. **Rejected** → Not accepted

### 6.5 Program Enrollment

After admission, enroll the student:

**Education → Student → [Student] → Enroll**

Or via: **Education → Program Enrollment → New**

---

## 7. Timetable

### 7.1 Create Course Schedule

**Education → Course Schedule → New**

| Field | Value |
|-------|-------|
| Course | Mathematics |
| Program | Grade 6 |
| Instructor | Teacher Name |
| Room | Room 101 |
| From Time | 09:00 |
| To Time | 09:45 |
| Day of Week | Monday |
| Academic Year | 2026-2027 |
| Academic Term | Term 1 2026-2027 |

### 7.2 Timetable Tool

**Education → Timetable Tool**

The visual timetable creator allows drag-and-drop scheduling.

---

## 8. Attendance

### 8.1 Student Attendance

**Education → Attendance → Student Attendance → New**

| Field | Value |
|-------|-------|
| Student | Select student |
| Course Schedule | Select class period |
| Status | Present / Absent / Leave |
| Date | Today's date |

### 8.2 Bulk Attendance (via Course Schedule)

From any Course Schedule: **Actions → Take Attendance**

This shows a list of enrolled students with checkboxes.

### 8.3 Attendance Report

**Education → Reports → Student Monthly Attendance Report**

Filter by:
- Student
- Program
- Academic Year/Term
- Date range

---

## 9. Fee Management

### 9.1 Fee Categories

**Education → Fee Category → New**

Already created by setup script:
- Tuition Fee, Library Fee, Lab Fee, Sports Fee, etc.

### 9.2 Fee Structure

**Education → Fee Structure → New**

| Field | Value |
|-------|-------|
| Name | Monthly Fee - Grade 6 - 2026-2027 |
| Academic Year | 2026-2027 |
| Company | My School |

In the **Components** table:
| Fee Category | Amount |
|-------------|--------|
| Tuition Fee | 4500.00 |
| Library Fee | 250.00 |
| Sports Fee | 300.00 |

### 9.3 Create Fee for Students

**Education → Fees → New**

| Field | Value |
|-------|-------|
| Student | Select student |
| Program | Grade 6 |
| Fee Structure | Monthly Fee - Grade 6 - 2026-2027 |
| Academic Year | 2026-2027 |
| Academic Term | Term 1 2026-2027 |
| Due Date | 10-04-2026 |

### 9.4 Bulk Fee Creation

Use the **Fee Schedule** tool:
**Education → Fee Schedule → New**

Configure once, and fees are auto-created for all students in a program.

---

## 10. Examinations

### 10.1 Create Exam Group (Assessment Criteria)

**Education → Assessment Criteria → New**

| Field | Value |
|-------|-------|
| Assessment Criteria | Unit Test 1 |
| Maximum Score | 100 |

### 10.2 Assessment Plan

**Education → Assessment Plan → New**

| Field | Value |
|-------|-------|
| Assessment Name | Unit Test 1 - Term 1 |
| Program | Grade 8 |
| Course | Mathematics |
| Academic Year | 2026-2027 |
| Academic Term | Term 1 2026-2027 |
| Scheduling Date | 15-05-2026 |
| From Time | 09:00 |
| To Time | 11:00 |
| Room | Exam Hall |
| Maximum Assessment Score | 100 |

### 10.3 Enter Assessment Results

**Education → Assessment Result → New**

Or from Assessment Plan: **Submit → Enter Results**

### 10.4 Grading Scale

**Education → Grading Scale → New**

| Grade | Threshold |
|-------|-----------|
| A+ | 90 |
| A | 80 |
| B+ | 70 |
| B | 60 |
| C | 50 |
| D | 40 |
| F | 0 |

---

## 11. Library

### 11.1 Library Settings

**Library Management → Library Settings**

| Field | Value |
|-------|-------|
| Loan Period | 14 (days) |
| Maximum Number of Loans | 3 |
| Fine Amount | 2.00 (per day) |

### 11.2 Add Books

**Library Management → Library Item → New**

| Field | Value |
|-------|-------|
| Title | Mathematics for Grade 6 |
| Author | Author Name |
| ISBN | ISBN number |
| Publisher | Publisher |
| Year | 2024 |
| Copies | 5 |

### 11.3 Library Members

**Library Management → Library Member → New**

Create a member record for each student/staff.

### 11.4 Issue Books

**Library Management → Library Transaction → New**

| Field | Value |
|-------|-------|
| Library Member | Select member |
| Library Item | Select book |
| Type | Issue |
| Date | Today |

---

## 12. Role Configuration

### 12.1 Assign Roles to Users

**Settings → User → [Username] → Roles**

| User Type | Roles to Assign |
|-----------|----------------|
| School Principal | Principal, System Manager (for full access) |
| Teachers | Teacher, Student Portal User (to view portal) |
| Parents | Guest (portal only — they log in via web portal) |
| Accounts Staff | Accounts Manager, Accounts User |
| Librarian | Librarian, Library Manager |
| Transport In-charge | Transport Manager |

### 12.2 Parent Portal Access

Parents access via the **Web Portal** (same URL, not the desk):
- URL: `https://erp.yourschool.com` (without `/desk`)
- They see a simplified view of their child's data

Parent user setup:
1. **Settings → User → New**
2. Email: parent@email.com
3. Role: Guest (Portal only)
4. Link to Guardian record

### 12.3 Student Portal Access

Students access the LMS and their academic data:
1. **Settings → User → New**
2. Email: student@email.com
3. Role: Student Portal User, LMS User

---

## 13. Email Notifications

### 13.1 Configure Notifications

**Settings → Notification → New**

Example — Fee reminder:

| Field | Value |
|-------|-------|
| Name | Fee Reminder |
| Document Type | Fees |
| Send Alert On | Days Before |
| Days Before or After | 7 |
| Recipients | Send to Parent Email |
| Subject | Fee Payment Reminder - {{doc.student_name}} |

---

## 14. Transport Management

**Transport → Vehicle → New**

| Field | Value |
|-------|-------|
| License Plate | KA-01-AB-1234 |
| Model | Tata Winger |
| Seating Capacity | 12 |

**Transport → Driver → New**

**Transport → Vehicle Route → New** (define pickup points)

**Transport → Student Transport Assignment → New** (assign students to routes)

---

## 15. Hostel Management

**HRMS → Accommodation → Hostel → New**

| Field | Value |
|-------|-------|
| Name | Boys Hostel Block A |
| Capacity | 50 |

**Hostel Room:**

| Field | Value |
|-------|-------|
| Room Number | A-101 |
| Hostel | Boys Hostel Block A |
| Capacity | 4 |

**Hostel Allocation:**

Assign students to rooms for the academic year.

---

## Quick Reference: ERPNext Education Module

```
Education
├── Setup
│   ├── Academic Year
│   ├── Academic Term
│   ├── Program
│   ├── Course
│   └── Grading Scale
├── Student
│   ├── Student Applicant
│   ├── Student
│   ├── Program Enrollment
│   └── Student Attendance
├── Instructor
├── Fee
│   ├── Fee Category
│   ├── Fee Structure
│   ├── Fee Schedule
│   └── Fees
├── Examination
│   ├── Assessment Criteria
│   ├── Assessment Plan
│   └── Assessment Result
├── Course Schedule (Timetable)
├── Reports
│   ├── Student Monthly Attendance
│   ├── Fee Collection Summary
│   └── Assessment Results
└── LMS
    ├── Course (Online)
    ├── Chapter
    └── Lesson
```
