import { httpRouter } from 'convex/server';
import { httpAction } from './_generated/server';

const http = httpRouter();

// Convex serves HTTP actions on the deployment's .convex.site hostname.
// This confirms the HTTP handler is reachable; it does not test Bird or auth.
http.route({
  path: '/health',
  method: 'GET',
  handler: httpAction(async () => Response.json(
    { ok: true, service: 'pester-ai', stage: 'preview' },
    { headers: { 'Cache-Control': 'no-store' } },
  )),
});

export default http;
