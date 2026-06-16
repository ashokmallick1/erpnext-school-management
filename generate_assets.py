logo_svg='''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#4F46E5;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#7C3AED;stop-opacity:1" />
    </linearGradient>
  </defs>
  <circle cx="50" cy="50" r="45" fill="url(#grad1)" />
  <text x="50" y="65" font-family="Arial, sans-serif" font-size="50" font-weight="bold" fill="white" text-anchor="middle">Q</text>
  <polygon points="75,25 80,15 85,25 95,28 87,35 89,45 80,40 71,45 73,35 65,28" fill="#FBBF24" />
</svg>'''

with open("apps/quorvia_erp/quorvia_erp/public/images/quorvia_logo.svg", "w") as f:
    f.write(logo_svg)

with open("apps/quorvia_erp/quorvia_erp/public/images/favicon.svg", "w") as f:
    f.write(logo_svg)

css='''
/* Quorvia Custom Branding */
:root {
  --primary-color: #4F46E5;
  --navbar-bg: #1E1B4B;
}

body[data-route="login"] .for-login {
  background: linear-gradient(135deg, #EEF2FF 0%, #E0E7FF 100%);
  border-radius: 12px;
  box-shadow: 0 10px 25px rgba(0,0,0,0.05);
}

body[data-route="login"] .page-card-head {
  padding-bottom: 20px;
}

body[data-route="login"] .page-card-head img {
  width: 64px;
  height: 64px;
}

.navbar .brand-logo {
  font-weight: 800;
  color: var(--primary-color);
  letter-spacing: -0.5px;
}
'''
with open("apps/quorvia_erp/quorvia_erp/public/css/quorvia_erp.css", "w") as f:
    f.write(css)

