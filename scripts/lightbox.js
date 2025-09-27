document.addEventListener("DOMContentLoaded", () => {
  const lightbox = document.getElementById("lightbox");
  const lightboxImg = document.getElementById("lightbox-img");
  const closeBtn = document.querySelector(".lightbox-close");
  const triggers = document.querySelectorAll(".lightbox-trigger");

  // Function to open the lightbox
  triggers.forEach((trigger) => {
    trigger.addEventListener("click", (e) => {
      // Prevent the browser from navigating to the image URL
      e.preventDefault();

      // Get the full image URL from the anchor's href
      const fullImageUrl = trigger.getAttribute("href");

      // Set the image source and display the lightbox
      lightboxImg.setAttribute("src", fullImageUrl);
      lightbox.style.display = "block";
    });
  });

  // Function to close the lightbox when the 'X' is clicked
  closeBtn.addEventListener("click", () => {
    lightbox.style.display = "none";
  });

  // Function to close the lightbox when the user clicks anywhere outside the image
  lightbox.addEventListener("click", (e) => {
    if (e.target.classList.contains("lightbox")) {
      lightbox.style.display = "none";
    }
  });
});
