# Chirpy POS Website

React, Next.js, and Tailwind marketing website for Chirpy POS.

## Run locally

Requirements:

- Node.js 22.13 or newer
- npm

From the `website` directory:

```powershell
npm install
npm run dev
```

Open `http://localhost:3000`.

Production checks:

```powershell
npm run lint
npm run build
node --test tests/rendered-html.test.mjs
```

## Common edits

- Page content and plan details: `app/page.tsx`
- Colors and layout: `app/globals.css`
- Store photograph: `public/chirpy-pos-retail-hero.png`
- Social sharing image: `public/chirpy-pos-social.png`
- Product logo and favicon: `public/chirpy-logo.png`
- Manrope font files: `public/fonts/`
- Browser title and social metadata: `app/layout.tsx`

Replace the placeholder `sales@chirpypos.example` and `support@chirpypos.example`
addresses before launch.

## Subscription gateway

The website is ready for a hosted checkout flow, but it intentionally does not
mark a subscription paid in the browser. Connect PayMongo, Xendit, Maya
Business, Stripe, or another provider through the Laravel API:

1. The plan button requests a checkout session from Laravel.
2. Laravel creates the subscription with the payment provider.
3. The provider returns a hosted checkout URL.
4. The customer pays on the provider's secure page.
5. A signed provider webhook updates the tenant subscription in Laravel.
6. The POS reads the server entitlement: `trialing`, `active`, `past_due`, or
   `canceled`.

Keep provider secret keys in server environment variables. Never place them in
the React app or Flutter client.
