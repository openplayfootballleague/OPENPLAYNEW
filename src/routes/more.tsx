import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/more")({
  component: MorePage,
});

function MorePage() {
  const links = [
    { title: "Leagues & teams", description: "Explore Open Play competitions and clubs.", href: "/teams" },
    { title: "Player Hub", description: "Sign in to view your profile, team and season.", href: "/player" },
    { title: "Sign in", description: "Access your Open Play account.", href: "/sign-in" },
    { title: "About Open Play", description: "Local football. Big energy.", href: "/#about" },
  ];
  return (
    <main className="more-page">
      <p className="eyebrow"><span /> OPEN PLAY</p>
      <h1>MORE.</h1>
      <p className="more-intro">Everything else you need to find your place in the game.</p>
      <div className="more-links">
        {links.map((link, index) => (
          <a href={link.href} key={link.title}>
            <span className="more-link-index">0{index + 1}</span>
            <span><strong>{link.title}</strong><small>{link.description}</small></span>
            <span className="more-link-arrow" aria-hidden="true">↗</span>
          </a>
        ))}
      </div>
    </main>
  );
}
