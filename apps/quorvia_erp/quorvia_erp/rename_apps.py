import frappe

def run():
    frappe.flags.in_test = True

    translations = {
        "ERPNext": "Quorvia Core",
        "Frappe HR": "Quorvia HR",
        "Education": "Quorvia Education",
        "Learning": "Quorvia LMS"
    }

    for source, target in translations.items():
        # Check if translation already exists
        if not frappe.db.exists("Translation", {"source_text": source, "language": "en"}):
            doc = frappe.get_doc({
                "doctype": "Translation",
                "language": "en",
                "source_text": source,
                "translated_text": target
            })
            doc.insert(ignore_permissions=True)
            print(f"Added translation: {source} -> {target}")
        else:
            # Update existing
            name = frappe.db.get_value("Translation", {"source_text": source, "language": "en"}, "name")
            doc = frappe.get_doc("Translation", name)
            doc.translated_text = target
            doc.save(ignore_permissions=True)
            print(f"Updated translation: {source} -> {target}")

    frappe.db.commit()
    print("App names successfully renamed via Translation Engine!")

if __name__ == '__main__':
    run()
