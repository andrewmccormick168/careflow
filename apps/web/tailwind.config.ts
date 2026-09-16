import type { Config } from "tailwindcss";

export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Calm, neutral, high-contrast — see docs/architecture.md UX section.
        background: "#F7F9FA",
        surface: "#FFFFFF",
        ink: "#1B2430",
        muted: "#5B6B7A",
        border: "#E1E7EB",
        primary: {
          DEFAULT: "#2C6E8E", // soft blue
          hover: "#255C78",
        },
        accent: {
          teal: "#2E8B7F",
          green: "#3E8E5A",
        },
        status: {
          info: "#2C6E8E",
          success: "#3E8E5A",
          warning: "#B8860B",
          danger: "#B3261E",
        },
      },
      borderRadius: {
        card: "0.75rem",
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "sans-serif"],
      },
    },
  },
  plugins: [],
} satisfies Config;
