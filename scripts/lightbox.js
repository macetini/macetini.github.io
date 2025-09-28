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
