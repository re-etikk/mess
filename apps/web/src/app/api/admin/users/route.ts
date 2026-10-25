import { NextRequest, NextResponse } from 'next/server';

export async function GET(req: NextRequest) {
  // Returns user directory
  const users = [
    {
      id: 'cust-ritik-001',
      name: 'Ritik Chaurasia',
      email: 'ritik45chaurasia@gmail.com',
      role: 'admin',
      created_at: '2026-10-24T00:00:00Z',
    },
    {
      id: 'user-owner-001',
      name: 'Radhe Shyam',
      email: 'owner@radhemess.in',
      role: 'provider',
      created_at: '2026-10-24T00:00:00Z',
    },
    {
      id: 'cust-demo-002',
      name: 'Ananya Sharma',
      email: 'ananya@example.com',
      role: 'customer',
      created_at: '2026-10-25T00:00:00Z',
    },
  ];

  return NextResponse.json({
    success: true,
    total: users.length,
    users,
  });
}
