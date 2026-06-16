import frappe

def create_single_doctype(name, module, fields):
    if frappe.db.exists("DocType", name):
        print(f"DocType {name} already exists.")
        return

    doc = frappe.get_doc({
        "doctype": "DocType",
        "name": name,
        "module": module,
        "custom": 1,
        "issingle": 1,
        "fields": fields
    })
    doc.insert(ignore_permissions=True)
    print(f"Created Single DocType: {name}")

def run():
    frappe.flags.in_test = True
    module = "Quorvia Erp"

    # AI Settings
    create_single_doctype(
        name="Quorvia AI Settings",
        module=module,
        fields=[
            {"fieldname": "enable_ai_assistant", "fieldtype": "Check", "label": "Enable AI Assistant", "default": "1"},
            {"fieldname": "ai_provider", "fieldtype": "Select", "options": "Mock\nOpenAI\nGemini", "label": "AI Provider", "default": "Mock"},
            {"fieldname": "api_key", "fieldtype": "Password", "label": "API Key", "depends_on": "eval:doc.ai_provider != 'Mock'"},
            {"fieldname": "system_prompt", "fieldtype": "Small Text", "label": "System Prompt", "default": "You are Quorvia AI, a helpful assistant for students and staff. You are polite, concise, and helpful."}
        ]
    )

    frappe.db.commit()
    print("AI Module setup successfully.")

if __name__ == '__main__':
    run()
