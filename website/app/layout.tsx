import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "TRX POS | Sell clearly, online or offline",
  description:
    "A modern point of sale for checkout, inventory, reports, returns, credit, expenses, and connected desktop and mobile workflows.",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
  openGraph: {
    title: "TRX POS | Modern retail, clearly connected",
    description:
      "Sell faster, know your stock, and keep moving online or offline.",
    images: ["/trx-pos-social.png"],
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
