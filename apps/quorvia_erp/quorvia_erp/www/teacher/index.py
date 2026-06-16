import frappe
from frappe.utils import today

def get_context(context):
    if frappe.session.user == "Guest":
        frappe.local.flags.redirect_location = "/login"
        raise frappe.Redirect
        
    context.no_cache = 1
    user = frappe.session.user
    
    # 1. Get the Instructor record
    instructors = frappe.get_all("Instructor", filters={"employee_user_id": user}, limit=1)
    # Also check by email if employee_user_id is not set
    if not instructors:
        instructors = frappe.get_all("Instructor", filters={"email": user}, limit=1)
        
    if not instructors:
        context.error_msg = "Your account is not linked to an Instructor Profile. Please contact the administration."
        return context
        
    instructor_id = instructors[0].name
    context.instructor = frappe.get_doc("Instructor", instructor_id)
    
    # 2. Get Today's Schedule
    context.schedule = frappe.get_all("Course Schedule",
        filters={"instructor": instructor_id, "schedule_date": today()},
        fields=["name", "student_group", "course", "from_time", "to_time", "room"],
        order_by="from_time asc"
    )
    
    # 3. Get Student Groups assigned to this Instructor
    # We find distinct groups from all course schedules of this instructor
    groups = frappe.get_all("Course Schedule", 
        filters={"instructor": instructor_id},
        fields=["student_group"],
        distinct=True
    )
    context.student_groups = [g.student_group for g in groups if g.student_group]
