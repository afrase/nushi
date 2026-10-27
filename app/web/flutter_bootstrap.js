{{flutter_js}}
{{flutter_build_config}}

// Everything from this origin (the relay's CSP): CanvasKit and the
// fallback fonts are bundled, never fetched from Google's servers. Flutter
// draws into #app, which app.css keeps inside the safe area.
const config = {
  canvasKitBaseUrl: "canvaskit/",
  canvasKitVariant: "full",
  fontFallbackBaseUrl: "assets/fonts/fallback/",
  hostElement: document.querySelector("#app"),
};
_flutter.loader.load({
  config: config,
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine(config);
    await appRunner.runApp();
  },
});
