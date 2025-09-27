// Define the function to initialize the lightbox triggers
function initializeLightboxTriggers() {
  const lightbox = document.getElementById("lightbox");
  const lightboxImg = document.getElementById("lightbox-img");
  const closeBtn = document.querySelector(".lightbox-close");
  // Select all triggers, including those loaded dynamically
  const triggers = document.querySelectorAll(".lightbox-trigger");

  // Function to open the lightbox
  triggers.forEach((trigger) => {
    trigger.addEventListener("click", (e) => {
      e.preventDefault();
      const fullImageUrl = trigger.getAttribute("href");
      lightboxImg.setAttribute("src", fullImageUrl);
      lightbox.style.display = "block";
      document.body.style.overflow = 'hidden'; 
    });
  });

  // Safety check for the close button from previous steps
  if (closeBtn) {
    closeBtn.addEventListener("click", () => {
      lightbox.style.display = "none";
      document.body.style.overflow = 'auto'; 
    });
  }

  // Function to close the lightbox when the user clicks anywhere outside the image
  lightbox.addEventListener("click", (e) => {
    if (e.target.classList.contains("lightbox")) {
      lightbox.style.display = "none";
      document.body.style.overflow = 'auto'; 
    }
  });
}

// Call the function initially for any content already in the main index.html file
document.addEventListener("DOMContentLoaded", initializeLightboxTriggers);

// Export the function so other scripts (like summary-loader.js) can call it
export { initializeLightboxTriggers };
