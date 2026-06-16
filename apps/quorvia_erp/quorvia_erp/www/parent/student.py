import frappe

def get_context(context):
    if frappe.session.user == "Guest":
        frappe.local.flags.redirect_location = "/login"
        raise frappe.Redirect
        
    context.no_cache = 1
    user = frappe.session.user
    student_id = frappe.form_dict.get("name")
    
    if not student_id:
        frappe.local.flags.redirect_location = "/parent"
        raise frappe.Redirect
        
    # Verify the logged-in user is a guardian for THIS student
    guardians = frappe.get_all("Guardian", filters={"email_address": user}, limit=1)
    if not guardians:
        context.error_msg = "Access Denied."
        return context
        
    guardian_id = guardians[0].name
    
    is_linked = frappe.db.exists("Student Guardian", {"parent": student_id, "guardian": guardian_id})
    if not is_linked:
        context.error_msg = "You do not have permission to view this student."
        return context
        
    context.student = frappe.get_doc("Student", student_id)
    
    # Get Attendance records (last 30 days)
    context.attendance = frappe.get_all("Student Attendance",
        filters={"student": student_id},
        fields=["date", "status"],
        order_by="date desc",
        limit=30
    )
    
    # Calculate attendance percentage
    total_days = len(context.attendance)
    present_days = len([a for a in context.attendance if a.status == "Present"])
    context.attendance_percent = (present_days / total_days * 100) if total_days > 0 else 0
    
    # Get Academic Results (Assessment Results)
    context.results = frappe.get_all("Assessment Result",
        filters={"student": student_id, "docstatus": 1},
        fields=["assessment_plan", "course", "total_score", "maximum_score", "grade"],
        order_by="creation desc"
    )
    
    # Get Fees
    context.fees = frappe.get_all("Sales Invoice",
        filters={"student": student_id, "docstatus": 1},
        fields=["name", "posting_date", "due_date", "grand_total", "outstanding_amount", "status"],
        order_by="posting_date desc"
    )
