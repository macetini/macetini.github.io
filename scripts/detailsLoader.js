// scripts/detailsLoader.js

import { loadContent } from "./loaderUtils.js";

document.addEventListener("DOMContentLoaded", () => {
  // ... (Code for summary loading is removed here for brevity, but should be in summaryLoader.js) ...

  const lazyDetails = document.querySelectorAll("details[data-content-url]");

  lazyDetails.forEach((detailsElement) => {
    detailsElement.addEventListener("toggle", () => {
      if (detailsElement.open) {
        // --- CRITICAL FIX START ---
        // The element to inject content INTO is the placeholder <div>
        const contentContainer = detailsElement.querySelector(
          ".content-placeholder"
        );

        // The element that has the URL is the <details> element itself
        // Pass the detailsElement to loadContent so it can read the URL
        if (contentContainer) {
          loadContent(detailsElement, contentContainer); // <-- NOW PASSING BOTH ELEMENTS
        }
        // --- CRITICAL FIX END ---
      }
    });
  });
});
