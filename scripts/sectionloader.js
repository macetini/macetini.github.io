document.addEventListener("DOMContentLoaded", () => {
  // 1. Select all collapsible sections that use lazy loading
  const lazyDetails = document.querySelectorAll("details[data-content-url]");

  lazyDetails.forEach((detailsElement) => {
    // 2. Add an event listener for when the state changes (open/closed)
    detailsElement.addEventListener("toggle", () => {
      if (detailsElement.open) {
        // The section is expanding (opening)

        const contentUrl = detailsElement.getAttribute("data-content-url");
        const contentContainer = detailsElement.querySelector(
          ".content-placeholder"
        );

        // Check if content has already been loaded (to prevent re-loading)
        if (contentContainer.getAttribute("data-loaded") === "true") {
          return; // Content is already there, do nothing
        }

        // 3. Fetch the external HTML content
        fetch(contentUrl)
          .then((response) => {
            // Check for successful response
            if (!response.ok) {
              throw new Error("Network response was not ok");
            }
            return response.text(); // Get the HTML content as text
          })
          .then((html) => {
            // 4. Insert the fetched content into the placeholder
            contentContainer.innerHTML = html;

            // 5. Mark the content as loaded
            contentContainer.setAttribute("data-loaded", "true");
          })
          .catch((error) => {
            console.error("Error loading content:", error);
            contentContainer.innerHTML =
              '<p style="color: red;">Failed to load project details.</p>';
          });
      }
    });
  });
});
