# Launch checklist for the website (not a served page; for whoever deploys)

Fill the placeholders with sed (all 6 pages):

```sh
cd website   # run from the repo root
FILES="index.html privacy.html support.html es/index.html es/privacy.html es/support.html"
sed -i '' 's/{{SUPPORT_EMAIL}}/you@example.com/g; s/{{DEVELOPER_NAME}}/Your Name/g' $FILES
```

When the app is live, swap each "Coming soon" pill for a real link. The HTML comment above each pill shows the
target markup with the `{{APP_STORE_URL}}` marker. Apple's badge artwork must come from Apple's marketing tools.

```sh
APP_STORE_URL="https://apps.apple.com/app/idXXXXXXXXXX"
perl -0pi -e 's#<span class="cta cta-soon">Coming soon to the App Store</span>#<a class="cta cta-live" href="'"$APP_STORE_URL"'">Download on the App Store</a>#g' index.html
perl -0pi -e 's#<span class="cta cta-soon">Pr.ximamente en el App Store</span>#<a class="cta cta-live" href="'"$APP_STORE_URL"'">Descargar en el App Store</a>#g' es/index.html
```

Notes:
- The site has no external resources. The CSP in `vercel.json` (`default-src 'self'`, no scripts) would block any CDN or analytics added later.
- Canonical, hreflang, og:url and og:image use root-relative paths because the domain is not decided. Prefix them with the real origin before deploying.
- The privacy pages are rendered from `docs/legal/privacy-policy.*.md` without the DRAFT banner. Legal review of that text is still required.
