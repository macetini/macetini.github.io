// Handles immediate, static content loading.

import { loadContent } from "./loaderUtils.js";

document.addEventListener("DOMContentLoaded", () => {
  const summaryPlaceholder = document.getElementById(
    "procedural-dungeon-summary"
  );

  if (summaryPlaceholder) {
    // Only one job: load the summary immediately on page load
    loadContent(summaryPlaceholder);
  }
});
