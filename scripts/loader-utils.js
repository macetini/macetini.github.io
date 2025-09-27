/**
 * Core function to fetch content from a URL specified in the 'data-content-url' attribute
 * and inserts it into the given element.
 */
import { initializeLightboxTriggers } from './lightbox.js'; 

export const loadContent = (element) => {
  // ... [The entire loadContent function logic remains here, unchanged] ...

  const contentUrl = element.getAttribute("data-content-url");

  // Safety check: Don't load if no URL is present or already loaded
  if (!contentUrl || element.getAttribute("data-loaded") === "true") {
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

      initializeLightboxTriggers(); 
    })
    .catch((error) => {
      console.error("Error loading content:", error);
      element.innerHTML = `<p style="color: red;">Failed to load content: ${error.message}</p>`;
    })
    .finally(() => {
      element.classList.remove("loading");
    });
};
