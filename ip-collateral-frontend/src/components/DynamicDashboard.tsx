'use client';

import dynamic from 'next/dynamic';
import { Loader2 } from 'lucide-react';

// ✅ Dynamic import with no SSR
const Dashboard = dynamic(
  () => import('./Dashboard'),
  { 
    ssr: false,
    loading: () => (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 via-indigo-50 to-purple-50 flex items-center justify-center">
        <div className="flex items-center space-x-2">
          <Loader2 className="w-6 h-6 animate-spin" />
          <span>Loading Dashboard...</span>
        </div>
      </div>
    )
  }
);

export default Dashboard;
