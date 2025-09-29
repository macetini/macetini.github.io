// Call the function initially for any content already in the main index.html file
document.addEventListener("DOMContentLoaded", () => {
  const closeBtn = document.querySelector(".lightbox-close");
  // Safety check for the close button from previous steps
  if (closeBtn) {
    closeBtn.addEventListener("click", () => {
      lightbox.style.display = "none";
    });
  }

  // Define the function to initialize the lightbox triggers
  const lightbox = document.getElementById("lightbox");
  // Function to close the lightbox when the user clicks anywhere outside the image
  lightbox.addEventListener("click", (e) => {
    if (e.target.classList.contains("lightbox")) {
      lightbox.style.display = "none";
    }
  });
});

// Function to initialize the lightbox triggers
export function initializeLightboxTriggers(triggers) {
  if (triggers.length === 0) {
    console.warn("No lightbox triggers found, skipping initialization.");
    return;
  }

  const lightboxImg = document.getElementById("lightbox-img");
  const lightboxVideo = document.getElementById("lightbox-video");

  // Function to open the lightbox
  triggers.forEach((trigger) => {
    trigger.addEventListener("click", (e) => {
      e.preventDefault();

      lightboxImg.style.display = "none";
      lightboxVideo.style.display = "none";
      lightboxVideo.pause(); // Stop any previous video

      const fullMediaUrl = trigger.getAttribute("href");

      if (fullMediaUrl.endsWith(".webm") || fullMediaUrl.endsWith(".mp4")) {
        lightboxVideo.src = fullMediaUrl;
        lightboxVideo.load();
        lightboxVideo.play();
        lightboxVideo.style.display = "flex";
      } else {
        lightboxImg.setAttribute("src", fullMediaUrl);
        lightboxImg.style.display = "flex";
      }

      lightbox.style.display = "flex";
    });
  });
}
