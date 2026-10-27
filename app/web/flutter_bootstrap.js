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
// The loading line: a longer wait said after a while, any failure shown.
const loading = document.querySelector("#loading");
const line = document.querySelector("#loading-text");
const slow = setTimeout(() => {
  line.textContent = "Loading Nushi… The first time takes up to a minute.";
}, 6000);
function failed(why) {
  clearTimeout(slow);
  loading.classList.add("failed");
  line.textContent = "Nushi couldn't start: " + why;
}
window.addEventListener("error", (e) => failed(e.message || "an error"));
window.addEventListener("unhandledrejection", (e) =>
  failed(String((e.reason && e.reason.message) || e.reason)));
_flutter.loader.load({
  config: config,
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine(config);
    await appRunner.runApp();
    clearTimeout(slow);
    loading.remove();
  },
});
