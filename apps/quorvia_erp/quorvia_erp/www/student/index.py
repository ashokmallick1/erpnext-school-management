import frappe
from frappe.utils import today

def get_context(context):
    if frappe.session.user == "Guest":
        frappe.local.flags.redirect_location = "/login"
        raise frappe.Redirect
        
    context.no_cache = 1
    user = frappe.session.user
    
    # 1. Get the Student record
    students = frappe.get_all("Student", filters={"student_email_id": user}, limit=1)
    
    if not students:
        context.error_msg = "Your account is not linked to a Student Profile. Please contact the administration."
        return context
        
    student_id = students[0].name
    context.student = frappe.get_doc("Student", student_id)
    
    # 2. Get LMS Course Enrollments
    # LMS enrolls by member email, so we search LMS Enrollment for this user
    context.courses = []
    if frappe.db.exists("DocType", "LMS Enrollment"):
        enrollments = frappe.get_all("LMS Enrollment", 
            filters={"member": user}, 
            fields=["course", "current_lesson", "progress"]
        )
        for e in enrollments:
            course_doc = frappe.get_doc("LMS Course", e.course)
            e.course_title = course_doc.title
            e.image = course_doc.image
            e.short_introduction = course_doc.short_introduction
            context.courses.append(e)
            
    # 3. Get Recent Attendance
    context.attendance = frappe.get_all("Student Attendance",
        filters={"student": student_id},
        fields=["date", "status"],
        order_by="date desc",
        limit=5
    )
    
    # Overall attendance percent
    all_att = frappe.get_all("Student Attendance", filters={"student": student_id}, fields=["status"])
    total_days = len(all_att)
    present_days = len([a for a in all_att if a.status == "Present"])
    context.attendance_percent = (present_days / total_days * 100) if total_days > 0 else 0
    
    # 4. Get Recent Grades (Assessment Results)
    context.results = frappe.get_all("Assessment Result",
        filters={"student": student_id, "docstatus": 1},
        fields=["assessment_plan", "course", "total_score", "maximum_score", "grade"],
        order_by="creation desc",
        limit=5
    )
