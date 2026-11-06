/* Animaciones: transición entre páginas, barra de progreso y efecto onda en botones */
(function () {
  // Barra de progreso
  const bar = document.createElement("div");
  bar.className = "page-progress";
  document.body.appendChild(bar);
  function runBar() {
    bar.classList.remove("run");
    void bar.offsetWidth; // reinicia la animación
    bar.classList.add("run");
  }

  // Transición de salida antes de cambiar de página
  const originalGo = window.go;
  let busy = false;
  window.go = function (view) {
    const current = document.querySelector(".view.active");
    const target = document.getElementById("view-" + view);
    if (busy || !current || !target || current === target ||
        window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      return originalGo(view);
    }
    busy = true;
    runBar();
    current.classList.add("leaving");
    setTimeout(() => {
      current.classList.remove("leaving");
      originalGo(view);
      busy = false;
    }, 180);
  };

  // Efecto onda en botones
  document.addEventListener("pointerdown", e => {
    const btn = e.target.closest(".btn, .nav-link, .action-btn, .text-button, .chatbot-options button");
    if (!btn) return;
    const r = btn.getBoundingClientRect();
    const size = Math.max(r.width, r.height);
    const span = document.createElement("span");
    span.className = "ripple";
    span.style.width = span.style.height = size + "px";
    span.style.left = e.clientX - r.left - size / 2 + "px";
    span.style.top = e.clientY - r.top - size / 2 + "px";
    btn.appendChild(span);
    span.addEventListener("animationend", () => span.remove());
  });
})();
