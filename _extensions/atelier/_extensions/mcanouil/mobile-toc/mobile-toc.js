/**
 * Mobile TOC - Narrow-screen table of contents
 * Shows the table of contents as a pill and a bottom sheet on narrow screens.
 *
 * @license MIT
 * @copyright 2026 Mickaël Canouil
 * @author Mickaël Canouil
 */

/*
 * Upstream: https://github.com/quarto-dev/quarto-cli/issues/5961
 * Remove when: the minimum Quarto version includes the fix.
 * Quarto hides the side table of contents below the Bootstrap md breakpoint
 * and shows nothing in its place.
 * Below that width, add a pill that opens a copy of the list in a bottom sheet.
 */
(() => {
  const SHEET_ID = "mobile-toc-sheet";

  const readCloseLabel = () => {
    const raw = document.getElementById("mobile-toc-options")?.textContent;
    try {
      return JSON.parse(raw)?.labels?.close || "Close";
    } catch (error) {
      console.error("mobile-toc: cannot read #mobile-toc-options.", error);
      return "Close";
    }
  };

  const start = () => {
    const toc = document.querySelector("#quarto-margin-sidebar nav#TOC, #quarto-sidebar-toc-left nav#TOC");
    const list = toc?.querySelector(":scope > ul");
    if (
      !list ||
      document.getElementById("TOC-body") ||
      typeof window.HTMLDialogElement?.prototype.showModal !== "function" ||
      list.querySelectorAll("a").length < 2
    ) {
      return;
    }

    const label = toc.querySelector("#toc-title")?.textContent.trim() || "Contents";
    const closeLabel = readCloseLabel();
    const breakpoint =
      getComputedStyle(document.documentElement).getPropertyValue("--bs-breakpoint-md").trim() || "768px";
    const narrow = window.matchMedia(`(width < ${breakpoint})`);

    const build = () => {
      const sheet = document.createElement("dialog");
      sheet.id = SHEET_ID;
      sheet.className = "mobile-toc-sheet";
      sheet.setAttribute("aria-labelledby", "mobile-toc-sheet-label");

      const header = document.createElement("div");
      header.className = "mobile-toc-sheet-header";
      const sheetLabel = document.createElement("span");
      sheetLabel.id = "mobile-toc-sheet-label";
      sheetLabel.className = "mobile-toc-sheet-label";
      sheetLabel.textContent = label;
      const close = document.createElement("button");
      close.type = "button";
      close.className = "mobile-toc-close";
      close.setAttribute("aria-label", closeLabel);
      close.innerHTML = '<i class="bi bi-x-lg" aria-hidden="true"></i>';
      header.append(sheetLabel, close);
      const landmark = document.createElement("nav");
      landmark.setAttribute("aria-labelledby", "mobile-toc-sheet-label");
      sheet.append(header, landmark);

      let copy = null;
      const mount = () => {
        const fresh = list.cloneNode(true);
        [fresh, ...fresh.querySelectorAll("[id], [inert]")].forEach((el) => {
          el.removeAttribute("id");
          el.inert = false;
        });
        const focusedHref = copy?.contains(document.activeElement)
          ? document.activeElement.getAttribute("href")
          : null;
        if (copy) copy.replaceWith(fresh);
        else landmark.append(fresh);
        copy = fresh;
        markCurrent();
        if (focusedHref) {
          [...copy.querySelectorAll("a")].find((a) => a.getAttribute("href") === focusedHref)?.focus();
        }
      };
      const markCurrent = () => {
        copy.querySelectorAll("a[aria-current]").forEach((a) => a.removeAttribute("aria-current"));
        const active = copy.querySelectorAll("a.active");
        active[active.length - 1]?.setAttribute("aria-current", "location");
      };
      const MIRRORED = ["class", "hidden"];
      const mirrorState = () => {
        const selector = "ul, li, a";
        const source = list.querySelectorAll(selector);
        const target = copy.querySelectorAll(selector);
        source.forEach((el, index) => {
          for (const name of MIRRORED) {
            const value = el.getAttribute(name);
            if (target[index].getAttribute(name) === value) continue;
            if (value === null) target[index].removeAttribute(name);
            else target[index].setAttribute(name, value);
          }
        });
        markCurrent();
      };
      mount();
      const HEADING = ":is(h1, h2, h3, h4, h5, h6)";
      const focusHeading = (id) => {
        const target = document.getElementById(id);
        const active = document.activeElement;
        if (!target || (active !== document.body && !active?.classList.contains("mobile-toc-pill"))) return;
        const heading = target.matches(HEADING) ? target : target.querySelector(`:scope > ${HEADING}`) || target;
        if (!heading.hasAttribute("tabindex")) {
          heading.setAttribute("tabindex", "-1");
          heading.addEventListener("blur", () => heading.removeAttribute("tabindex"), { once: true });
        }
        heading.focus({ preventScroll: true });
      };
      const isPlainSamePageClick = (event, link) =>
        !event.defaultPrevented &&
        !(event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) &&
        link.origin + link.pathname === location.origin + location.pathname;
      // A click on the backdrop targets the dialog itself, as does a click on its padding.
      // Close only when the point is outside the dialog box.
      const onBackdrop = (event) => {
        if (event.target !== sheet) return false;
        const box = sheet.getBoundingClientRect();
        return (
          event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom
        );
      };
      sheet.addEventListener("click", (event) => {
        if (onBackdrop(event)) {
          sheet.close();
          return;
        }
        const link = event.target.closest("a");
        if (!link) return;
        sheet.close();
        if (!isPlainSamePageClick(event, link)) return;
        let id;
        try {
          id = decodeURIComponent(link.hash.slice(1));
        } catch {
          return;
        }
        requestAnimationFrame(() => focusHeading(id));
      });

      // Other scripts may add children inside TOC links, so a copy paired by position can drift.
      // Clone the list again on any child change, and copy only classes and hidden otherwise.
      // Both are coalesced to one update for each animation frame.
      let frame = 0;
      let reclone = false;
      const observer = new MutationObserver((records) => {
        if (records.some((record) => record.type === "childList")) reclone = true;
        if (frame) return;
        frame = requestAnimationFrame(() => {
          frame = 0;
          if (reclone) mount();
          else mirrorState();
          reclone = false;
        });
      });
      observer.observe(list, {
        subtree: true,
        childList: true,
        attributes: true,
        attributeFilter: MIRRORED,
      });

      const pill = document.createElement("button");
      pill.type = "button";
      pill.className = "mobile-toc-pill";
      pill.setAttribute("aria-haspopup", "dialog");
      pill.setAttribute("aria-controls", SHEET_ID);
      pill.setAttribute("aria-expanded", "false");
      pill.innerHTML = '<i class="bi bi-list-nested" aria-hidden="true"></i>';
      const pillLabel = document.createElement("span");
      pillLabel.className = "mobile-toc-pill-label";
      pillLabel.textContent = label;
      pill.append(pillLabel);
      close.addEventListener("click", () => sheet.close());
      const main = document.querySelector("#quarto-content > main") ?? document.querySelector("main");
      if (main) main.before(pill, sheet);
      else document.body.append(pill, sheet);

      const root = document.documentElement;
      const writePillHeight = () => {
        root.style.setProperty("--mobile-toc-pill-height", `${pill.getBoundingClientRect().height}px`);
      };
      const pillObserver = new ResizeObserver(writePillHeight);
      pillObserver.observe(pill);

      // Content wider than the screen widens the layout viewport on a phone,
      // and a fixed element follows its far edge off screen.
      // Offset the pill, the sheet and back-to-top by the gap to the visual viewport.
      // A hidden fixed box measures the area that fixed elements use, which leaves out
      // a classic desktop scrollbar.
      const viewport = window.visualViewport;
      const listeners = new AbortController();
      let placeFrame = 0;
      let area = null;
      if (viewport) {
        const { signal } = listeners;
        area = document.createElement("div");
        area.setAttribute("aria-hidden", "true");
        area.style.cssText =
          "display: block; position: fixed; inset: 0; margin: 0; padding: 0; border: 0; " +
          "width: auto; height: auto; min-width: 0; min-height: 0; max-width: none; max-height: none; " +
          "visibility: hidden; pointer-events: none;";
        document.body.append(area);
        const apply = () => {
          placeFrame = 0;
          const box = area.getBoundingClientRect();
          const offsetX = box.right - (viewport.offsetLeft + viewport.width);
          const offsetY = box.bottom - (viewport.offsetTop + viewport.height);
          const offsetLeft = viewport.offsetLeft - box.left;
          root.style.setProperty("--mobile-toc-offset-x", `${Math.max(0, offsetX)}px`);
          root.style.setProperty("--mobile-toc-offset-y", `${Math.max(0, offsetY)}px`);
          root.style.setProperty("--mobile-toc-offset-left", `${Math.max(0, offsetLeft)}px`);
        };
        const place = () => {
          if (!placeFrame) placeFrame = requestAnimationFrame(apply);
        };
        viewport.addEventListener("resize", place, { signal });
        viewport.addEventListener("scroll", place, { signal });
        window.addEventListener("resize", place, { signal });
        window.addEventListener("scroll", place, { signal, passive: true });
        window.addEventListener("load", place, { signal });
        apply();
      }

      // showModal() focuses the first control while the sheet still slides in from below the screen,
      // and on a zoomed page that focus pans the visual viewport.
      // A hidden sheet has no control to focus, so focus the start link afterwards, without a scroll.
      pill.addEventListener("click", () => {
        if (sheet.open) return;
        sheet.style.visibility = "hidden";
        sheet.showModal();
        sheet.style.removeProperty("visibility");
        pill.setAttribute("aria-expanded", "true");
        const link = copy.querySelector("a[aria-current]") || copy.querySelector("a");
        if (!link) return;
        const box = sheet.getBoundingClientRect();
        const linkBox = link.getBoundingClientRect();
        if (linkBox.top < box.top) sheet.scrollTop += linkBox.top - box.top;
        else if (linkBox.bottom > box.bottom) sheet.scrollTop += linkBox.bottom - box.bottom;
        link.focus({ preventScroll: true });
      });
      sheet.addEventListener("close", () => {
        pill.setAttribute("aria-expanded", "false");
        // Safari does not focus a button on tap, so close() would otherwise leave focus on the body.
        if (document.activeElement === document.body || sheet.contains(document.activeElement)) pill.focus();
      });

      return () => {
        listeners.abort();
        pillObserver.disconnect();
        cancelAnimationFrame(placeFrame);
        area?.remove();
        ["pill-height", "offset-x", "offset-y", "offset-left"].forEach((name) =>
          root.style.removeProperty(`--mobile-toc-${name}`),
        );
        observer.disconnect();
        cancelAnimationFrame(frame);
        if (sheet.open) sheet.close();
        pill.remove();
        sheet.remove();
      };
    };

    let teardown = null;
    const sync = () => {
      if (narrow.matches && !teardown) teardown = build();
      if (!narrow.matches && teardown) {
        teardown();
        teardown = null;
      }
    };
    sync();
    narrow.addEventListener("change", sync);
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
