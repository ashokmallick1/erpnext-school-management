import frappe
from frappe.utils import today, add_days

def run():
    frappe.flags.in_test = True
    
    teacher_email = "teacher@quorvia.test"
    
    # Ensure the User exists
    if not frappe.db.exists("User", teacher_email):
        user = frappe.get_doc({
            "doctype": "User",
            "email": teacher_email,
            "first_name": "Jane",
            "last_name": "Smith",
            "send_welcome_email": 0,
            "roles": [{"role": "Instructor"}, {"role": "Academics User"}]
        }).insert(ignore_permissions=True)
        frappe.utils.password.update_password(teacher_email, "Quorvia@123")
        
    # Ensure Instructor Profile exists
    if not frappe.db.exists("Instructor", "Jane Smith"):
        instructor = frappe.get_doc({
            "doctype": "Instructor",
            "instructor_name": "Jane Smith",
            "email": teacher_email,
            "employee_user_id": teacher_email
        }).insert(ignore_permissions=True)
    else:
        instructor = frappe.get_doc("Instructor", "Jane Smith")
        instructor.email = teacher_email
        instructor.employee_user_id = teacher_email
        instructor.save(ignore_permissions=True)
        
    # Ensure Program and Course exist
    if not frappe.db.exists("Program", "High School"):
        frappe.get_doc({"doctype": "Program", "program_name": "High School"}).insert(ignore_permissions=True)
        
    if not frappe.db.exists("Course", "Mathematics 101"):
        frappe.get_doc({"doctype": "Course", "course_name": "Mathematics 101"}).insert(ignore_permissions=True)
        
    # Create Student Group
    if not frappe.db.exists("Student Group", "Grade 10 Math (A)"):
        frappe.get_doc({
            "doctype": "Student Group",
            "student_group_name": "Grade 10 Math (A)",
            "program": "High School",
            "group_based_on": "Course",
            "course": "Mathematics 101"
        }).insert(ignore_permissions=True)
        
    # Create Course Schedule for Today
    schedule_exists = frappe.db.exists("Course Schedule", {
        "instructor": instructor.name, 
        "schedule_date": today()
    })
    
    if not schedule_exists:
        frappe.get_doc({
            "doctype": "Course Schedule",
            "student_group": "Grade 10 Math (A)",
            "instructor": instructor.name,
            "course": "Mathematics 101",
            "schedule_date": today(),
            "from_time": "10:00:00",
            "to_time": "11:30:00",
            "room": "Room 101"
        }).insert(ignore_permissions=True)
        
    frappe.db.commit()
    print("Teacher test data generated.")

if __name__ == '__main__':
    run()

