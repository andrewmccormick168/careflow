import React from "react";

type Props = { children: React.ReactNode };
type State = { hasError: boolean };

/**
 * Top-level error boundary. No external error-monitoring integration is
 * enabled by default, and no sensitive data
 * should ever be included in what this renders or logs (see
 * docs/architecture.md audit/logging notes on not leaking
 * invitation tokens or medical detail into any logging surface,
 * which applies equally to client-side error reporting later).
 */
export class AppErrorBoundary extends React.Component<Props, State> {
  override state: State = { hasError: false };

  static getDerivedStateFromError(): State {
    return { hasError: true };
  }

  override componentDidCatch(error: unknown) {
    console.error("Unhandled application error:", error);
  }

  override render() {
    if (this.state.hasError) {
      return (
        <div className="flex min-h-screen items-center justify-center bg-background p-6">
          <div className="max-w-md rounded-card border border-border bg-surface p-6 text-center">
            <h1 className="text-lg font-semibold text-ink">Something went wrong</h1>
            <p className="mt-2 text-sm text-muted">
              Please refresh the page. If this keeps happening, contact your administrator.
            </p>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}
