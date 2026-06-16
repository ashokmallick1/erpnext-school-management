import frappe

def create_number_card(name, doctype, label, function="Count"):
    if not frappe.db.exists("Number Card", name):
        doc = frappe.get_doc({
            "doctype": "Number Card",
            "name": name,
            "document_type": doctype,
            "label": label,
            "function": function,
            "is_public": 1,
            "show_percentage_stats": 1,
            "stats_time_interval": "Monthly"
        })
        doc.insert(ignore_permissions=True)
        print(f"Created Number Card: {name}")

def create_dashboard_chart(name, doctype, chart_type, timespan, time_interval, based_on):
    if not frappe.db.exists("Dashboard Chart", name):
        doc = frappe.get_doc({
            "doctype": "Dashboard Chart",
            "name": name,
            "chart_name": name,
            "document_type": doctype,
            "chart_type": "Count",
            "timespan": timespan,
            "time_interval": time_interval,
            "based_on": based_on,
            "filters_json": "{}",
            "is_public": 1,
            "type": "Bar" if chart_type == "Bar" else "Line"
        })
        doc.insert(ignore_permissions=True)
        print(f"Created Dashboard Chart: {name}")

def run():
    frappe.flags.in_test = True

    # Number Cards
    create_number_card("Total Students", "Student", "Total Active Students")
    create_number_card("Total Instructors", "Instructor", "Total Instructors")
    
    # Dashboard Charts
    create_dashboard_chart("Admissions Trend", "Student Applicant", "Bar", "Last Year", "Monthly", "creation")
    create_dashboard_chart("Fee Collection Trend", "Sales Invoice", "Line", "Last Year", "Monthly", "posting_date")

    # Workspace
    workspace_name = "Quorvia Overview"
    if not frappe.db.exists("Workspace", workspace_name):
        doc = frappe.get_doc({
            "doctype": "Workspace",
            "name": workspace_name,
            "label": workspace_name,
            "title": workspace_name,
            "module": "Quorvia Erp",
            "is_standard": 0,
            "public": 1,
            "content": '[{"id":"header","type":"header","data":{"text":"Overview Dashboard","level":2}},{"id":"charts","type":"chart","data":{"chart_name":"Admissions Trend"}},{"id":"charts2","type":"chart","data":{"chart_name":"Fee Collection Trend"}},{"id":"cards","type":"number_card","data":{"number_card_name":"Total Students"}}]'
        })
        doc.insert(ignore_permissions=True)
        print(f"Created Workspace: {workspace_name}")

    frappe.db.commit()
    print("Dashboards Module setup successfully.")

if __name__ == '__main__':
    run()
