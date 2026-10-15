const setupEventPagination = () => {
  const link = document.querySelector("[data-events-load-more]");
  if (!link || link.dataset.paginationInitialized) return;

  link.dataset.paginationInitialized = "true";
  let loading = false;
  let paginationObserver = null;

  const loadNextPage = async () => {
    if (loading || !link.isConnected) return;

    loading = true;
    link.setAttribute("aria-busy", "true");

    try {
      const response = await fetch(link.href, {
        headers: { "X-Requested-With": "XMLHttpRequest" }
      });
      if (!response.ok) throw new Error(`Event loading failed: ${response.status}`);

      const cards = await response.text();
      document.querySelector(".events-grid").insertAdjacentHTML("beforeend", cards);

      const nextPage = response.headers.get("X-Next-Page");
      if (nextPage) {
        link.href = nextPage;
        link.textContent = "Load more events";
        paginationObserver?.unobserve(link);
        paginationObserver?.observe(link);
      } else {
        paginationObserver?.unobserve(link);
        link.remove();
      }
    } catch (error) {
      console.error(error);
      link.textContent = "Could not load events. Try again";
    } finally {
      loading = false;
      link.removeAttribute("aria-busy");
    }
  };

  link.addEventListener("click", (event) => {
    event.preventDefault();
    loadNextPage();
  });

  if ("IntersectionObserver" in window) {
    paginationObserver = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) loadNextPage();
    }, { rootMargin: "300px" });
    paginationObserver.observe(link);
  }
};

document.addEventListener("DOMContentLoaded", setupEventPagination);
document.addEventListener("turbo:load", setupEventPagination);
