import frappe
import json
import time

@frappe.whitelist(allow_guest=False)
def chat():
    # Frappe auto-passes kwargs from the request
    message = frappe.form_dict.get('message', '')
    if not message:
        return {"error": "Message is required."}

    # Fetch AI settings
    if frappe.db.exists("DocType", "Quorvia AI Settings"):
        settings = frappe.get_single("Quorvia AI Settings")
        if not settings.enable_ai_assistant:
            return {"reply": "The AI assistant is currently disabled by the administration."}
        provider = settings.ai_provider
    else:
        provider = "Mock"
        
    user = frappe.session.user
    first_name = frappe.db.get_value("User", user, "first_name") or "there"

    # Context injection (who are we talking to?)
    roles = frappe.get_roles(user)
    role_context = "User"
    if "Student" in roles:
        role_context = "Student"
    elif "Instructor" in roles:
        role_context = "Teacher"
    elif "Parent" in roles:
        role_context = "Parent"

    # Simulate network delay for realism
    time.sleep(1.5)

    if provider == "Mock":
        # A simple simulated AI logic based on keywords
        msg_lower = message.lower()
        if "attendance" in msg_lower:
            reply = f"Hello {first_name}! As a {role_context}, you can view your attendance records directly from your portal dashboard. Let me know if you need help finding them."
        elif "fee" in msg_lower or "pay" in msg_lower:
            reply = "Fee invoices are automatically generated and sent to parents via email. You can also view outstanding balances on the dashboard."
        elif "schedule" in msg_lower or "timetable" in msg_lower:
            reply = "Your daily schedule is displayed on the main portal page. It updates dynamically based on your assigned Student Group."
        else:
            reply = f"Hi {first_name}! I am the Quorvia AI Assistant. I detected you are a {role_context}. I am currently in Mock Mode, but once my administrator configures my API key, I'll be able to answer complex questions about your academic life!"
        return {"reply": reply}
    else:
        # In a production environment, you would use requests/openai library here
        # to send `message` along with `system_prompt` and `role_context` to the LLM.
        return {"reply": f"Connected to {provider}, but the integration code needs the official python SDK installed."}
