<cfparam name="pageTitle" default="CF/OBSERVER | Dashboard" />
<cfparam name="pageDescription" default="ColdFusion job intelligence for India and remote CFML roles." />
<cfparam name="bodyClass" default="flex h-screen overflow-hidden selection:bg-primary/30 bg-background text-on-surface" />
<!DOCTYPE html>
<html class="dark" lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<meta name="description" content="<cfoutput>#encodeForHTMLAttribute( pageDescription )#</cfoutput>"/>
<title><cfoutput>#encodeForHTML( pageTitle )#</cfoutput></title>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;700&amp;family=Geist:wght@100..900&amp;family=Archivo:wght@400;500;600;700;800&amp;family=Bricolage+Grotesque:opsz,wght@12..96,400..800&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<link href="<cfoutput>#assetBase#</cfoutput>cf-observer.css" rel="stylesheet"/>
<script id="tailwind-config">
tailwind.config = {
	darkMode: "class",
	theme: {
		extend: {
			colors: {
				"surface-dim": "#121414",
				"outline-variant": "#3e4850",
				"outline": "#87929b",
				"on-primary-container": "#003e58",
				"surface-container-highest": "#333535",
				"background": "#121414",
				"on-surface-variant": "#bdc8d1",
				"primary": "#82cfff",
				"tertiary": "#ffb876",
				"on-surface": "#e2e2e2",
				"surface-container-low": "#1a1c1c",
				"surface-container-high": "#282a2b",
				"surface-container-lowest": "#0c0f0f",
				"primary-container": "#00aeef",
				"surface-container": "#1e2020"
			},
			spacing: {
				"margin-mobile": "16px",
				"margin-desktop": "40px"
			},
			fontFamily: {
				"label-mono": ["JetBrains Mono"],
				"headline-md": ["Geist"],
				"body-md": ["Geist"]
			}
		}
	}
};
</script>
</head>
<body class="<cfoutput>#bodyClass#</cfoutput>">
