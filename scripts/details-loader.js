import { loadContent } from "./loader-utils.js";

document.addEventListener("DOMContentLoaded", () => {
  // Select all <details> elements with a data-content-url attribute
  const lazyDetails = document.querySelectorAll("details[data-content-url]");

  if (lazyDetails.length === 0) {
    console.warn(
      "No <details> elements found with a 'data-content-url' attribute"
    );
    return;
  }

  lazyDetails.forEach((detailsElement) => {
    detailsElement.addEventListener("toggle", (e) => {
      e.stopPropagation();
      if (detailsElement.open) {
        const contentContainer = detailsElement.querySelector(
          ".content-placeholder"
        );
        // The element that has the URL is the <details> element itself
        // Pass the detailsElement to loadContent so it can read the URL
        // If content already loaded, loadContent will skip reloading
        if (contentContainer) {
          loadContent(detailsElement);
        }
      }
    });
  });
});

// Function to initialize the detail triggers
export function initializeDetailTriggers(triggers) {
  triggers.forEach((trigger) => {
    trigger.addEventListener("click", (e) => {
      e.stopPropagation();
      const detailsId = trigger.getAttribute("data-target-id");
      const detailsElement = document.getElementById(detailsId);
      if (!detailsElement) {
        console.warn(`No details element found with ID: ${detailsId}`);
        return;
      }
      detailsElement.open = !detailsElement.open;
      if (!detailsElement.open) {
        // Optionally, scroll back to the trigger after closing
        detailsElement.scrollIntoView({ behavior: "instant", block: "center" });
      }
    });
  });
}
