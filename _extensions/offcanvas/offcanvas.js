/**
 * Quarto offcanvas extension: auto-dismiss helper.
 *
 * Each offcanvas with `data-offcanvas-auto-dismiss="<ms>"` is automatically
 * dismissed after the specified number of milliseconds following the
 * `shown.bs.offcanvas` event. The timer is cancelled when the offcanvas is
 * dismissed early (e.g. by clicking the close button or pressing Escape).
 */
(function () {
  "use strict";

  function init() {
    if (typeof window === "undefined" || !window.bootstrap || !window.bootstrap.Offcanvas) {
      return;
    }

    const offcanvases = document.querySelectorAll("[data-offcanvas-auto-dismiss]");
    offcanvases.forEach(function (element) {
      const raw = element.getAttribute("data-offcanvas-auto-dismiss");
      const timeoutMs = parseInt(raw, 10);
      if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
        return;
      }

      let timer = null;

      element.addEventListener("shown.bs.offcanvas", function () {
        if (timer !== null) {
          clearTimeout(timer);
        }
        timer = window.setTimeout(function () {
          const instance = window.bootstrap.Offcanvas.getInstance(element);
          if (instance) {
            instance.hide();
          }
        }, timeoutMs);
      });

      element.addEventListener("hide.bs.offcanvas", function () {
        if (timer !== null) {
          clearTimeout(timer);
          timer = null;
        }
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
