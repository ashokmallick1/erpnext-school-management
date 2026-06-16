import frappe

def run():
    frappe.flags.in_test = True
    
    # Check if student exists
    if frappe.db.exists("Student", "EDU-STU-2026-00001"):
        student = frappe.get_doc("Student", "EDU-STU-2026-00001")
        
        # Link the user to this student
        student_email = "john@quorvia.test"
        student.student_email_id = student_email
        student.save(ignore_permissions=True)
        
        # Ensure the User exists
        if not frappe.db.exists("User", student_email):
            user = frappe.get_doc({
                "doctype": "User",
                "email": student_email,
                "first_name": "John",
                "last_name": "Doe",
                "send_welcome_email": 0,
                "roles": [{"role": "Student"}, {"role": "Student Portal User"}]
            }).insert(ignore_permissions=True)
            frappe.utils.password.update_password(student_email, "Quorvia@123")
        
        # Ensure LMS app doctypes exist before creating enrollments
        if frappe.db.exists("DocType", "LMS Course"):
            # Create a mock course
            course_name = "Intro to Quorvia"
            if not frappe.db.exists("LMS Course", course_name):
                frappe.get_doc({
                    "doctype": "LMS Course",
                    "title": course_name,
                    "short_introduction": "Learn the basics of the platform.",
                    "published": 1
                }).insert(ignore_permissions=True)
                
            if not frappe.db.exists("LMS Enrollment", {"member": student_email, "course": course_name}):
                frappe.get_doc({
                    "doctype": "LMS Enrollment",
                    "member": student_email,
                    "course": course_name,
                    "progress": 45
                }).insert(ignore_permissions=True)
                
        frappe.db.commit()
        print("Student test data generated.")

if __name__ == '__main__':
    run()
