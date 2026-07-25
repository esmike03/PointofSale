"use client";

import Image from "next/image";
import {
  ArrowRight,
  BadgeCheck,
  Banknote,
  BarChart3,
  Boxes,
  Check,
  ChevronDown,
  Cloud,
  CreditCard,
  FileText,
  Menu,
  Monitor,
  MonitorSmartphone,
  PackageCheck,
  QrCode,
  ReceiptText,
  ShieldCheck,
  ShoppingCart,
  Smartphone,
  Store,
  TrendingUp,
  WifiOff,
  X,
} from "lucide-react";
import { useEffect, useRef, useState } from "react";

// Desktop horizontal-scroll mode. Set to false (or remove the matching
// "DESKTOP HORIZONTAL SCROLL MODE" block in globals.css) to fully revert
// to normal vertical scrolling.
const HORIZONTAL_SCROLL = true;

const navigation = [
  { label: "Product", href: "#product" },
  { label: "Features", href: "#features" },
  { label: "Pricing", href: "#pricing" },
  { label: "FAQ", href: "#faq" },
];

// Animated icons, exported greyscale at 150px (see public/icons).
const features = [
  {
    icon: "/icons/shopping-cart.webp",
    title: "Fast checkout",
    copy: "Scan, discount, and split payments.",
  },
  {
    icon: "/icons/management.webp",
    title: "Live inventory",
    copy: "Track stock with low-stock alerts.",
  },
  {
    icon: "/icons/analytics.webp",
    title: "Clear analytics",
    copy: "See sales, margins, and best sellers.",
  },
  {
    icon: "/icons/fifo.webp",
    title: "Easy returns",
    copy: "Find any sale by receipt number.",
  },
  {
    icon: "/icons/credit-card.webp",
    title: "Credit and expenses",
    copy: "Track customer credit and store costs.",
  },
  {
    icon: "/icons/copy.webp",
    title: "Receipt ready",
    copy: "Your store name and logo on every receipt.",
  },
];

const plans = [
  {
    name: "Starter",
    price: "7,990",
    description: "For a small shop running one counter.",
    features: ["1 register", "1 desktop + 1 mobile", "Inventory and sales", "Offline selling", "Email support"],
  },
  {
    name: "Business",
    price: "14,990",
    description: "For growing stores that need more control.",
    features: ["Up to 3 registers", "Unlimited products", "Analytics and reports", "Credits and expenses", "Priority support"],
    featured: true,
  },
  {
    name: "Scale",
    price: "Custom",
    description: "For multi-branch operations and tailored rollout.",
    features: ["Multiple branches", "Team permissions", "Central reporting", "Guided onboarding", "Custom integrations"],
  },
];

const faqs = [
  {
    question: "Does TRX POS work without internet?",
    answer:
      "Yes. The installed app can keep checkout and inventory operations available locally, then synchronize permitted changes when the connection returns.",
  },
  {
    question: "Is the price really one-time?",
    answer:
      "Yes. Each plan is a single payment per store, with no monthly billing. A provider such as PayMongo, Xendit, Maya Business, or Stripe can handle the checkout, and secure webhooks in the backend then unlock that store's plan and feature access permanently.",
  },
  {
    question: "Can desktop and mobile use the same store data?",
    answer:
      "Yes. Devices can share cloud data while online and retain an offline-ready local workspace. Sync rules prevent one device from silently overwriting another device's transaction history.",
  },
  {
    question: "Is the POS automatically BIR permitted?",
    answer:
      "No. Software features and a store's tax registration do not by themselves make a POS BIR-permitted. TRX POS can label non-permitted output clearly while a store issues its separate authorized invoice.",
  },
];

function BrandMark() {
  return (
    <span className="brand-mark" aria-hidden="true">
      <Store size={20} strokeWidth={2.2} />
    </span>
  );
}

const previewTabs = [
  { id: "checkout", icon: ShoppingCart, label: "Checkout", kicker: "COUNTER 01", title: "New sale" },
  { id: "inventory", icon: Boxes, label: "Inventory", kicker: "STOCK LEVELS", title: "Inventory" },
  { id: "analytics", icon: BarChart3, label: "Analytics", kicker: "TODAY", title: "Performance" },
  { id: "receipts", icon: ReceiptText, label: "Receipts", kicker: "HISTORY", title: "Receipts" },
];

const previewProducts = [
  { name: "House Blend", price: "₱180.00", stock: "38 in stock", tone: "mint" },
  { name: "Cold Brew", price: "₱145.00", stock: "24 in stock", tone: "ink" },
  { name: "Oat Cookie", price: "₱75.00", stock: "16 in stock", tone: "amber" },
  { name: "Iced Latte", price: "₱165.00", stock: "27 in stock", tone: "mint" },
  { name: "Butter Croissant", price: "₱120.00", stock: "12 in stock", tone: "amber" },
];

const previewStock = [
  { name: "House Blend", count: "38", status: "In stock", tone: "" },
  { name: "Cold Brew", count: "24", status: "In stock", tone: "" },
  { name: "Oat Cookie", count: "16", status: "Low", tone: "low" },
  { name: "Almond Milk", count: "6", status: "Low", tone: "low" },
  { name: "Espresso Beans", count: "0", status: "Out", tone: "out" },
];

// Screen insets for each mockup are measured from the cropped artwork and
// live in globals.css alongside .device-frame.laptop / .device-frame.phone.
const deviceViews = [
  { id: "laptop", label: "Desktop", icon: Monitor, src: "/laptop-mockup.png", width: 1628, height: 935 },
  { id: "phone", label: "Mobile", icon: Smartphone, src: "/phone-mockup.png", width: 754, height: 1555 },
];

const salesChart = [
  { day: "Mon", value: 48 },
  { day: "Tue", value: 61 },
  { day: "Wed", value: 44 },
  { day: "Thu", value: 76 },
  { day: "Fri", value: 87 },
  { day: "Sat", value: 100, peak: true },
  { day: "Sun", value: 69 },
];

// Percentage coordinates in a 0-100 box; y is inverted so 0 sits at the top.
const chartPoints = salesChart.map((point, index) => ({
  ...point,
  x: (index / (salesChart.length - 1)) * 100,
  y: 100 - point.value,
}));

// Catmull-Rom control points give the line a smooth curve through each value.
function buildCurve(points: { x: number; y: number }[]) {
  let path = `M ${points[0].x} ${points[0].y}`;
  for (let i = 0; i < points.length - 1; i += 1) {
    const previous = points[i - 1] ?? points[i];
    const start = points[i];
    const end = points[i + 1];
    const next = points[i + 2] ?? end;
    const c1x = start.x + (end.x - previous.x) / 6;
    const c1y = start.y + (end.y - previous.y) / 6;
    const c2x = end.x - (next.x - start.x) / 6;
    const c2y = end.y - (next.y - start.y) / 6;
    path += ` C ${c1x.toFixed(2)} ${c1y.toFixed(2)}, ${c2x.toFixed(2)} ${c2y.toFixed(2)}, ${end.x.toFixed(2)} ${end.y.toFixed(2)}`;
  }
  return path;
}

const salesLinePath = buildCurve(chartPoints);
const salesAreaPath = `${salesLinePath} L 100 100 L 0 100 Z`;

const previewReceipts = [
  { id: "TRX-004821", meta: "10:24 AM · 3 items", amount: "₱435.00" },
  { id: "TRX-004820", meta: "10:11 AM · 1 item", amount: "₱180.00" },
  { id: "TRX-004819", meta: "09:58 AM · 8 items", amount: "₱1,240.00" },
  { id: "TRX-004818", meta: "09:42 AM · 1 item", amount: "₱75.00" },
];

function ProductPreview() {
  const [activeTab, setActiveTab] = useState("checkout");
  const tab = previewTabs.find((item) => item.id === activeTab) ?? previewTabs[0];

  return (
    <div className="product-preview" aria-label="TRX POS product interface preview">
      <div className="preview-sidebar">
        <BrandMark />
        {previewTabs.map((item) => {
          const Icon = item.icon;
          return (
            <button
              type="button"
              key={item.id}
              className={`preview-nav ${activeTab === item.id ? "active" : ""}`}
              onClick={() => setActiveTab(item.id)}
              aria-label={`Preview ${item.label}`}
              aria-pressed={activeTab === item.id}
            >
              <Icon size={17} />
            </button>
          );
        })}
      </div>
      <div className="preview-main">
        <div className="preview-topbar">
          <div>
            <span className="preview-kicker">{tab.kicker}</span>
            <strong>{tab.title}</strong>
          </div>
          <span className="status-pill"><span /> Online</span>
        </div>

        {activeTab === "checkout" && (
          <div className="preview-content">
            <div className="preview-products">
              <div className="preview-search">Search product or scan barcode</div>
              <div className="preview-product-list">
                {previewProducts.map((product) => (
                  <div className="preview-product" key={product.name}>
                    <span className={`product-swatch ${product.tone}`} />
                    <div className="product-meta">
                      <strong>{product.name}</strong>
                      <small>{product.stock}</small>
                    </div>
                    <span className="product-price">{product.price}</span>
                  </div>
                ))}
              </div>
            </div>
            <div className="preview-cart">
              <div className="cart-heading">
                <strong>Current order</strong>
                <span>3 items</span>
              </div>
              <div className="cart-row"><span>House Blend × 2</span><strong>₱360.00</strong></div>
              <div className="cart-row"><span>Oat Cookie × 1</span><strong>₱75.00</strong></div>
              <div className="cart-total"><span>Total</span><strong>₱435.00</strong></div>
              <button type="button" className="preview-pay"><CreditCard size={16} /> Pay now</button>
            </div>
          </div>
        )}

        {activeTab === "inventory" && (
          <div className="preview-panel">
            <div className="preview-search">Search product or scan barcode</div>
            <div className="stock-table">
              <div className="stock-row head">
                <span>Product</span><span>Stock</span><span>Status</span>
              </div>
              {previewStock.map((item) => (
                <div className="stock-row" key={item.name}>
                  <strong>{item.name}</strong>
                  <span>{item.count}</span>
                  <span className={`stock-status ${item.tone}`}>{item.status}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === "analytics" && (
          <div className="preview-panel">
            <div className="panel-head">
              <div>
                <span>Net sales today</span>
                <strong>₱12,840.00</strong>
              </div>
              <span className="trend">↑ 12.4%</span>
            </div>
            <div className="bars" aria-hidden="true">
              {[42, 58, 47, 71, 63, 86, 74, 93, 79, 68, 90, 100].map((height, index) => (
                <span key={index} style={{ height: `${height}%` }} />
              ))}
            </div>
            <div className="metric-grid">
              <div><PackageCheck size={18} /><span>Items sold</span><strong>184</strong></div>
              <div><FileText size={18} /><span>Transactions</span><strong>46</strong></div>
              <div><Banknote size={18} /><span>Avg basket</span><strong>₱279.00</strong></div>
            </div>
          </div>
        )}

        {activeTab === "receipts" && (
          <div className="preview-panel">
            <div className="panel-head">
              <div>
                <span>Recent receipts</span>
                <strong>Today</strong>
              </div>
              <span className="trend">46 total</span>
            </div>
            <div className="receipt-list">
              {previewReceipts.map((receipt) => (
                <div className="receipt-row" key={receipt.id}>
                  <span className="receipt-icon"><ReceiptText size={15} /></span>
                  <div>
                    <strong>{receipt.id}</strong>
                    <small>{receipt.meta}</small>
                  </div>
                  <strong className="receipt-amount">{receipt.amount}</strong>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default function Home() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [activeDevice, setActiveDevice] = useState("laptop");
  const [deviceSwitching, setDeviceSwitching] = useState(false);
  const [hintVisible, setHintVisible] = useState(true);
  const [openFaq, setOpenFaq] = useState<number | null>(0);
  const mainRef = useRef<HTMLElement>(null);
  const deviceTimer = useRef<number | undefined>(undefined);
  const deviceView = deviceViews.find((view) => view.id === activeDevice) ?? deviceViews[0];

  useEffect(() => () => window.clearTimeout(deviceTimer.current), []);

  // Fade out, swap the mockup while hidden, fade back in. The two devices
  // have very different proportions, so cross-fading beats animating them.
  const switchDevice = (id: string) => {
    if (id === activeDevice) return;

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setActiveDevice(id);
      return;
    }

    setDeviceSwitching(true);
    window.clearTimeout(deviceTimer.current);
    deviceTimer.current = window.setTimeout(() => {
      setActiveDevice(id);
      setDeviceSwitching(false);
    }, 190);
  };

  // Translate vertical mouse-wheel movement into horizontal scrolling on
  // desktop, eased over a few frames so it glides instead of jumping.
  // Panels taller than the viewport still scroll vertically first, then
  // hand off to horizontal at their top/bottom edge.
  useEffect(() => {
    if (!HORIZONTAL_SCROLL) return;
    const main = mainRef.current;
    if (!main) return;

    const desktop = window.matchMedia("(min-width: 1024px)");
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

    let target = 0;
    let animating = false;
    let frame = 0;

    // Hand control back to CSS: smooth anchor links and panel snapping.
    const release = () => {
      animating = false;
      main.style.scrollBehavior = "";
      main.style.scrollSnapType = "";
    };

    const step = () => {
      const distance = target - main.scrollLeft;
      if (Math.abs(distance) < 0.5) {
        main.scrollLeft = target;
        release();
        return;
      }
      main.scrollLeft += distance * 0.15;
      frame = requestAnimationFrame(step);
    };

    // Wheel deltas arrive as pixels, lines, or pages depending on device.
    const toPixels = (event: WheelEvent) => {
      if (event.deltaMode === 1) return event.deltaY * 16;
      if (event.deltaMode === 2) return event.deltaY * main.clientHeight;
      return event.deltaY;
    };

    const onWheel = (event: WheelEvent) => {
      if (!desktop.matches || event.ctrlKey || event.deltaY === 0) return;

      // Find the direct panel (child of <main>) under the pointer.
      let node = event.target as HTMLElement | null;
      let panel: HTMLElement | null = null;
      while (node && node !== main) {
        if (node.parentElement === main) {
          panel = node;
          break;
        }
        node = node.parentElement;
      }

      if (panel && panel.scrollHeight > panel.clientHeight + 1) {
        const atTop = panel.scrollTop <= 0;
        const atBottom =
          panel.scrollTop + panel.clientHeight >= panel.scrollHeight - 1;
        if ((event.deltaY < 0 && !atTop) || (event.deltaY > 0 && !atBottom)) {
          return; // let the panel scroll vertically
        }
      }

      event.preventDefault();

      const limit = main.scrollWidth - main.clientWidth;

      if (reduceMotion.matches) {
        main.scrollLeft = Math.min(limit, Math.max(0, main.scrollLeft + toPixels(event)));
        return;
      }

      // Resync when idle, so scrollbar drags and anchor jumps aren't fought.
      if (!animating) target = main.scrollLeft;
      target = Math.min(limit, Math.max(0, target + toPixels(event)));

      if (!animating) {
        animating = true;
        // Take manual control so per-frame writes aren't re-animated or snapped.
        main.style.scrollBehavior = "auto";
        main.style.scrollSnapType = "none";
        frame = requestAnimationFrame(step);
      }
    };

    // Anchor links need to drive the horizontal container explicitly.
    // Native fragment navigation assumes a vertically scrolling document,
    // and a wheel glide still in flight would drag the jump back.
    const onAnchorClick = (event: MouseEvent) => {
      if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey) {
        return;
      }

      const link = (event.target as HTMLElement | null)?.closest?.("a[href^='#']");
      if (!(link instanceof HTMLAnchorElement)) return;

      const id = link.getAttribute("href")?.slice(1);
      const panel = id ? document.getElementById(id) : null;
      if (!panel) return;

      event.preventDefault();

      // Stop any wheel glide so it cannot pull us back mid-jump.
      cancelAnimationFrame(frame);
      release();

      const behavior: ScrollBehavior = reduceMotion.matches ? "auto" : "smooth";

      if (desktop.matches) {
        const left =
          panel.getBoundingClientRect().left -
          main.getBoundingClientRect().left +
          main.scrollLeft;
        target = left;
        main.scrollTo({ left, behavior });
      } else {
        panel.scrollIntoView({ behavior, block: "start" });
      }

      history.replaceState(null, "", `#${id}`);
    };

    // Arrow keys step one panel at a time, so the hero's hint is accurate.
    const onKeyDown = (event: KeyboardEvent) => {
      if (!desktop.matches || event.metaKey || event.ctrlKey || event.altKey) return;

      const forward = event.key === "ArrowRight";
      const back = event.key === "ArrowLeft";
      if (!forward && !back) return;

      event.preventDefault();
      cancelAnimationFrame(frame);
      release();

      const step = main.clientWidth;
      const limit = main.scrollWidth - step;
      const current = Math.round(main.scrollLeft / step) * step;
      const left = Math.min(limit, Math.max(0, current + (forward ? step : -step)));

      target = left;
      main.scrollTo({ left, behavior: reduceMotion.matches ? "auto" : "smooth" });
    };

    // Retire the hint once they have actually moved.
    const onScroll = () => {
      if (main.scrollLeft > 40) setHintVisible(false);
    };

    main.addEventListener("wheel", onWheel, { passive: false });
    main.addEventListener("scroll", onScroll, { passive: true });
    document.addEventListener("click", onAnchorClick);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      main.removeEventListener("wheel", onWheel);
      main.removeEventListener("scroll", onScroll);
      document.removeEventListener("click", onAnchorClick);
      document.removeEventListener("keydown", onKeyDown);
      cancelAnimationFrame(frame);
      release();
    };
  }, []);

  // Fade content in as each panel comes into view. The .reveal class is
  // applied by JS only to elements that start off-screen, so nothing that
  // is already painted ever flashes out and back in.
  useEffect(() => {
    const main = mainRef.current;
    if (!main) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const revealSelectors = [
      ".hero-content > *",
      ".section-heading",
      ".device-stage",
      ".feature-card",
      ".connectivity-copy",
      ".sync-visual",
      ".detail-copy",
      ".metrics-panel",
      ".price-card",
      ".pricing-note",
      ".faq-heading",
      ".faq-list .faq-item",
      ".final-cta > div",
      ".final-cta .light-button",
      ".footer-brand",
      ".footer-links",
    ].join(",");

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        });
      },
      { threshold: 0.2 },
    );

    const onScreen = (el: HTMLElement) => {
      const box = el.getBoundingClientRect();
      return (
        box.left < window.innerWidth &&
        box.right > 0 &&
        box.top < window.innerHeight &&
        box.bottom > 0
      );
    };

    const panels = Array.from(main.children).filter(
      (child) => !child.classList.contains("site-header"),
    );

    panels.forEach((panel) => {
      const found = Array.from(panel.querySelectorAll<HTMLElement>(revealSelectors));
      const targets = found.length > 0 ? found : [panel as HTMLElement];

      targets.forEach((el, index) => {
        if (onScreen(el)) return; // already visible: leave it alone
        // Stagger siblings so a panel assembles rather than popping in.
        el.style.transitionDelay = `${Math.min(index, 6) * 80}ms`;
        el.classList.add("reveal");
        observer.observe(el);
      });
    });

    return () => observer.disconnect();
  }, []);

  return (
    <main ref={mainRef} className={HORIZONTAL_SCROLL ? "hscroll" : undefined}>
      <header className="site-header">
        <nav className="nav-shell" aria-label="Primary navigation">
          <a className="brand" href="#top" aria-label="TRX POS home">
            <BrandMark />
            <span>TRX POS</span>
          </a>
          <div className="desktop-nav">
            {navigation.map((item) => (
              <a href={item.href} key={item.href}>{item.label}</a>
            ))}
          </div>
          <a className="nav-cta desktop-cta" href="#pricing">
            See plans <ArrowRight size={16} />
          </a>
          <button
            type="button"
            className="menu-button"
            aria-label={menuOpen ? "Close navigation" : "Open navigation"}
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen((open) => !open)}
          >
            {menuOpen ? <X size={21} /> : <Menu size={21} />}
          </button>
        </nav>
        {menuOpen && (
          <div className="mobile-menu">
            {navigation.map((item) => (
              <a href={item.href} key={item.href} onClick={() => setMenuOpen(false)}>
                {item.label}
              </a>
            ))}
            <a className="nav-cta" href="#pricing" onClick={() => setMenuOpen(false)}>
              See plans <ArrowRight size={16} />
            </a>
          </div>
        )}
      </header>

      <section className="hero" id="top">
        <Image
          src="/trx-pos-retail-hero.png"
          alt="Retail checkout using a touchscreen POS and mobile barcode scanner"
          fill
          priority
          unoptimized
          sizes="100vw"
          className="hero-image"
        />
        <div className="hero-shade" />
        <div className="hero-content">
          <h1>TRX POS</h1>
          <p>Sell faster. Know your stock. Keep moving online or offline.</p>
          <div className="hero-actions">
            <a className="primary-button" href="#pricing">Start with TRX <ArrowRight size={18} /></a>
            <a className="secondary-button" href="#product">Explore the product</a>
          </div>
          <div className="hero-proof">
            <span><Check size={15} /> Windows and Android</span>
            <span><Check size={15} /> Offline-ready</span>
            <span><Check size={15} /> Philippine peso</span>
          </div>
        </div>

        {/* Was its own panel; folded into the hero so the opening slide
            carries the capability row instead of spending a whole
            viewport on four short labels. */}
        <div className="hero-capabilities">
          {/* Absolutely positioned, so it floats above the panel like a
              toast without taking a row in the hero's stack. */}
          {HORIZONTAL_SCROLL && (
            <div className={`scroll-hint${hintVisible ? "" : " is-gone"}`}>
              <span className="hint-wheel" aria-hidden="true"><i /></span>
              <span>Scroll</span>
              <span className="hint-keys">Press <kbd>←</kbd><kbd>→</kbd></span>
            </div>
          )}
          <span><MonitorSmartphone size={18} /> Desktop + mobile</span>
          <span><QrCode size={18} /> Camera + USB scanning</span>
          <span><ShieldCheck size={18} /> Role-based access</span>
          <span><Cloud size={18} /> Connected sync</span>
        </div>
      </section>

      <section className="section product-section" id="product">
        <div className="section-heading centered">
          <span className="section-label">THE WORKSPACE</span>
          <h2>Everything your counter needs.<br />Nothing it doesn’t.</h2>
          <p>Designed to stay fast during a rush and clear at the end of the day.</p>
        </div>
        <div className="device-stage">
          <div className={`device-frame ${deviceView.id}${deviceSwitching ? " is-switching" : ""}`}>
            <Image
              className="device-image"
              src={deviceView.src}
              alt=""
              width={deviceView.width}
              height={deviceView.height}
              unoptimized
            />
            <ProductPreview />
          </div>
          <div className="device-switch" role="group" aria-label="Preview device">
            {deviceViews.map((view) => {
              const Icon = view.icon;
              return (
                <button
                  type="button"
                  key={view.id}
                  className={activeDevice === view.id ? "active" : ""}
                  onClick={() => switchDevice(view.id)}
                  aria-pressed={activeDevice === view.id}
                >
                  <Icon size={15} /> {view.label}
                </button>
              );
            })}
          </div>
        </div>
      </section>

      <section className="section feature-section" id="features">
        <div className="section-heading">
          <span className="section-label">BUILT AROUND THE SALE</span>
          <h2>From first scan to final report.</h2>
          <p>Every module shares one visual system, one data flow, and one reliable record of what happened.</p>
        </div>
        <div className="feature-grid">
          {features.map((feature) => (
            <article className="feature-card" key={feature.title}>
              <span className="feature-icon">
                <Image src={feature.icon} alt="" width={150} height={150} unoptimized />
              </span>
              <h3>{feature.title}</h3>
              <p>{feature.copy}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="connectivity-band">
        <div className="connectivity-inner">
          <div className="connectivity-copy">
            <span className="section-label light">READY EITHER WAY</span>
            <h2>Your counter does not stop when Wi-Fi does.</h2>
            <p>TRX POS keeps the essential selling flow on the device. When connectivity returns, approved data synchronizes with your store account.</p>
            <div className="connectivity-points">
              <span><WifiOff size={18} /> Keep checking out offline</span>
              <span><Cloud size={18} /> Sync when connected</span>
              <span><BadgeCheck size={18} /> Preserve the audit trail</span>
            </div>
          </div>
          <div className="sync-visual">
            <svg
              className="sync-diagram"
              viewBox="0 0 520 470"
              role="img"
              aria-label="Data circulating between the counter and a mobile device"
            >
              {/* A true circle: r is equal in both axes and the default
                  preserveAspectRatio keeps it round at any box size.
                  The devices sit on it but off the horizontal axis --
                  counter at 165 degrees (low left), mobile at 345 (high
                  right) -- so they stagger instead of sitting level. */}
              <defs>
                <radialGradient id="flowGlow">
                  <stop offset="0%" stopColor="#16803d" stopOpacity="0.5" />
                  <stop offset="55%" stopColor="#16803d" stopOpacity="0.16" />
                  <stop offset="100%" stopColor="#16803d" stopOpacity="0" />
                </radialGradient>

                {/* Hides the circle and the dots where each device sits.
                    A real mask, not painted shapes: painted ones have to
                    match the section background exactly, and the section
                    wash made them show up as pale ovals. userSpaceOnUse
                    fixes the region so the dots animate through it. */}
                <mask
                  id="orbitMask"
                  maskUnits="userSpaceOnUse"
                  x="0"
                  y="0"
                  width="520"
                  height="470"
                >
                  <rect className="mask-show" x="0" y="0" width="520" height="470" />
                  <ellipse className="mask-hide" cx="101" cy="313" rx="85" ry="97" />
                  <ellipse className="mask-hide" cx="419" cy="216" rx="58" ry="95" />
                </mask>
              </defs>

              <circle className="orbit" cx="260" cy="235" r="165" mask="url(#orbitMask)" />

              {/* Both dots run one shared full-circle path, offset half a
                  lap, so they stay exactly opposite and never drift.
                  The path's arcs span exactly 2r (95 -> 425), which is what
                  forces their centre onto 260,235 -- arcs whose endpoints
                  are any closer than 2r resolve to an offset centre and the
                  dots visibly leave the outline.
                  The mask sits on this wrapper, not the animated groups, so
                  it stays put while they travel. */}
              <g mask="url(#orbitMask)">
              {[0, 3.6].map((offset) => (
                <g className="flow" key={offset}>
                  <circle className="flow-glow" r="13">
                    <animate
                      attributeName="r"
                      values="10;16;10"
                      dur="1.7s"
                      repeatCount="indefinite"
                    />
                    <animate
                      attributeName="opacity"
                      values="0.9;0.35;0.9"
                      dur="1.7s"
                      repeatCount="indefinite"
                    />
                  </circle>
                  <circle className="flow-core" r="4.5">
                    <animate
                      attributeName="r"
                      values="3.6;5.2;3.6"
                      dur="1.7s"
                      repeatCount="indefinite"
                    />
                  </circle>
                  <animateMotion
                    dur="7.2s"
                    begin={`${offset}s`}
                    repeatCount="indefinite"
                    path="M95 235a165 165 0 1 1 330 0a165 165 0 1 1 -330 0"
                  />
                </g>
              ))}
              </g>

              {/* Counter, sitting low on the circle. The 47px y offset puts
                  its SCREEN on the circle point, not its box, which the
                  stand would otherwise skew. */}
              <g transform="translate(27 231)">
                <rect className="shell" x="1.5" y="1.5" width="145" height="92" rx="7" />
                <path className="detail" d="M34 12v70" />
                <path className="detail" d="M12 22h10M12 34h10M12 46h10" />
                <path className="detail" d="M46 24h60M46 38h80M46 52h46M46 66h68" />
                <path className="stand" d="M61 94l-5 15h36l-5-15M47 109h54" />
              </g>

              {/* Mobile, sitting high on the circle. */}
              <g transform="translate(385 134)">
                <rect className="shell" x="1.5" y="1.5" width="65" height="113" rx="11" />
                <path className="detail" d="M27 10h14" />
                <path className="detail" d="M13 32h42M13 45h28M13 58h42M13 71h22" />
                <path className="detail" d="M21 100h26" />
              </g>

              <text className="caption" x="101" y="374" textAnchor="middle">Counter</text>
              <text className="caption sub" x="101" y="393" textAnchor="middle">Saved locally</text>
              <text className="caption" x="419" y="277" textAnchor="middle">Mobile</text>
              <text className="caption sub" x="419" y="296" textAnchor="middle">Up to date</text>
            </svg>
          </div>
        </div>
      </section>

      <section className="section details-section">
        <div className="detail-copy">
          <span className="section-label">CLEARER OPERATIONS</span>
          <h2>Know what is selling, what is left, and where money went.</h2>
          <p>Inventory, returns, customer credit, and store expenses meet in the same reporting layer, so owners get the full picture without assembling spreadsheets.</p>
          <a className="text-link" href="#pricing">Find the right plan <ArrowRight size={17} /></a>
        </div>
        <div className="metrics-panel">
          <div className="metrics-top">
            <div className="metric-main">
              <span>Net sales</span>
              <strong>₱84,620.00</strong>
              <small>
                <span className="delta"><TrendingUp size={12} /> 12.4%</span> vs last week
              </small>
            </div>
            <div className="range-chips" aria-hidden="true">
              <span className="active">7D</span>
              <span>30D</span>
              <span>12M</span>
            </div>
          </div>

          <div className="sales-chart" aria-hidden="true">
            <div className="chart-plot">
              <div className="chart-grid">
                <span /><span /><span /><span />
              </div>
              <svg className="chart-svg" viewBox="0 0 100 100" preserveAspectRatio="none">
                <defs>
                  <linearGradient id="salesFill" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#16803d" stopOpacity="0.26" />
                    <stop offset="100%" stopColor="#16803d" stopOpacity="0" />
                  </linearGradient>
                </defs>
                <path d={salesAreaPath} fill="url(#salesFill)" />
                <path
                  className="chart-line"
                  d={salesLinePath}
                  fill="none"
                  vectorEffect="non-scaling-stroke"
                />
              </svg>
              <div className="chart-points">
                {chartPoints.map((point, index) => (
                  <span
                    key={index}
                    className={point.peak ? "peak" : ""}
                    style={{ left: `${point.x}%`, top: `${point.y}%` }}
                  >
                    {point.peak && <span className="peak-chip">₱18,240</span>}
                  </span>
                ))}
              </div>
            </div>
            <div className="chart-axis">
              {salesChart.map((point, index) => <span key={index}>{point.day}</span>)}
            </div>
          </div>

          <div className="metric-grid">
            <div>
              <PackageCheck size={18} />
              <span>Items sold</span>
              <div className="metric-value"><strong>1,284</strong><em>+8.2%</em></div>
            </div>
            <div>
              <Banknote size={18} />
              <span>Expenses</span>
              <div className="metric-value"><strong>₱9,440.00</strong><em className="down">+3.1%</em></div>
            </div>
            <div>
              <FileText size={18} />
              <span>Transactions</span>
              <div className="metric-value"><strong>326</strong><em>+5.7%</em></div>
            </div>
          </div>
        </div>
      </section>

      <section className="section pricing-section" id="pricing">
        <div className="section-heading centered">
          <span className="section-label">SIMPLE PRICING</span>
          <h2>Pay once. Keep your history as you grow.</h2>
          <p>One payment per store, no monthly billing. These launch prices are easy to update before you connect your live payment gateway.</p>
        </div>
        <div className="pricing-grid">
          {plans.map((plan) => (
            <article className={`price-card ${plan.featured ? "featured" : ""}`} key={plan.name}>
              {plan.featured && <span className="popular">MOST POPULAR</span>}
              <h3>{plan.name}</h3>
              <p>{plan.description}</p>
              <div className="price">
                {plan.price === "Custom" ? (
                  <strong className="custom-price">Let’s talk</strong>
                ) : (
                  <><small>₱</small><strong>{plan.price}</strong><span>one-time</span></>
                )}
              </div>
              <a
                className={plan.featured ? "primary-button full" : "plan-button"}
                href={`mailto:sales@trxpos.example?subject=${encodeURIComponent(`TRX POS ${plan.name} plan`)}`}
              >
                {plan.price === "Custom" ? "Contact sales" : "Choose plan"} <ArrowRight size={17} />
              </a>
              <div className="plan-features">
                {plan.features.map((feature) => <span key={feature}><Check size={16} /> {feature}</span>)}
              </div>
            </article>
          ))}
        </div>
        <p className="pricing-note"><CreditCard size={16} /> One-time checkout activates after your preferred payment provider is connected.</p>
      </section>

      <section className="section faq-section" id="faq">
        <div className="faq-heading">
          <span className="section-label">GOOD TO KNOW</span>
          <h2>Questions, answered plainly.</h2>
          <p>Built for an actual store environment, not just a clean demo.</p>
        </div>
        <div className="faq-list">
          {faqs.map((faq, index) => {
            const open = openFaq === index;
            return (
              <div className={`faq-item${open ? " open" : ""}`} key={faq.question}>
                <button
                  type="button"
                  id={`faq-q-${index}`}
                  className="faq-question"
                  aria-expanded={open}
                  aria-controls={`faq-a-${index}`}
                  onClick={() => setOpenFaq(open ? null : index)}
                >
                  {faq.question}
                  <ChevronDown size={19} />
                </button>
                <div
                  className="faq-answer"
                  id={`faq-a-${index}`}
                  role="region"
                  aria-labelledby={`faq-q-${index}`}
                >
                  <div>
                    <p>{faq.answer}</p>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </section>

      {/* Closing CTA and footer share one panel: neither fills a viewport
          on its own, and together they balance it. */}
      <section className="closing">
        <div className="final-cta">
          <div>
            <span className="section-label light">YOUR STORE, IN STEP</span>
            <h2>Make every transaction easier to follow.</h2>
            <p>Bring checkout, inventory, returns, credit, expenses, and reporting into TRX POS.</p>
          </div>
          <a className="light-button" href="mailto:sales@trxpos.example?subject=TRX%20POS%20demo">
            Book a product demo <ArrowRight size={18} />
          </a>
        </div>

        <footer>
          <div className="footer-brand">
            <a className="brand" href="#top"><BrandMark /><span>TRX POS</span></a>
            <p>A clear, connected point of sale for modern local retail.</p>
          </div>
          <div className="footer-links">
            <div><strong>Product</strong><a href="#features">Features</a><a href="#pricing">Pricing</a><a href="#faq">FAQ</a></div>
            <div><strong>Contact</strong><a href="mailto:sales@trxpos.example">Sales</a><a href="mailto:support@trxpos.example">Support</a></div>
          </div>
          <div className="footer-bottom">
            <span>© 2026 TRX POS. All rights reserved.</span>
            <span>Built for Philippine retail.</span>
          </div>
        </footer>
      </section>
    </main>
  );
}
