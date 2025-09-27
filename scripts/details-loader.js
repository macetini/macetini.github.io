import { loadContent } from "./loader-utils.js";

document.addEventListener("DOMContentLoaded", () => {
  // Select all <details> elements with a data-content-url attribute
  const lazyDetails = document.querySelectorAll("details[data-content-url]");

  lazyDetails.forEach((detailsElement) => {
    detailsElement.addEventListener("toggle", () => {
      if (detailsElement.open) {
        const contentContainer = detailsElement.querySelector(
          ".content-placeholder"
        );
        // The element that has the URL is the <details> element itself
        // Pass the detailsElement to loadContent so it can read the URL
        if (contentContainer) {
          loadContent(detailsElement, contentContainer); 
        }
      }
    });
  });
});
