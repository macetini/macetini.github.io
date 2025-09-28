/**
 * Core function to fetch content from a URL specified in the 'data-content-url' attribute
 * and inserts it into the given element.
 */
import { initializeLightboxTriggers } from './lightbox.js'; 

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
      const triggers = element.querySelectorAll(".lightbox-trigger");
      if(triggers.length > 0) {
        initializeLightboxTriggers(triggers); 
      }      
    })
    .catch((error) => {
      console.error("Error loading content:", error);
      element.innerHTML = `<p style="color: red;">Failed to load content: ${error.message}</p>`;
    })
    .finally(() => {
      element.classList.remove("loading");
    });
};
