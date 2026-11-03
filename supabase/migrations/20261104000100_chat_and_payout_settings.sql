-- Migration: Add provider payout details and persistent chat messages
-- Created: 2026-11-04

-- 1. Add payout and custom QR fields to provider_billing_accounts
ALTER TABLE provider_billing_accounts 
ADD COLUMN IF NOT EXISTS upi_id text,
ADD COLUMN IF NOT EXISTS upi_name text,
ADD COLUMN IF NOT EXISTS upi_qr_url text,
ADD COLUMN IF NOT EXISTS account_number text,
ADD COLUMN IF NOT EXISTS ifsc_code text,
ADD COLUMN IF NOT EXISTS bank_name text,
ADD COLUMN IF NOT EXISTS branch_name text,
ADD COLUMN IF NOT EXISTS account_holder_name text;

-- 2. Create chat_messages table for two-way Customer <-> Provider communication
CREATE TABLE IF NOT EXISTS chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id uuid REFERENCES providers(id) ON DELETE CASCADE,
  customer_id text NOT NULL,
  sender_role text NOT NULL CHECK (sender_role IN ('customer', 'provider')),
  sender_name text NOT NULL,
  sender_id text NOT NULL,
  message text NOT NULL,
  attachment_url text,
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_provider_customer ON chat_messages(provider_id, customer_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_chat_customer ON chat_messages(customer_id, created_at DESC);

-- Enable RLS and service role access
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_messages_service_role_all" ON chat_messages
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "chat_messages_select_public" ON chat_messages
  FOR SELECT
  TO authenticated, anon
  USING (true);

CREATE POLICY "chat_messages_insert_public" ON chat_messages
  FOR INSERT
  TO authenticated, anon
  WITH CHECK (true);
