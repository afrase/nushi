/// Whether a newer version of the app waits to replace the one running,
/// read from the service worker's registration whenever one of its workers
/// is installed: one waits while another is active. A fresh install's
/// first worker is "installed" too, with nothing active, on its way to
/// taking over at once (sw.js), and the page may be controlled by then:
/// asking whether the page had a controller took that for an update.
bool updateWaits({required bool waiting, required bool active}) =>
    waiting && active;
