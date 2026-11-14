import { useEffect, useId, useRef, type ReactNode } from "react";
import { Link } from "@tanstack/react-router";
import { AlertTriangle, ChevronRight, Inbox, LoaderCircle, Search, type LucideIcon } from "lucide-react";

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

export function SectionHeading({ title, description, meta, id }: { title: string; description?: string; meta?: ReactNode; id?: string }) {
  return (
    <div className="op-section-heading">
      <div>
        <h2 id={id} className="op-section-title">{title}</h2>
        {description && <p className="op-section-description">{description}</p>}
      </div>
      {meta && <div className="op-section-meta">{meta}</div>}
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

type ButtonVariant = "primary" | "outline" | "ghost" | "light";
const buttonClass = (variant: ButtonVariant, block?: boolean) => `op-button op-button-${variant}${block ? " op-button-block" : ""}`;

export function Button({ children, variant = "primary", block, type = "button", disabled, busy, onClick, icon: Icon }: {
  children: ReactNode; variant?: ButtonVariant; block?: boolean; type?: "button" | "submit";
  disabled?: boolean; busy?: boolean; onClick?: () => void; icon?: LucideIcon;
}) {
  return (
    <button type={type} className={buttonClass(variant, block)} disabled={disabled || busy} aria-busy={busy || undefined} onClick={onClick}>
      {busy ? <LoaderCircle aria-hidden="true" className="op-spin" /> : Icon && <Icon aria-hidden="true" />}
      <span>{children}</span>
    </button>
  );
}

export function ButtonLink({ children, to, variant = "primary", block, icon: Icon, hash }: {
  children: ReactNode; to: To; variant?: ButtonVariant; block?: boolean; icon?: LucideIcon; hash?: string;
}) {
  return (
    <Link to={to} hash={hash} className={buttonClass(variant, block)}>
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
