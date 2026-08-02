// The ONLY place the product name lives. Every screen, email, and push
// notification should import from here rather than hardcoding a name.
// Renaming the app = change these values, nothing else in the codebase.

export const BRAND = {
  appName: "Zorva",              // working name — not finalized
  flagshipRatingLabel: "Zorva Rating",   // shown in UI for the 'flagship' rating context
  communityRatingLabel: "Community Rating",
  tagline: "The real rating for real players.",
};

// Internal identifiers (rating_contexts.type values, route names, table
// names, analytics event names) should NEVER use BRAND.appName or any
// brand-derived string. Use generic terms: 'flagship', 'community', etc.
// This is what makes the rename in BRAND above sufficient on its own.
