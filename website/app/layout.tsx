import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Chirpy POS | Sell clearly, online or offline",
  description:
    "A modern point of sale for checkout, inventory, reports, returns, credit, expenses, and connected desktop and mobile workflows.",
  icons: {
    icon: "/chirpy-logo.png",
    shortcut: "/chirpy-logo.png",
    apple: "/chirpy-logo.png",
  },
  openGraph: {
    title: "Chirpy POS | Modern retail, clearly connected",
    description:
      "Sell faster, know your stock, and keep moving online or offline.",
    images: ["/chirpy-pos-social.png"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
