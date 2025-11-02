import { initializeLightboxTriggers } from "./lightbox.js";
import { initializeDetailTriggers } from "./details-loader.js";

// Exported function to load content into a specified element
export function loadContent(element) {
  const contentUrl = element.dataset.contentUrl;

  // Safety check: Don't load if no URL is present or already loaded
  if (!contentUrl || element.dataset.loaded === "true") {
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
  element.dataset.loaded = "true";

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

  const copyButtons = document.querySelectorAll(".copy-code-button");
  for (const button of copyButtons) {
    button.addEventListener("click", (event) => {
      copyShaderCode(event, "code-details-" + button.dataset.codeId);
    });
  }

  const closeButtons = document.querySelectorAll(".close-code-button");
  for (const element of closeButtons) {
    element.addEventListener("click", () => {
      const detailsId = element.dataset.codeId;
      const detailsElement = document.getElementById(detailsId);
      if (detailsElement) {
        detailsElement.open = false;
        detailsElement.scrollIntoView({ behavior: "instant", block: "center" });
      } else {
        console.warn(`No details element found with ID: ${detailsId}`);
      }
    });
  }

  const codeBlocks = document.querySelectorAll("code[data-src]");

  for (const codeElement of codeBlocks) {
    const filePath = codeElement.dataset.src;

    fetch(filePath)
      .then((response) => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.text();
      })
      .then((fileContent) => {
        // Ensure the content is HTML-escaped before injection
        codeElement.textContent = fileContent;
      })
      .catch((error) => {
        codeElement.textContent = `Error loading file: ${filePath}`;
        console.error("Fetch error:", error);
      });
  }
}

function copyShaderCode(event, detailsId) {
  // 1. Stop the click event from toggling the <details> state
  //    We only want the button to copy, not expand/collapse the section.
  event.stopPropagation();

  // 2. Find the code content associated with this details block
  const detailsElement = document.getElementById(detailsId);
  const codeElement = detailsElement.querySelector("code");

  // Ensure the code element exists and get its text content
  if (!codeElement) {
    console.error("Could not find code element to copy.");
    return;
  }

  const codeText = codeElement.textContent;
  const button = event.currentTarget;
  const originalText = button.textContent;

  // 3. Use the Clipboard API to copy the text
  navigator.clipboard
    .writeText(codeText)
    .then(() => {
      // 4. Provide feedback to the user
      button.textContent = "Copied!";
      button.style.backgroundColor = "#28a745"; // Success color

      // 5. Revert the button text after a short delay
      setTimeout(() => {
        button.textContent = originalText;
        button.style.backgroundColor = "#555";
      }, 1500);
    })
    .catch((err) => {
      console.error("Failed to copy text: ", err);
      // Fallback or error message could go here
    });
}
