import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import "./styles.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);

// Offline support + installability. Skipped in dev so HMR isn't served stale files.
if ("serviceWorker" in navigator && import.meta.env.PROD) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("./sw.js").catch((err) => console.warn("Service worker registration failed", err));
  });
}

// Ask the browser not to evict our localStorage under storage pressure (Android Chrome honours this for installed PWAs).
navigator.storage?.persist?.().catch(() => {});
