import { useState, useMemo } from "react";

const CATEGORIES = [
  { id: "all", name: "All", icon: "📻", count: 1842 },
  { id: "hf_radios", name: "HF Radios", icon: "📡", count: 487 },
  { id: "vhf_radios", name: "VHF/UHF", icon: "🔊", count: 156 },
  { id: "hf_amps", name: "HF Amps", icon: "⚡", count: 202 },
  { id: "hf_antennas", name: "Antennas", icon: "🗼", count: 318 },
  { id: "keys", name: "Keys", icon: "🔑", count: 89 },
  { id: "antique", name: "Antique", icon: "🕰️", count: 139 },
  { id: "test_equip", name: "Test Equip", icon: "🔬", count: 94 },
  { id: "misc", name: "Misc", icon: "📦", count: 722 },
];

const LISTINGS = [
  {
    id: "qth:1758058",
    title: "Flex 6400 SDR Transceiver",
    description: "Purchased new from DX Engineering back in November. SmartSDR+ subscription included. Recently got an Elecraft K4 so this is sitting idle. No issues. Feel free to reach out.",
    price: 4400,
    obo: false,
    shipping: true,
    callsign: "AA5SH",
    category: "hf_radios",
    source: "qth",
    type: "for_sale",
    hasPhoto: true,
    datePosted: "2026-02-06",
    location: null,
  },
  {
    id: "qth:1757975",
    title: "QCX Transceivers (40m + 80m) + Z-Match Tuner",
    description: "Two original QCX transceivers with BaMaTech enclosures. 40m unit has signal generator enabled, 80m has QLG1 GPS for WSPR. Both in great shape. Includes z-Match Tuner. No returns.",
    price: 150,
    obo: false,
    shipping: true,
    callsign: "KC9DZ",
    category: "hf_radios",
    source: "qth",
    type: "for_sale",
    hasPhoto: true,
    datePosted: "2026-02-05",
    location: "IN",
  },
  {
    id: "qth:1757994",
    title: "SteppIR DB36 6m-80m Beam Antenna",
    description: "SteppIR DB36 covering 6m-80m on one antenna. All EHUs functioning, no issues. Does NOT include controller. Located in Queen Creek, AZ — buyer arranges transport. Was $9500 new. All fair offers considered.",
    price: null,
    obo: true,
    shipping: false,
    callsign: "NG7E",
    category: "hf_antennas",
    source: "qth",
    type: "for_sale",
    hasPhoto: true,
    datePosted: "2026-02-05",
    location: "AZ",
  },
  {
    id: "qth:1758093",
    title: "Ameritron ALS-600 HF Amplifier",
    description: "Rated 160-15M, 600W PEP, 400W CW. No 12-10M mod installed. Amp works and appears operational, sold as is. Will ship at buyer cost or pick-up in St. Louis, MO.",
    price: 925,
    obo: false,
    shipping: true,
    callsign: "W0FK",
    category: "hf_amps",
    source: "qth",
    type: "for_sale",
    hasPhoto: true,
    datePosted: "2026-02-06",
    location: "MO",
  },
  {
    id: "qth:1727037",
    title: "Vibroplex 70th Anniversary Key/Paddle Set",
    description: "MINT condition Vibroplex 70th anniversary Key/Paddle RARE Set. Cleaning up shack! Shipped FedEx.",
    price: 150,
    obo: true,
    shipping: true,
    callsign: "AA9NN",
    category: "keys",
    source: "qth",
    type: "for_sale",
    hasPhoto: true,
    datePosted: "2025-04-24",
    location: "IL",
  },
  {
    id: "qth:1753170",
    title: "WANTED: Yaesu FTM-200D",
    description: "Wanted Yaesu FTM 200D in good condition. Please send pictures and price shipped in the first email. If the ad is running I am still looking.",
    price: null,
    obo: false,
    shipping: false,
    callsign: "W8JDE",
    category: "vhf_radios",
    source: "qth",
    type: "wanted",
    hasPhoto: false,
    datePosted: "2025-12-19",
    location: null,
  },
  {
    id: "qth:1756131",
    title: "QRO-2000 HF Amplifier",
    description: "QRO-2000 in perfect condition. Brand new Penta 3-500ZG tubes installed 1/14/25. Works as it should. Come try it or ship at buyer expense in three boxes. Also have FT-2000 — deal on both.",
    price: 2000,
    obo: true,
    shipping: true,
    callsign: "W4EKY",
    category: "hf_amps",
    source: "qth",
    type: "for_sale",
    hasPhoto: true,
    datePosted: "2026-01-18",
    location: null,
  },
  {
    id: "qth:1757996",
    title: "Chameleon EMCOMM II HF Antenna",
    description: "Brand New, Never Used. 60 Ft, 1.8-54 MHz. 250W continuous, 500W SSB. PL-259 connector. Original box and instructions included.",
    price: 105,
    obo: false,
    shipping: true,
    callsign: "AA7LX",
    category: "hf_antennas",
    source: "qth",
    type: "for_sale",
    hasPhoto: true,
    datePosted: "2026-02-05",
    location: "AZ",
  },
  {
    id: "qrz:90421",
    title: "Elecraft KX3 + KXPA100 Amplifier Bundle",
    description: "Selling my KX3 with matching KXPA100 amp. Both in excellent condition, original boxes. Great portable/POTA setup. Includes all cables and manuals.",
    price: 1800,
    obo: false,
    shipping: true,
    callsign: "N7QR",
    category: "hf_radios",
    source: "qrz",
    type: "for_sale",
    hasPhoto: true,
    datePosted: "2026-02-04",
    location: "WA",
  },
  {
    id: "qth:1757939",
    title: "TRADE: FTDX10 for FTDX101D",
    description: "Like new FTDX10 with all factory packing materials. Would like to trade towards a FTDX101D. Great option if you're looking to downgrade.",
    price: null,
    obo: false,
    shipping: false,
    callsign: "WJ3V",
    category: "hf_radios",
    source: "qth",
    type: "trade",
    hasPhoto: true,
    datePosted: "2026-02-04",
    location: "PA",
  },
];

function timeAgo(dateStr) {
  const now = new Date("2026-02-06");
  const date = new Date(dateStr);
  const days = Math.floor((now - date) / 86400000);
  if (days === 0) return "Today";
  if (days === 1) return "Yesterday";
  if (days < 7) return `${days}d ago`;
  if (days < 30) return `${Math.floor(days / 7)}w ago`;
  return `${Math.floor(days / 30)}mo ago`;
}

function formatPrice(listing) {
  if (listing.price) {
    return `$${listing.price.toLocaleString()}${listing.obo ? " OBO" : ""}`;
  }
  if (listing.type === "wanted") return "WANTED";
  if (listing.type === "trade") return "TRADE";
  if (listing.obo) return "Make Offer";
  return "Contact";
}

function ListingTypeBadge({ type }) {
  const styles = {
    for_sale: { bg: "#1a2e1a", color: "#4ade80", label: "For Sale" },
    wanted: { bg: "#2e1a2e", color: "#c084fc", label: "Wanted" },
    trade: { bg: "#1a2a2e", color: "#22d3ee", label: "Trade" },
  };
  const s = styles[type];
  return (
    <span style={{
      fontSize: 10, fontWeight: 700, letterSpacing: "0.05em",
      padding: "2px 6px", borderRadius: 4,
      backgroundColor: s.bg, color: s.color, textTransform: "uppercase",
    }}>{s.label}</span>
  );
}

function SourceBadge({ source }) {
  return (
    <span style={{
      fontSize: 9, fontWeight: 600, letterSpacing: "0.08em",
      padding: "1px 5px", borderRadius: 3,
      border: `1px solid ${source === "qth" ? "#555" : "#6366f1"}`,
      color: source === "qth" ? "#999" : "#818cf8",
      textTransform: "uppercase", fontFamily: "'SF Mono', 'Fira Code', monospace",
    }}>{source === "qth" ? "QTH" : "QRZ"}</span>
  );
}

function PhotoPlaceholder({ hasPhoto, category }) {
  const icons = {
    hf_radios: "📡", vhf_radios: "🔊", hf_amps: "⚡",
    hf_antennas: "🗼", keys: "🔑", antique: "🕰️",
    test_equip: "🔬", misc: "📦",
  };
  const gradients = {
    hf_radios: "linear-gradient(135deg, #1a1a2e 0%, #16213e 100%)",
    vhf_radios: "linear-gradient(135deg, #1a2e1a 0%, #162e3e 100%)",
    hf_amps: "linear-gradient(135deg, #2e1a1a 0%, #3e2816 100%)",
    hf_antennas: "linear-gradient(135deg, #1a2e2e 0%, #163e2e 100%)",
    keys: "linear-gradient(135deg, #2e2a1a 0%, #3e3016 100%)",
    antique: "linear-gradient(135deg, #2e2418 0%, #3e2e16 100%)",
    test_equip: "linear-gradient(135deg, #1a1a2e 0%, #2e163e 100%)",
    misc: "linear-gradient(135deg, #1e1e1e 0%, #2a2a2a 100%)",
  };
  return (
    <div style={{
      width: 80, height: 80, borderRadius: 12, flexShrink: 0,
      background: gradients[category] || gradients.misc,
      display: "flex", alignItems: "center", justifyContent: "center",
      fontSize: 28, position: "relative",
      border: "1px solid rgba(255,255,255,0.06)",
    }}>
      {icons[category] || "📦"}
      {hasPhoto && (
        <div style={{
          position: "absolute", bottom: 4, right: 4,
          width: 16, height: 16, borderRadius: 4,
          backgroundColor: "rgba(0,0,0,0.7)",
          display: "flex", alignItems: "center", justifyContent: "center",
          fontSize: 9,
        }}>📷</div>
      )}
    </div>
  );
}

function ListingCard({ listing, onClick }) {
  const [hovered, setHovered] = useState(false);
  return (
    <div
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display: "flex", gap: 12, padding: "14px 16px",
        backgroundColor: hovered ? "rgba(255,255,255,0.03)" : "transparent",
        borderBottom: "1px solid rgba(255,255,255,0.06)",
        cursor: "pointer", transition: "background-color 0.15s",
      }}
    >
      <PhotoPlaceholder hasPhoto={listing.hasPhoto} category={listing.category} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 4 }}>
          <ListingTypeBadge type={listing.type} />
          <SourceBadge source={listing.source} />
        </div>
        <div style={{
          fontSize: 15, fontWeight: 600, color: "#f0f0f0",
          lineHeight: 1.3, marginBottom: 4,
          overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap",
        }}>{listing.title}</div>
        <div style={{
          fontSize: 13, color: "#888", lineHeight: 1.4,
          overflow: "hidden", display: "-webkit-box",
          WebkitLineClamp: 2, WebkitBoxOrient: "vertical",
        }}>{listing.description}</div>
        <div style={{
          display: "flex", alignItems: "center", gap: 8, marginTop: 8,
          fontSize: 12, color: "#666",
        }}>
          <span style={{
            fontFamily: "'SF Mono', 'Fira Code', monospace",
            color: "#d4a843", fontWeight: 600, fontSize: 11,
          }}>{listing.callsign}</span>
          <span>·</span>
          <span>{timeAgo(listing.datePosted)}</span>
          {listing.location && <>
            <span>·</span>
            <span>{listing.location}</span>
          </>}
        </div>
      </div>
      <div style={{
        display: "flex", flexDirection: "column", alignItems: "flex-end",
        justifyContent: "center", flexShrink: 0,
      }}>
        <span style={{
          fontSize: listing.price ? 17 : 13,
          fontWeight: 700,
          color: listing.price ? "#4ade80" : (listing.type === "wanted" ? "#c084fc" : "#22d3ee"),
          fontFamily: listing.price ? "inherit" : "'SF Mono', monospace",
          letterSpacing: listing.price ? "-0.02em" : "0.02em",
        }}>{formatPrice(listing)}</span>
        {listing.shipping && listing.price && (
          <span style={{ fontSize: 10, color: "#666", marginTop: 2 }}>shipped</span>
        )}
      </div>
    </div>
  );
}

function ListingDetail({ listing, onBack }) {
  return (
    <div style={{ height: "100%", overflow: "auto" }}>
      <div style={{
        padding: "12px 16px", display: "flex", alignItems: "center",
        borderBottom: "1px solid rgba(255,255,255,0.08)",
        position: "sticky", top: 0, backgroundColor: "#111113", zIndex: 10,
      }}>
        <button onClick={onBack} style={{
          background: "none", border: "none", color: "#d4a843",
          fontSize: 15, cursor: "pointer", padding: "4px 0", fontWeight: 500,
        }}>← Back</button>
      </div>
      <div style={{ padding: 20 }}>
        <div style={{
          width: "100%", height: 200, borderRadius: 16,
          background: "linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #1a2e2e 100%)",
          display: "flex", alignItems: "center", justifyContent: "center",
          fontSize: 64, marginBottom: 20,
          border: "1px solid rgba(255,255,255,0.06)",
        }}>
          {listing.hasPhoto ? "📷" : "📻"}
        </div>
        <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
          <ListingTypeBadge type={listing.type} />
          <SourceBadge source={listing.source} />
        </div>
        <h2 style={{
          fontSize: 22, fontWeight: 700, color: "#f0f0f0",
          lineHeight: 1.3, margin: "0 0 12px 0",
        }}>{listing.title}</h2>
        {(listing.price || listing.type !== "for_sale") && (
          <div style={{
            fontSize: 28, fontWeight: 800, marginBottom: 16,
            color: listing.price ? "#4ade80" : "#c084fc",
          }}>
            {formatPrice(listing)}
            {listing.shipping && listing.price && (
              <span style={{ fontSize: 14, color: "#666", fontWeight: 400, marginLeft: 8 }}>
                shipped
              </span>
            )}
          </div>
        )}
        <div style={{
          display: "flex", gap: 10, marginBottom: 20,
        }}>
          <button style={{
            flex: 1, padding: "12px 16px", borderRadius: 10,
            backgroundColor: "#d4a843", color: "#111", border: "none",
            fontSize: 15, fontWeight: 700, cursor: "pointer",
          }}>Contact Seller</button>
          <button style={{
            padding: "12px 16px", borderRadius: 10,
            backgroundColor: "rgba(255,255,255,0.08)", color: "#ccc", border: "none",
            fontSize: 15, cursor: "pointer",
          }}>☆</button>
          <button style={{
            padding: "12px 16px", borderRadius: 10,
            backgroundColor: "rgba(255,255,255,0.08)", color: "#ccc", border: "none",
            fontSize: 15, cursor: "pointer",
          }}>↗</button>
        </div>
        <div style={{
          padding: 16, borderRadius: 12,
          backgroundColor: "rgba(255,255,255,0.04)",
          border: "1px solid rgba(255,255,255,0.06)",
          marginBottom: 20,
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 12 }}>
            <div style={{
              width: 40, height: 40, borderRadius: 10,
              backgroundColor: "rgba(212,168,67,0.15)",
              display: "flex", alignItems: "center", justifyContent: "center",
              fontSize: 18,
            }}>📡</div>
            <div>
              <div style={{
                fontFamily: "'SF Mono', 'Fira Code', monospace",
                color: "#d4a843", fontWeight: 700, fontSize: 16,
              }}>{listing.callsign}</div>
              <div style={{ fontSize: 12, color: "#666" }}>
                {listing.location ? `${listing.location} · ` : ""}View on QRZ →
              </div>
            </div>
          </div>
        </div>
        <div style={{ marginBottom: 20 }}>
          <h3 style={{
            fontSize: 13, fontWeight: 600, color: "#888",
            textTransform: "uppercase", letterSpacing: "0.05em",
            marginBottom: 8,
          }}>Description</h3>
          <p style={{
            fontSize: 15, color: "#ccc", lineHeight: 1.6, margin: 0,
          }}>{listing.description}</p>
        </div>
        <div style={{
          display: "grid", gridTemplateColumns: "1fr 1fr",
          gap: 10, marginBottom: 20,
        }}>
          {[
            { label: "Source", value: listing.source === "qth" ? "QTH.com" : "QRZ Swapmeet" },
            { label: "Posted", value: listing.datePosted },
            { label: "Category", value: CATEGORIES.find(c => c.id === listing.category)?.name || listing.category },
            { label: "Listing ID", value: listing.source_id || listing.id.split(":")[1] },
          ].map(({ label, value }) => (
            <div key={label} style={{
              padding: 12, borderRadius: 10,
              backgroundColor: "rgba(255,255,255,0.03)",
              border: "1px solid rgba(255,255,255,0.05)",
            }}>
              <div style={{ fontSize: 11, color: "#666", marginBottom: 2, textTransform: "uppercase", letterSpacing: "0.05em" }}>{label}</div>
              <div style={{
                fontSize: 13, color: "#ccc", fontWeight: 500,
                fontFamily: label === "Listing ID" ? "'SF Mono', monospace" : "inherit",
              }}>{value}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function FilterSheet({ filters, setFilters, onClose }) {
  const [local, setLocal] = useState({ ...filters });
  return (
    <div style={{
      position: "absolute", bottom: 0, left: 0, right: 0,
      backgroundColor: "#1a1a1d", borderRadius: "20px 20px 0 0",
      padding: "20px 20px 32px", zIndex: 20,
      borderTop: "1px solid rgba(255,255,255,0.1)",
      boxShadow: "0 -20px 60px rgba(0,0,0,0.5)",
    }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 20 }}>
        <h3 style={{ margin: 0, fontSize: 18, fontWeight: 700, color: "#f0f0f0" }}>Filters</h3>
        <button onClick={onClose} style={{
          background: "none", border: "none", color: "#d4a843", fontSize: 15, cursor: "pointer", fontWeight: 600,
        }}>Done</button>
      </div>
      <div style={{ marginBottom: 16 }}>
        <div style={{ fontSize: 12, color: "#888", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.05em", marginBottom: 8 }}>Listing Type</div>
        <div style={{ display: "flex", gap: 8 }}>
          {[
            { id: "all", label: "All" },
            { id: "for_sale", label: "For Sale" },
            { id: "wanted", label: "Wanted" },
            { id: "trade", label: "Trade" },
          ].map(t => (
            <button key={t.id} onClick={() => setLocal(p => ({ ...p, type: t.id }))}
              style={{
                padding: "8px 14px", borderRadius: 8, fontSize: 13, fontWeight: 600, cursor: "pointer",
                border: `1px solid ${local.type === t.id ? "#d4a843" : "rgba(255,255,255,0.1)"}`,
                backgroundColor: local.type === t.id ? "rgba(212,168,67,0.15)" : "rgba(255,255,255,0.04)",
                color: local.type === t.id ? "#d4a843" : "#888",
              }}>{t.label}</button>
          ))}
        </div>
      </div>
      <div style={{ marginBottom: 16 }}>
        <div style={{ fontSize: 12, color: "#888", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.05em", marginBottom: 8 }}>Source</div>
        <div style={{ display: "flex", gap: 8 }}>
          {[
            { id: "all", label: "All Sources" },
            { id: "qth", label: "QTH.com" },
            { id: "qrz", label: "QRZ" },
          ].map(s => (
            <button key={s.id} onClick={() => setLocal(p => ({ ...p, source: s.id }))}
              style={{
                padding: "8px 14px", borderRadius: 8, fontSize: 13, fontWeight: 600, cursor: "pointer",
                border: `1px solid ${local.source === s.id ? "#d4a843" : "rgba(255,255,255,0.1)"}`,
                backgroundColor: local.source === s.id ? "rgba(212,168,67,0.15)" : "rgba(255,255,255,0.04)",
                color: local.source === s.id ? "#d4a843" : "#888",
              }}>{s.label}</button>
          ))}
        </div>
      </div>
      <div style={{ marginBottom: 16 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
          <div style={{ fontSize: 12, color: "#888", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.05em" }}>Has Photo</div>
          <button onClick={() => setLocal(p => ({ ...p, hasPhoto: !p.hasPhoto }))}
            style={{
              width: 44, height: 26, borderRadius: 13, border: "none", cursor: "pointer",
              backgroundColor: local.hasPhoto ? "#d4a843" : "rgba(255,255,255,0.15)",
              position: "relative", transition: "background-color 0.2s",
            }}>
            <div style={{
              width: 22, height: 22, borderRadius: 11, backgroundColor: "#fff",
              position: "absolute", top: 2,
              left: local.hasPhoto ? 20 : 2,
              transition: "left 0.2s",
            }} />
          </button>
        </div>
      </div>
      <div style={{ marginBottom: 20 }}>
        <div style={{ fontSize: 12, color: "#888", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.05em", marginBottom: 8 }}>Sort By</div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          {[
            { id: "newest", label: "Newest" },
            { id: "price_asc", label: "Price ↑" },
            { id: "price_desc", label: "Price ↓" },
          ].map(s => (
            <button key={s.id} onClick={() => setLocal(p => ({ ...p, sort: s.id }))}
              style={{
                padding: "8px 14px", borderRadius: 8, fontSize: 13, fontWeight: 600, cursor: "pointer",
                border: `1px solid ${local.sort === s.id ? "#d4a843" : "rgba(255,255,255,0.1)"}`,
                backgroundColor: local.sort === s.id ? "rgba(212,168,67,0.15)" : "rgba(255,255,255,0.04)",
                color: local.sort === s.id ? "#d4a843" : "#888",
              }}>{s.label}</button>
          ))}
        </div>
      </div>
      <button onClick={() => { setFilters(local); onClose(); }} style={{
        width: "100%", padding: "14px", borderRadius: 12, border: "none",
        backgroundColor: "#d4a843", color: "#111", fontSize: 16, fontWeight: 700,
        cursor: "pointer",
      }}>Apply Filters</button>
    </div>
  );
}

export default function HamSwap() {
  const [activeTab, setActiveTab] = useState("browse");
  const [activeCategory, setActiveCategory] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [showFilters, setShowFilters] = useState(false);
  const [selectedListing, setSelectedListing] = useState(null);
  const [filters, setFilters] = useState({
    type: "all", source: "all", hasPhoto: false, sort: "newest",
  });

  const filteredListings = useMemo(() => {
    let results = [...LISTINGS];
    if (activeCategory !== "all") results = results.filter(l => l.category === activeCategory);
    if (filters.type !== "all") results = results.filter(l => l.type === filters.type);
    if (filters.source !== "all") results = results.filter(l => l.source === filters.source);
    if (filters.hasPhoto) results = results.filter(l => l.hasPhoto);
    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      results = results.filter(l =>
        l.title.toLowerCase().includes(q) ||
        l.description.toLowerCase().includes(q) ||
        l.callsign.toLowerCase().includes(q)
      );
    }
    if (filters.sort === "newest") results.sort((a, b) => new Date(b.datePosted) - new Date(a.datePosted));
    if (filters.sort === "price_asc") results.sort((a, b) => (a.price || 99999) - (b.price || 99999));
    if (filters.sort === "price_desc") results.sort((a, b) => (b.price || 0) - (a.price || 0));
    return results;
  }, [activeCategory, filters, searchQuery]);

  const activeFilterCount = [
    filters.type !== "all", filters.source !== "all", filters.hasPhoto, filters.sort !== "newest"
  ].filter(Boolean).length;

  return (
    <div style={{
      width: 390, height: 844, backgroundColor: "#111113", color: "#f0f0f0",
      borderRadius: 40, overflow: "hidden", position: "relative",
      fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
      border: "3px solid #333", boxShadow: "0 20px 80px rgba(0,0,0,0.6)",
      margin: "20px auto",
      display: "flex", flexDirection: "column",
    }}>
      {/* Status Bar */}
      <div style={{
        padding: "14px 28px 0", display: "flex", justifyContent: "space-between",
        fontSize: 14, fontWeight: 600, color: "#fff",
      }}>
        <span>9:41</span>
        <div style={{
          width: 126, height: 34, backgroundColor: "#000", borderRadius: 20,
          position: "absolute", top: 8, left: "50%", transform: "translateX(-50%)",
        }} />
        <span style={{ display: "flex", gap: 4, alignItems: "center" }}>
          <span style={{ fontSize: 12 }}>📶</span>
          <span style={{ fontSize: 12 }}>🔋</span>
        </span>
      </div>

      {/* Main Content */}
      <div style={{ flex: 1, overflow: "hidden", display: "flex", flexDirection: "column" }}>
        {selectedListing ? (
          <ListingDetail listing={selectedListing} onBack={() => setSelectedListing(null)} />
        ) : (
          <>
            {/* Header */}
            <div style={{ padding: "16px 20px 0" }}>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 12 }}>
                <h1 style={{
                  margin: 0, fontSize: 28, fontWeight: 800, color: "#f0f0f0",
                  letterSpacing: "-0.02em",
                }}>
                  <span style={{ color: "#d4a843" }}>Ham</span>Swap
                </h1>
                <div style={{ fontSize: 11, color: "#666", fontFamily: "'SF Mono', monospace" }}>
                  {LISTINGS.length} listings
                </div>
              </div>

              {/* Search */}
              <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
                <div style={{
                  flex: 1, display: "flex", alignItems: "center",
                  backgroundColor: "rgba(255,255,255,0.06)",
                  borderRadius: 12, padding: "0 12px",
                  border: "1px solid rgba(255,255,255,0.08)",
                }}>
                  <span style={{ color: "#666", marginRight: 8, fontSize: 14 }}>🔍</span>
                  <input
                    value={searchQuery}
                    onChange={e => setSearchQuery(e.target.value)}
                    placeholder="Search radios, callsigns..."
                    style={{
                      flex: 1, background: "none", border: "none", outline: "none",
                      color: "#f0f0f0", fontSize: 15, padding: "10px 0",
                      fontFamily: "inherit",
                    }}
                  />
                  {searchQuery && (
                    <button onClick={() => setSearchQuery("")} style={{
                      background: "none", border: "none", color: "#666", cursor: "pointer",
                      fontSize: 16, padding: 0,
                    }}>✕</button>
                  )}
                </div>
                <button onClick={() => setShowFilters(true)} style={{
                  padding: "0 14px", borderRadius: 12, border: "none",
                  backgroundColor: activeFilterCount > 0 ? "rgba(212,168,67,0.15)" : "rgba(255,255,255,0.06)",
                  color: activeFilterCount > 0 ? "#d4a843" : "#888",
                  fontSize: 14, cursor: "pointer", position: "relative",
                  borderWidth: 1, borderStyle: "solid",
                  borderColor: activeFilterCount > 0 ? "#d4a843" : "rgba(255,255,255,0.08)",
                }}>
                  ⚙
                  {activeFilterCount > 0 && (
                    <span style={{
                      position: "absolute", top: -4, right: -4,
                      width: 16, height: 16, borderRadius: 8,
                      backgroundColor: "#d4a843", color: "#111",
                      fontSize: 10, fontWeight: 700,
                      display: "flex", alignItems: "center", justifyContent: "center",
                    }}>{activeFilterCount}</span>
                  )}
                </button>
              </div>

              {/* Category Chips */}
              <div style={{
                display: "flex", gap: 8, overflowX: "auto", paddingBottom: 12,
                scrollbarWidth: "none", msOverflowStyle: "none",
              }}>
                {CATEGORIES.map(cat => (
                  <button key={cat.id} onClick={() => setActiveCategory(cat.id)}
                    style={{
                      padding: "6px 12px", borderRadius: 20, whiteSpace: "nowrap",
                      fontSize: 13, fontWeight: 600, cursor: "pointer",
                      flexShrink: 0, display: "flex", alignItems: "center", gap: 5,
                      border: `1px solid ${activeCategory === cat.id ? "#d4a843" : "rgba(255,255,255,0.1)"}`,
                      backgroundColor: activeCategory === cat.id ? "rgba(212,168,67,0.15)" : "rgba(255,255,255,0.04)",
                      color: activeCategory === cat.id ? "#d4a843" : "#888",
                      transition: "all 0.15s",
                    }}>
                    <span style={{ fontSize: 13 }}>{cat.icon}</span>
                    {cat.name}
                    <span style={{
                      fontSize: 10, opacity: 0.7,
                      fontFamily: "'SF Mono', monospace",
                    }}>{cat.count}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Listings */}
            <div style={{ flex: 1, overflow: "auto" }}>
              {filteredListings.length === 0 ? (
                <div style={{
                  padding: 40, textAlign: "center", color: "#555",
                }}>
                  <div style={{ fontSize: 48, marginBottom: 12 }}>📻</div>
                  <div style={{ fontSize: 15, fontWeight: 600 }}>No listings found</div>
                  <div style={{ fontSize: 13, marginTop: 4 }}>Try adjusting your filters</div>
                </div>
              ) : (
                filteredListings.map(listing => (
                  <ListingCard
                    key={listing.id}
                    listing={listing}
                    onClick={() => setSelectedListing(listing)}
                  />
                ))
              )}
            </div>
          </>
        )}
      </div>

      {/* Tab Bar */}
      {!selectedListing && (
        <div style={{
          display: "flex", justifyContent: "space-around",
          padding: "8px 0 28px",
          borderTop: "1px solid rgba(255,255,255,0.08)",
          backgroundColor: "#111113",
        }}>
          {[
            { id: "browse", icon: "📻", label: "Browse" },
            { id: "search", icon: "🔍", label: "Search" },
            { id: "saved", icon: "☆", label: "Saved" },
            { id: "settings", icon: "⚙", label: "Settings" },
          ].map(tab => (
            <button key={tab.id} onClick={() => setActiveTab(tab.id)}
              style={{
                background: "none", border: "none", cursor: "pointer",
                display: "flex", flexDirection: "column", alignItems: "center", gap: 2,
                color: activeTab === tab.id ? "#d4a843" : "#555",
                fontSize: 10, fontWeight: 600, padding: "4px 16px",
              }}>
              <span style={{ fontSize: 20 }}>{tab.icon}</span>
              {tab.label}
            </button>
          ))}
        </div>
      )}

      {/* Filter Sheet */}
      {showFilters && (
        <>
          <div
            onClick={() => setShowFilters(false)}
            style={{
              position: "absolute", top: 0, left: 0, right: 0, bottom: 0,
              backgroundColor: "rgba(0,0,0,0.5)", zIndex: 15,
            }}
          />
          <FilterSheet filters={filters} setFilters={setFilters} onClose={() => setShowFilters(false)} />
        </>
      )}
    </div>
  );
}
