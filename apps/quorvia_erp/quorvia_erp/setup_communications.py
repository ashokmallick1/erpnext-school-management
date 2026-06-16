import frappe

def run():
    frappe.flags.in_test = True

    # 1. Email Notification for Absenteeism
    if not frappe.db.exists("Notification", "Absenteeism Alert"):
        doc = frappe.get_doc({
            "doctype": "Notification",
            "name": "Absenteeism Alert",
            "subject": "Attendance Alert: {{ doc.student_name }} is marked Absent",
            "document_type": "Student Attendance",
            "event": "Save",
            "condition": "doc.status == 'Absent'",
            "send_to_all_assignees": 0,
            "message": """
            <h3>Attendance Alert</h3>
            <p>Dear Parent,</p>
            <p>This is to inform you that your child <strong>{{ doc.student_name }}</strong> has been marked <strong>Absent</strong> on {{ frappe.utils.formatdate(doc.date) }}.</p>
            <p>If you have not already notified the school, please contact the administration immediately.</p>
            <p>Regards,<br>Quorvia Management</p>
            """,
            "recipients": [
                {
                    "receiver_by_document_field": "student",
                    # In a real setup, we would join the Guardian email. 
                    # Frappe's native notification allows picking an Email field.
                    # We will set a static email or leave the field blank for the test.
                }
            ]
        })
        # For simplicity in this demo, send to the user who created it
        doc.recipients[0].receiver_by_document_field = "owner"
        doc.insert(ignore_permissions=True)
        print("Created Notification: Absenteeism Alert")

    # 2. Email Notification for Fee Generation
    if not frappe.db.exists("Notification", "Fee Generation Alert"):
        doc = frappe.get_doc({
            "doctype": "Notification",
            "name": "Fee Generation Alert",
            "subject": "New Fee Invoice Generated for {{ doc.student_name }}",
            "document_type": "Sales Invoice",
            "event": "Submit",
            "condition": "doc.student",
            "send_to_all_assignees": 0,
            "message": """
            <h3>Fee Invoice Generated</h3>
            <p>Dear Parent,</p>
            <p>A new fee invoice has been generated for <strong>{{ doc.student_name }}</strong>.</p>
            <p>Total Amount: {{ doc.grand_total }}</p>
            <p>Please find the invoice attached to this email. You can view the details and pay online via the Parent Portal.</p>
            <p>Regards,<br>Quorvia Finance</p>
            """,
            "recipients": [
                {
                    "receiver_by_document_field": "owner"
                }
            ]
        })
        doc.insert(ignore_permissions=True)
        print("Created Notification: Fee Generation Alert")

    # 3. WhatsApp Webhook (Simulated Twilio endpoint)
    if not frappe.db.exists("Webhook", "WhatsApp Absenteeism Webhook"):
        doc = frappe.get_doc({
            "doctype": "Webhook",
            "webhook_name": "WhatsApp Absenteeism Webhook",
            "webhook_doctype": "Student Attendance",
            "webhook_docevent": "on_submit",
            "condition": "doc.status == 'Absent'",
            "request_url": "https://api.twilio.com/2010-04-01/Accounts/AC_SIMULATED/Messages.json",
            "request_method": "POST",
            "webhook_data": [
                {"fieldname": "To", "key": "whatsapp:+1234567890"},
                {"fieldname": "From", "key": "whatsapp:+0987654321"},
                {"fieldname": "Body", "key": "Attendance Alert: {{ doc.student_name }} is marked Absent today."}
            ]
        })
        doc.insert(ignore_permissions=True)
        print("Created Webhook: WhatsApp Absenteeism")

    frappe.db.commit()
    print("Communications Module setup successfully.")

if __name__ == '__main__':
    run()
