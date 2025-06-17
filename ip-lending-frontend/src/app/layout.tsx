import { Inter } from 'next/font/google';
import './globals.css';
import '@tomo-inc/tomo-evm-kit/styles.css'; // Changed from RainbowKit
import { Providers } from './providers';

const inter = Inter({ subsets: ['latin'] });

export const metadata = {
  title: 'IP Collateral Lending Protocol',
  description: 'Decentralized lending using IP assets as collateral',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <Providers>
          {children}
        </Providers>
      </body>
    </html>
  );
}
