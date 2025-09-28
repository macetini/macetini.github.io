// Call the function initially for any content already in the main index.html file
document.addEventListener("DOMContentLoaded", () => {
  // Define the function to initialize the lightbox triggers
  const lightbox = document.getElementById("lightbox");
  const closeBtn = document.querySelector(".lightbox-close");
  // Select all triggers, including those loaded dynamically

  // Safety check for the close button from previous steps
  if (closeBtn) {
    closeBtn.addEventListener("click", () => {
      lightbox.style.display = "none";
    });
  }

  // Function to close the lightbox when the user clicks anywhere outside the image
  lightbox.addEventListener("click", (e) => {
    if (e.target.classList.contains("lightbox")) {
      lightbox.style.display = "none";
    }
  });
});

// Function to initialize the lightbox triggers
// Export the function so other scripts (like 'loader-utils.js') can call it
export function initializeLightboxTriggers(triggers) {
  if (triggers.length === 0) {
    console.warn("No lightbox triggers found");
    return;
  }

  const lightboxImg = document.getElementById("lightbox-img");

  // Function to open the lightbox
  triggers.forEach((trigger) => {
    trigger.addEventListener("click", (e) => {
      e.preventDefault();
      const fullImageUrl = trigger.getAttribute("href");
      lightboxImg.setAttribute("src", fullImageUrl);
      lightbox.style.display = "flex";
    });
  });
}
