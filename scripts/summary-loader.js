// Handles immediate, static content loading.
import { loadContent } from "./loader-utils.js";

document.addEventListener("DOMContentLoaded", () => {
  const summaryPlaceholders = document.querySelectorAll(".summary-placeholder");

  if (summaryPlaceholders.length === 0) {
    console.warn("No Elements found with a class 'summary-placeholder'");
    return;
  }

  [...summaryPlaceholders].forEach((summaryElement) => {
    loadContent(summaryElement);
  });
});
