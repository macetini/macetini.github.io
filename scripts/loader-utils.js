/**
 * Core function to fetch content from a URL specified in the 'data-content-url' attribute
 * and inserts it into the given element.
 */
import { initializeLightboxTriggers } from "./lightbox.js";

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
      element.innerHTML = html;
      element.setAttribute("data-loaded", "true");

      // Initialize lightbox triggers for any new content, skip if none found (for example, in summaries without trigger images)
      const lightboxTriggers = element.querySelectorAll(".lightbox-trigger");
      if (lightboxTriggers.length > 0) {
        initializeLightboxTriggers(lightboxTriggers);
      }

      const detailTriggers = element.querySelectorAll(".project-banner");
      if (detailTriggers.length > 0) {
        initializeDetailTriggers(detailTriggers);
      }
    })
    .catch((error) => {
      console.error("Error loading content:", error);
      element.innerHTML = `<p style="color: red;">Failed to load content: ${error.message}</p>`;
    })
    .finally(() => {
      element.classList.remove("loading");
    });
}

function initializeDetailTriggers(triggers) {
  triggers.forEach((trigger) => {
    trigger.addEventListener("click", (e) => {
      e.preventDefault();
      const detailsId = trigger.id.replace("-banner", "-details");
      const detailsElement = document.getElementById(detailsId);
      if (!detailsElement) {
        console.warn(`No details element found with ID: ${detailsId}`);
        return;
      }
      detailsElement.open = !detailsElement.open;
    });
  });
}
