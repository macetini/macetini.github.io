import { initializeLightboxTriggers } from "./lightbox.js";
import { initializeDetailTriggers } from "./details-loader.js";

// Exported function to load content into a specified element
export function loadContent(element) {
  const contentUrl = element.getAttribute("data-content-url");

  // Safety check: Don't load if no URL is present or already loaded
  if (!contentUrl || element.getAttribute("data-loaded") === "true") {
    console.warn("No content URL found or already loaded");
    return;
  }

  element.classList.add("loading");

  fetch(contentUrl)
    .then((response) => {
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }
      return response.text();
    })
    .then((html) => {
      onHtmlLoaded(html, element);
    })
    .catch((error) => {
      console.error("Error loading content:", error);
      element.innerHTML = `<p style="color: red;">Failed to load content: ${error.message}</p>`;
    })
    .finally(() => {
      element.classList.remove("loading");
    });
}

// Function to handle the loaded HTML content
function onHtmlLoaded(html, element) {
  element.innerHTML = html;
  element.setAttribute("data-loaded", "true");

  // Initialize lightbox triggers for any new content, skip if none found (for example, in summaries without trigger images)
  const lightboxTriggers = element.querySelectorAll(".lightbox-trigger");
  if (lightboxTriggers.length > 0) {
    initializeLightboxTriggers(lightboxTriggers);
  }

  // Initialize detail triggers for any new content, skip if none found (for example, in summaries without banner)
  const detailTriggers = element.querySelectorAll(".detail-trigger");
  if (detailTriggers.length > 0) {
    initializeDetailTriggers(detailTriggers);
  }
}