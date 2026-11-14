import { useEffect, useId, useRef, type ReactNode } from "react";
import { Link } from "@tanstack/react-router";
import { AlertTriangle, ChevronRight, Inbox, LoaderCircle, Search, User, X, type LucideIcon } from "lucide-react";

/**
 * Open Play shared UI (design system, docs/project-knowledge/design-system.md).
 * Dark surfaces, orange accents, Oswald uppercase headings and Inter body text, matching the
 * owner reference images in docs/reference-assets/visual-references. Presentation only:
 * components never fetch data or decide permissions.
 */

type To = Parameters<typeof Link>[0]["to"];

export function PageHeader({ eyebrow, title, subtitle, badge, actions }: {
  eyebrow?: string; title: string; subtitle?: ReactNode; badge?: ReactNode; actions?: ReactNode;
}) {
  return (
    <header className="op-page-header">
      <div className="op-page-header-top">
        {eyebrow && <p className="op-eyebrow">{eyebrow}</p>}
        {badge}
      </div>
      <h1 className="op-page-title">{title}</h1>
      {subtitle && <p className="op-page-subtitle">{subtitle}</p>}
      {actions && <div className="op-page-actions">{actions}</div>}
    </header>
  );
}

export function SectionHeading({ title, description, meta, id, link }: {
  title: string; description?: string; meta?: ReactNode; id?: string; link?: { to: To; label: string; hash?: string; search?: Record<string, string> };
}) {
  return (
    <div className="op-section-heading">
      <div>
        <h2 id={id} className="op-section-title">{title}</h2>
        {description && <p className="op-section-description">{description}</p>}
      </div>
      {(meta || link) && <div className="op-section-meta">{meta}{link && <Link to={link.to} hash={link.hash} search={link.search as never} className="op-section-link">{link.label}<ChevronRight aria-hidden="true" /></Link>}</div>}
    </div>
  );
}

export function Card({ children, className = "", as: Tag = "article", labelledBy }: {
  children: ReactNode; className?: string; as?: "article" | "section" | "div"; labelledBy?: string;
}) {
  return <Tag className={`op-card ${className}`.trim()} aria-labelledby={labelledBy}>{children}</Tag>;
}

/** Whole-card navigation tile (IMG_0522, IMG_0532): icon, title, description and chevron. */
export function TileLink({ to, icon: Icon, title, description, hash }: {
  to: To; icon: LucideIcon; title: string; description: string; hash?: string;
}) {
  return (
    <Link to={to} hash={hash} className="op-tile">
      <span className="op-tile-top"><Icon aria-hidden="true" className="op-icon-accent" /><ChevronRight aria-hidden="true" className="op-icon-accent" /></span>
      <strong className="op-tile-title">{title}</strong>
      <span className="op-tile-description">{description}</span>
    </Link>
  );
}

type ButtonVariant = "primary" | "secondary" | "outline" | "ghost" | "light";
type ButtonSize = "regular" | "large";
const buttonClass = (variant: ButtonVariant, block?: boolean, size: ButtonSize = "regular") =>
  `op-button op-button-${variant}${size === "large" ? " op-button-large" : ""}${block ? " op-button-block" : ""}`;

export function Button({ children, variant = "primary", size, block, type = "button", disabled, busy, onClick, icon: Icon }: {
  children: ReactNode; variant?: ButtonVariant; size?: ButtonSize; block?: boolean; type?: "button" | "submit";
  disabled?: boolean; busy?: boolean; onClick?: () => void; icon?: LucideIcon;
}) {
  return (
    <button type={type} className={buttonClass(variant, block, size)} disabled={disabled || busy} aria-busy={busy || undefined} onClick={onClick}>
      {busy ? <LoaderCircle aria-hidden="true" className="op-spin" /> : Icon && <Icon aria-hidden="true" />}
      <span>{children}</span>
    </button>
  );
}

export function ButtonLink({ children, to, variant = "primary", size, block, icon: Icon, hash, params, search }: {
  children: ReactNode; to: To; variant?: ButtonVariant; size?: ButtonSize; block?: boolean; icon?: LucideIcon; hash?: string;
  params?: Record<string, string>; search?: Record<string, string>;
}) {
  return (
    <Link to={to} hash={hash} params={params as never} search={search as never} className={buttonClass(variant, block, size)}>
      {Icon && <Icon aria-hidden="true" />}<span>{children}</span>
    </Link>
  );
}

export type StatusTone = "active" | "upcoming" | "warning" | "danger" | "neutral" | "accent";
/** Semantic status pill: green active/success, blue upcoming/planned, orange emphasis. */
export function StatusBadge({ tone, children }: { tone: StatusTone; children: ReactNode }) {
  return <span className={`op-badge op-badge-${tone}`}>{children}</span>;
}

export function StatTile({ value, label, accent }: { value: ReactNode; label: string; accent?: boolean }) {
  return (
    <div className={`op-stat${accent ? " op-stat-accent" : ""}`}>
      <strong className="op-stat-value">{value}</strong>
      <span className="op-stat-label">{label}</span>
    </div>
  );
}

export function StatGrid({ children }: { children: ReactNode }) {
  return <div className="op-stat-grid">{children}</div>;
}

export function LoadingState({ label = "Loading…" }: { label?: string }) {
  return <p className="op-state op-state-loading" role="status" aria-live="polite"><LoaderCircle aria-hidden="true" className="op-spin" />{label}</p>;
}

export function EmptyState({ title, description, action, icon: Icon = Inbox }: {
  title: string; description?: string; action?: ReactNode; icon?: LucideIcon;
}) {
  return (
    <div className="op-state op-state-empty" role="status">
      <Icon aria-hidden="true" className="op-icon-muted" />
      <div><strong>{title}</strong>{description && <p>{description}</p>}{action}</div>
    </div>
  );
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="op-state op-state-error" role="alert">
      <AlertTriangle aria-hidden="true" />
      <div><strong>Something went wrong</strong><p>{message}</p>
        {onRetry && <button type="button" className={buttonClass("outline")} onClick={onRetry}><span>Try again</span></button>}
      </div>
    </div>
  );
}

export function SearchField({ label, value, onChange, placeholder }: {
  label: string; value: string; onChange: (value: string) => void; placeholder?: string;
}) {
  const id = useId();
  return (
    <div className="op-search">
      <label htmlFor={id} className="visually-hidden">{label}</label>
      <Search aria-hidden="true" className="op-icon-accent" />
      <input id={id} type="search" value={value} placeholder={placeholder ?? label} onChange={(event) => onChange(event.target.value)} />
    </div>
  );
}

/** Accessible confirmation built on the native <dialog> (focus trapping and Escape handled by the browser). */
export function ConfirmDialog({ open, title, children, confirmLabel, onConfirm, onCancel, busy, destructive }: {
  open: boolean; title: string; children: ReactNode; confirmLabel: string;
  onConfirm: () => void; onCancel: () => void; busy?: boolean; destructive?: boolean;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) dialog.showModal();
    if (!open && dialog.open) dialog.close();
  }, [open]);
  return (
    <dialog ref={ref} className="op-dialog" aria-labelledby={titleId} onCancel={(event) => { event.preventDefault(); onCancel(); }}>
      <h2 id={titleId} className="op-section-title">{title}</h2>
      <div className="op-dialog-body">{children}</div>
      <div className="op-dialog-actions">
        <Button variant="outline" onClick={onCancel} disabled={busy}>Cancel</Button>
        <Button variant={destructive ? "light" : "primary"} onClick={onConfirm} busy={busy}>{confirmLabel}</Button>
      </div>
    </dialog>
  );
}

/** Previous / Next pagination with the "1–4 of 10" range used in IMG_0572/0573/0540. */
export function Pagination({ from, to, total, hasPrevious, hasNext, onPrevious, onNext }: {
  from: number; to: number; total: number; hasPrevious: boolean; hasNext: boolean; onPrevious: () => void; onNext: () => void;
}) {
  return (
    <nav className="op-pagination" aria-label="Pagination">
      <button type="button" className={buttonClass("outline")} onClick={onPrevious} disabled={!hasPrevious}><span>Previous</span></button>
      <span aria-live="polite">{total === 0 ? "0 of 0" : `${from}–${to} of ${total}`}</span>
      <button type="button" className={buttonClass("outline")} onClick={onNext} disabled={!hasNext}><span>Next</span></button>
    </nav>
  );
}

/** Team initials tile used where no approved crest exists (IMG_0533, IMG_0535). */
export function TeamInitials({ name, size = "md" }: { name: string; size?: "sm" | "md" | "lg" }) {
  return <span className={`op-initials op-initials-${size}`} aria-hidden="true">{teamInitials(name)}</span>;
}

export function teamInitials(name: string): string {
  const words = name.replace(/[^\p{L}\p{N}\s]/gu, " ").split(/\s+/).filter(Boolean);
  if (words.length === 0) return "?";
  if (words.length === 1) return words[0].slice(0, 2).toUpperCase();
  return words.slice(0, 3).map((word) => word[0]).join("").toUpperCase();
}

export function IconButton({ label, icon: Icon, onClick, badge }: { label: string; icon: LucideIcon; onClick?: () => void; badge?: ReactNode }) {
  return <button type="button" className="op-icon-button" aria-label={label} onClick={onClick}><Icon aria-hidden="true" />{badge}</button>;
}

/** Segmented control for switching views within a page (buttons) — use links with `.op-segment` for routed views. */
export function SegmentedTabs<T extends string>({ label, value, options, onChange }: {
  label: string; value: T; options: readonly { value: T; label: string; icon?: LucideIcon }[]; onChange: (value: T) => void;
}) {
  return (
    <div className="op-segmented" role="tablist" aria-label={label}>
      {options.map(({ value: optionValue, label: optionLabel, icon: Icon }) => (
        <button key={optionValue} type="button" role="tab" className="op-segment" aria-selected={value === optionValue} onClick={() => onChange(optionValue)}>
          {Icon && <Icon aria-hidden="true" />}{optionLabel}
        </button>
      ))}
    </div>
  );
}

export function Field({ label, hint, error, children, htmlFor }: { label: string; hint?: string; error?: string; children: ReactNode; htmlFor: string }) {
  return (
    <div className="op-field">
      <label className="op-field-label" htmlFor={htmlFor}>{label}</label>
      {children}
      {error ? <span className="op-field-error" role="alert">{error}</span> : hint && <span className="op-field-hint">{hint}</span>}
    </div>
  );
}

/** Side panel for complex records (admin registers). Built on <dialog> for focus management. */
export function Drawer({ open, title, onClose, children }: { open: boolean; title: string; onClose: () => void; children: ReactNode }) {
  const ref = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) dialog.showModal();
    if (!open && dialog.open) dialog.close();
  }, [open]);
  return (
    <dialog ref={ref} className="op-drawer" aria-labelledby={titleId} onCancel={(event) => { event.preventDefault(); onClose(); }}>
      <div className="op-drawer-header"><h2 id={titleId} className="op-section-title">{title}</h2><IconButton label="Close" icon={X} onClick={onClose} /></div>
      <div className="op-drawer-body">{children}</div>
    </dialog>
  );
}

export function Avatar({ src, size = 40, label }: { src?: string | null; size?: number; label?: string }) {
  return (
    <span className="op-avatar" style={{ width: size, height: size }} aria-label={label} role={label ? "img" : undefined}>
      {src ? <img src={src} alt="" /> : <User aria-hidden="true" />}
    </span>
  );
}

/** Fixture/result card (IMG_0572/0573/0540). Never shows a score unless `score` is a published result. */
export function MatchCard({ meta, metaTrailing, home, away, score, foot, to, params, search }: {
  meta: ReactNode; metaTrailing?: ReactNode;
  home: { name: string; label?: string }; away: { name: string; label?: string };
  score?: { home: number; away: number } | null; foot?: ReactNode;
  to?: To; params?: Record<string, string>; search?: Record<string, string>;
}) {
  const body = <>
    <div className="op-match-meta"><span>{meta}</span>{metaTrailing}</div>
    <div className="op-match-teams">
      <span className="op-match-team"><strong>{home.name}</strong>{home.label && <small>{home.label}</small>}</span>
      {score ? <span className="op-match-centre" aria-label={`${score.home} to ${score.away}`}>{score.home}–{score.away}</span> : <span className="op-match-vs">vs</span>}
      <span className="op-match-team"><strong>{away.name}</strong>{away.label && <small>{away.label}</small>}</span>
    </div>
    {foot && <div className="op-match-foot">{foot}</div>}
  </>;
  return to ? <Link to={to} params={params as never} search={search as never} className="op-match">{body}</Link> : <article className="op-match">{body}</article>;
}

/** Team row used by directories and tables (IMG_0533, IMG_0580). */
export function TeamRow({ name, meta, trailing, to, params }: { name: string; meta?: ReactNode; trailing?: ReactNode; to?: To; params?: Record<string, string> }) {
  const body = <><TeamInitials name={name} size="sm" /><span className="op-row-body"><span className="op-row-title">{name}</span>{meta && <span className="op-row-meta">{meta}</span>}</span>{trailing && <span className="op-row-trailing">{trailing}</span>}{to && <ChevronRight aria-hidden="true" className="op-chevron" />}</>;
  return to ? <Link to={to} params={params as never} className="op-row">{body}</Link> : <div className="op-row">{body}</div>;
}

/** Player row (squads, leaderboards). Shows display names only — never contact details. */
export function PlayerRow({ name, leading, meta, trailing }: { name: string; leading?: ReactNode; meta?: ReactNode; trailing?: ReactNode }) {
  return <div className="op-row">{leading}<span className="op-row-body"><span className="op-row-title">{name}</span>{meta && <span className="op-row-meta">{meta}</span>}</span>{trailing && <span className="op-row-trailing">{trailing}</span>}</div>;
}
