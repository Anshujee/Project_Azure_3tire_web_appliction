// Next.js 13+ instrumentation hook — runs once on server startup.
// Loaded automatically when next.config.js has `experimental.instrumentationHook: true`.
export async function register() {
  if (
    process.env.NEXT_RUNTIME === 'nodejs' &&
    process.env.APPLICATIONINSIGHTS_CONNECTION_STRING
  ) {
    const appInsights = await import('applicationinsights');
    appInsights.default
      .setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
      .setAutoCollectRequests(true)
      .setAutoCollectPerformance(true)
      .setAutoCollectExceptions(true)
      .setAutoCollectDependencies(true)
      .setAutoCollectConsole(true, true)
      .setSendLiveMetrics(false)
      .start();
  }
}
