import { QueryClient } from "@tanstack/react-query";

/**
 * Every query key for tenant-scoped data MUST start with
 * ['company', activeCompanyId, ...] — see docs/architecture.md §5.
 * This prevents cross-tenant cache collisions and makes stale-company
 * data structurally unaddressable after a company switch, in addition
 * to the explicit queryClient.clear() performed on switch (see
 * src/lib/companyContext.ts once Phase 1 wires it up).
 */
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      staleTime: 30_000,
    },
  },
});
