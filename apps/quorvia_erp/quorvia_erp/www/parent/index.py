import frappe

def get_context(context):
    if frappe.session.user == "Guest":
        frappe.local.flags.redirect_location = "/login"
        raise frappe.Redirect
        
    context.no_cache = 1
    user = frappe.session.user
    
    # Find the Guardian linked to the logged-in user
    guardians = frappe.get_all("Guardian", filters={"email_address": user}, limit=1)
    
    if not guardians:
        context.error_msg = "We couldn't find a Guardian record linked to your account. Please contact the school administration."
        return context
        
    guardian_id = guardians[0].name
    context.guardian = frappe.get_doc("Guardian", guardian_id)
    
    # Find students linked to this guardian
    student_guardians = frappe.get_all("Student Guardian", 
        filters={"guardian": guardian_id}, 
        fields=["parent"]
    )
    
    student_ids = [sg.parent for sg in student_guardians]
    
    if student_ids:
        context.students = frappe.get_all("Student", 
            filters={"name": ["in", student_ids]},
            fields=["name", "first_name", "last_name", "student_email_id", "image"]
        )
        
        # Fetch basic stats for each student
        for student in context.students:
            # Attendance
            attendance = frappe.get_all("Student Attendance", 
                filters={"student": student.name, "status": "Present"}, 
                limit=100
            )
            student.attendance_count = len(attendance)
            
            # Fees (using Sales Invoice linked to Student)
            fees = frappe.get_all("Sales Invoice",
                filters={"student": student.name, "docstatus": 1, "status": ["in", ["Unpaid", "Overdue", "Partly Paid"]]},
                fields=["name", "outstanding_amount", "due_date", "status"]
            )
            student.pending_fees = fees
            student.total_outstanding = sum([f.outstanding_amount for f in fees]) if fees else 0
    else:
        context.students = []
