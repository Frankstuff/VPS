import './main';
import { ConvexHttpClient } from 'convex/browser';
import { api } from '../convex/_generated/api';

const deploymentUrl = import.meta.env.VITE_CONVEX_URL?.trim();
const availability = document.querySelector<HTMLElement>('[data-program-availability]');

// The static text remains useful if the backend is not configured or reachable.
// This is a single read of public metadata: no form choices or personal data.
if (deploymentUrl && availability) {
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), 8000);

  void (async () => {
    try {
      const client = new ConvexHttpClient(deploymentUrl, {
        fetch: (input, init) => fetch(input, { ...init, signal: controller.signal }),
      });
      const status = await client.query(api.program.getPublicStatus, {});
      if (status.stage === 'preview' && status.smsEnrollmentOpen === false) {
        availability.textContent = 'Enrollment is not open. You can explore the signup preview.';
        availability.dataset.statusSource = 'convex';
      }
    } catch {
      // No loss of functionality: this page is still a static program preview.
      if (import.meta.env.DEV) console.warn('Program status is unavailable; showing the static preview notice.');
    } finally {
      window.clearTimeout(timeout);
    }
  })();
}
