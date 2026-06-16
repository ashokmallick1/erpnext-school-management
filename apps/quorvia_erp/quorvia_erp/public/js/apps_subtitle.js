document.addEventListener("DOMContentLoaded", function() {
    if (window.location.pathname === '/apps') {
        const descriptions = {
            "Quorvia Core": "Accounting, Transport, Hostels, Dashboards",
            "Quorvia HR": "Payroll, Leaves, Attendance, Staffing",
            "Quorvia Education": "Admissions, Fees, Schedules, Academics",
            "Quorvia LMS": "Online Courses, Quizzes, Certifications"
        };

        const appIcons = document.querySelectorAll('.app-icon');
        appIcons.forEach(icon => {
            const titleEl = icon.querySelector('.app-title');
            if (titleEl) {
                const titleText = titleEl.innerText.trim();
                if (descriptions[titleText]) {
                    const descEl = document.createElement('div');
                    descEl.className = 'app-description';
                    descEl.innerText = descriptions[titleText];
                    descEl.style.fontSize = '12px';
                    descEl.style.color = '#6b7280';
                    descEl.style.marginTop = '4px';
                    descEl.style.textAlign = 'center';
                    descEl.style.lineHeight = '1.3';
                    icon.appendChild(descEl);

                    // Slightly adjust the parent to handle the new height nicely
                    icon.style.height = 'auto';
                    icon.style.paddingBottom = '10px';
                }
            }
        });
    }
});
